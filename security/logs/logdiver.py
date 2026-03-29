#!/usr/bin/env python3

import argparse
import pprint
import re
import ipaddress as IP
from termcolor import cprint
import sys
import os
import json
### Use this for the default interface (URL only) for ipinfo -- this has usage limits.
# from urllib.request import urlopen
### ipinfo is a PITA to install in managed environments.  Go learn how to set up venv's
#import ipinfo
### Trying just a basic requests call
import requests

def parse_arguments():
    p = argparse.ArgumentParser()
    vqd = p.add_mutually_exclusive_group()
    vqd.add_argument('-v', '--verbose', dest='verbose', action='store_true', help="Adds more output.")
    vqd.add_argument('-q', '--quiet', dest='quiet', action='store_true', help='Suppresses all output except erors.')
    vqd.add_argument('-D', '--debug', dest='debug', action='store_true', help='All the outputs for debugging.')
    p.add_argument('-f', '--input-file', dest='input_file', default='/tmp/access_log', help="The file to process.  Default: /tmp/access_log.")
    p.add_argument('--iptables-path', dest='iptables_path', help='the path to the iptables binary') # This may not be required or used if we want to try the iptc library.
    p.add_argument('--iptables-outfile', dest='iptables_out', help='the output file to write to')
    p.add_argument('--iptables-err', dest='iptables_err', default='/tmp/iptables.err', help='the output file to write errors')
    p.add_argument('-t', '--ipinfo-token', dest='ipinfo_token', help="The Bearer token to use with ipinfo api calls.")
    return p.parse_args()

def get_country_code_from_ip(ipaddress: IP.IPv4Address | IP.IPv6Address, authtoken: str) -> str:
    """
    Fetches the two-letter country code (e.g., 'US') for a given IP address using the ipinfo.io.api
    
    Note: Free tiers of APIs may have usage limits.
    """
    pp = pprint.PrettyPrinter(indent=4)
    local_link = IP.ip_network("127.0.0.0/8")
    # An API URL - you can get a free token from the [IPinfo dashboard](https://ipinfo.io)
    # The [IP-API.com](http://ip-api.com/json/) service is another option that does not 
    # require a key for basic lookups.
    ### 
    ### curl -H "Authorization: Bearer XXXXXXXXXXXXXX" https://api.ipinfo.io/lite/8.8.8.8
    url = f"https://api.ipinfo.io/lite/{ipaddress}"
    #url = f"https://ipinfo.io/{ipaddress}/json"

    try:
        headers = {
            'Authorization': f"Bearer {authtoken}",
            'Content-Type': 'application/json'
        }
        resp = requests.get(url, headers=headers)
        r_json = resp.json()
    except Exception as e:
        print(f"An error occurred: {e}")
        exit(1)
    if 'country_code' in r_json.keys():
        return r_json['country_code']
    else:
        if ipaddress in local_link:
            return "LOC"
        else:
            return "UNK"

def main():
    pp = pprint.PrettyPrinter(indent=4)

    args = parse_arguments()

    if args.debug:
        args.verbose = True
    
    if not os.path.exists(args.input_file):
        cprint(f"ERROR :: The input file {args.input_file} does not exist.  Exiting.", 'red')
        sys.exit(1)

    if args.verbose:
        print(f"INFO :: verbose: {args.verbose}, quiet: {args.quiet}, debug: {args.debug}, input_file: {args.input_file}, iptables_path: {args.iptables_path}, iptables_out: {args.iptables_out}, iptables_err: {args.iptables_err}")

    clients = {}
    client_ccs = {}
    countries = {}
    requests = {}
    requestips = {}
    useragents = {}
    uaips = {}
    unmatched = []
    msg_type_count = {}

    # [Fri Feb 20 00:00:06.259891 2026] [core:notice] [pid 884:tid 884] AH00094: Command line: '/usr/sbin/apache2'
    core_notice_rgx = re.compile(r"\s+\[core:notice\]\s+")
    # '[Sun Feb 22 20:17:08.224872 2026] [mpm_event:notice] [pid 906:tid 906] '
    # 'AH00489: Apache/2.4.66 (Debian) configured -- resuming normal '
    # 'operations\n'
    mpm_event_notice_rgx = re.compile(r"\s+\[mpm_event:notice\]\s+")
    # "AH00558: apache2: Could not reliably determine the server's fully "
    # "qualified domain name, using 127.0.1.1. Set the 'ServerName' directive "
    # 'globally to suppress this message\n'
    no_fqdn_rgx = re.compile(r".*full qualified domain name,.+127\.0\.[01]\.1")
    # 52.169.14.74 - - [05/Aug/2025:14:59:04 +0000] "GET /y.php HTTP/1.1" 404 162 "-" "-"
    nginx_log_1_rgx = re.compile(r"((?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))\s*\-\s*.*?\s*\[(.*?)\]\s*\"(.*?)\"\s*(\d+)\s*\d+\s*\".*?\"\s*\"(.*?)\"")
    # logs should be http/apache/nginx access logs
    # loop through log lines
    with open(args.input_file, 'r') as inf:
        for line in inf.readlines():
            if args.verbose:
                print(f"INFO :: Processing line: {line.strip()}")
            #   skip empty lines
            if re.search(r"^\s*$", line):
                if 'blank' in msg_type_count.keys():
                    msg_type_count['blank'] += 1
                else:
                    msg_type_count['blank'] = 1
                if args.verbose:
                    print(f"INFO :: Adding increment 1 to blank line total: {msg_type_count['blank']}")
                continue
            if re.search(core_notice_rgx, line):
                if 'core_notice' in msg_type_count.keys():
                    msg_type_count['core_notice'] += 1
                else:
                    msg_type_count['core_notice'] = 1
                if args.verbose:
                    print(f"INFO :: Adding increment 1 to core_notice line total: {msg_type_count['core_notice']}")
                # This is mainly about service start and stop.  We don't really care about these messages.
                continue
            if re.search(mpm_event_notice_rgx, line):
                if 'mpm_event_notice' in msg_type_count.keys():
                    msg_type_count['mpm_event_notice'] += 1
                else:
                    msg_type_count['mpm_event_notice'] = 1
                if args.verbose:
                    print(f"INFO :: Adding increment 1 to mpm_event_notice line total: {msg_type_count['mpm_event_notice']}")
                continue
            if re.search(no_fqdn_rgx, line):
                if 'no_fqdn_lo' in msg_type_count.keys():
                    msg_type_count['no_fqdn_lo'] += 1
                else:
                    msg_type_count['no_fqdn_lo'] = 1
                if args.verbose:
                    print(f"INFO :: Adding increment 1 to no_fqdn_lo line total: {msg_type_count['no_fqdn_lo']}")
                continue
            if re.search(nginx_log_1_rgx, line):
                if args.verbose: 
                    print(f"INFO :: Matched a line to analyze (regex 1)...")
                m = re.search(nginx_log_1_rgx, line)
                if args.verbose:
                    print(f"INFO :: group1: {m.group(1)}, group2: {m.group(2)}, group3: {m.group(3)}, group4: {m.group(4)}, group5: {m.group(5)}") # pyright: ignore[reportOptionalMemberAccess]
                clientip = m.group(1) # pyright: ignore[reportOptionalMemberAccess]
                if args.verbose:
                    print(f"INFO :: clientip: {clientip}")
                datestr = m.group(2) # pyright: ignore[reportOptionalMemberAccess]
                if args.verbose:
                    print(f"INFO :: datestr: {datestr}")
                request = m.group(3) # pyright: ignore[reportOptionalMemberAccess]
                if args.verbose:
                    print(f"INFO :: request: {request}")
                httpstatus = m.group(4) # pyright: ignore[reportOptionalMemberAccess]
                if args.verbose:
                    print(f"INFO :: httpstatus: {httpstatus}")
                ua = m.group(5) # pyright: ignore[reportOptionalMemberAccess]
                if args.verbose:
                    print(f"INFO :: ua: {ua}")
                #   parse the various formats of log lines counting:
                #       clients (IPs)
                # clients[clientip] = clients.get(clientip, 0) + 1
                if clientip in clients.keys():
                    clients[clientip] += 1
                else:
                    clients[clientip] = 1
                #       clients per request
                # ensure we have a dict for this request before incrementing
                # requests.setdefault(request, {})
                # requests[request][clientip] = requests[request].get(clientip, 0) + 1
                if request in requests.keys():
                    if clientip in requests[request].keys():
                        requests[request][clientip] += 1
                    else:
                        requests[request][clientip] = 1
                else:
                    requests[request] = {clientip: 1}
                #       requests per client
                # requestips.setdefault(clientip, {})
                # requestips[clientip][request] = requestips[clientip].get(request, 0) + 1
                if clientip in requestips.keys():
                    if request in requestips[clientip].keys():
                        requestips[clientip][request] += 1
                    else:
                        requestips[clientip][request] = 1
                else:
                    requestips[clientip] = {request: 1}
                if ua in useragents.keys():
                    useragents[ua] += 1
                else:
                    useragents[ua] = 1
                #       user-agents per client
                if clientip in uaips.keys():
                    if ua in uaips[clientip].keys():
                        uaips[clientip][ua] += 1
                    else:
                        uaips[clientip][ua] = 1
                else:
                    uaips[clientip] = {}
                    uaips[clientip][ua] = 1
            else:
                #   collect unmatched lines (presumably for processing later)
                unmatched.append(line)
                if args.verbose:
                    print(f"INFO :: Did not match a line to analyze...(count: {len(unmatched)})")

    cprint(f"CLIENTS: ", 'yellow', end="")
    print(f"({len(clients.keys())} unique clients)")
    # pp.pprint(clients)
    cprint(f"REQUESTS: ", 'yellow', end="")
    print(f"({len(requests.keys())} unique requests)")
    # pp.pprint(requests)
    cprint(f"REQUESTIPS: ", 'yellow', end="")
    print(f"({len(requestips.keys())} unique requester ips)")
    # pp.pprint(requestips)
    cprint(f"USERAGENTS: ", "yellow", end="")
    print(f"({len(useragents)} unique uner-agents)")
    # pp.pprint(useragents)
    cprint(f"UAIPS: ", 'yellow', end="")
    print(f"({len(uaips.keys())} unique user-agents)")
    # pp.pprint(uaips)
    cprint(f"UNMATCHED: ", 'red', end="")
    print(f"({len(unmatched)} unmatched lines)")
    # pp.pprint(unmatched)
    cprint(f"MSG_TYPE_COUNT: ", 'green')
    pp.pprint(msg_type_count)

    # loop through clients looking up country-code/country-name for each IP address
    for client in clients.keys():
    #   get country, organization, description, and owner
    # collect countries by hit count
        cc = get_country_code_from_ip(client, args.ipinfo_token)
        print(f"INFO :: CC: {client} -> {cc}")
        if cc in countries.keys():
            countries[cc] += 1
        else:
            countries[cc] = 1
        if client in client_ccs:
            if cc in client_ccs[client].keys():
                client_ccs[client][cc] += 1
            else:
                client_ccs[client][cc] = 1
        else:
            client_ccs[client] = {}
            client_ccs[client][cc] = 1

        # loop through the requests
        for req in requestips[client].keys():
        #   skip empty requests (GET|HEAD requests with no path)
            if re.search(r"(?:GET|HEAD)\s*\/\s*", req):
                continue
            if re.search(r"\%\w\w", req):
                print(f"INFO :: Matched possible unicode(?) encoded request.")
            elif re.search(r"\\x[0-9a-fA-F][0-9a-fA-F]", req):
                print(f"INFO :: Matched possible hex encoded request.")
                ascii_decoded = req.decode('ascii')
                print(f"ASCII decoded: {ascii_decoded}")
                utf_decoded = req.decode('utf-8')
                print(f"UTF-8 Decoded: {utf_decoded}")
            else:
                if args.verbose:
                    print(f"INFO :: Matched a request that is either not encoded or encoding in unrecognized.")
            print(f"{req}")

        # loop through the user-agents
        for ua in uaips[client].keys():
            #   block any client IPs that have bot user-agents
            if re.search(r"Go-http-client", ua):
                cprint(f"BLOCK :: DROP (language-clients): {client} -> {ua} 'iptables -I INPUT 1 -s {client} -j DROP'", "red")
            if re.search(r"ZmEu", ua):
                cprint(f"BLOCK :: DROP (ZmEu): {client} -> {ua} 'iptables -I INPUT 1 -s {client} -j DROP'", "red")
            elif re.search(r"masss?can", ua):
                cprint(f"BLOCK :: DROP (masscan): {client} -> {ua} 'iptables -I INPUT 1 -s {client} -j DROP'", "red")
            elif re.search(r"RavenX-Scanner\/1\.0", ua):
                cprint(f"BLOCK :: DROP(RavenX-Scanner): {client} -> {ua} 'iptables -I INPUT -s {client} -j DROP'", "red")
            elif re.search(r"AhrefsBot\/7\.0;", ua):
                cprint(f"BLOCK :: DROP (AhrefsBot): {client} -> {ua} 'iptables -I INPUT 1 -s {client} -j DROP'", "red")
            elif re.search(r"zgrab", ua):
                cprint(f"BLOCK :: DROP (zgrab): {client} -> {ua} 'iptables -I INPUT 1 -s {client} -j DROP'", "red")
            elif re.search(r"SaaSBrowserBot", ua):
                cprint(f"BLOCK :: DROP (SaaSBrowserBot): {client} -> {ua} 'iptables -I INPUT 1 -s {client} -j DROP'", "red")
            elif re.search(r"MJ12bot", ua):
                cprint(f"BLOCK :: DROP (MJ12bot): {client} -> {ua} 'iptables -I INPUT 1 -s {client} -j DROP'", "red")
            elif re.search(r"BitSightBot", ua):
                cprint(f"BLOCK :: DROP (BitSightBot): {client} -> {ua} 'iptables -I INPUT 1 -s {client} -j DROP'", "red")
            elif re.search(r"Hello from Palo Alto Networks", ua):
                # We don't care about them scanning, really, since they should mostly be legit.  So let's send them a reset 
                # instead of just dropping the traffic.
                cprint(f"BLOCK :: RESET (palo-alto scanner): {client} -> {ua} 'iptables -I INPUT 1 -p tcp --dport 443 -j REJECT --reject-with tcp-reset", "yellow")
            elif re.search(r"silver\.inc", ua):
                # This looks like it might be research so go ahead and RESET them for now.
                cprint(f"BLOCK :: RESET (silver.inc) {client} -> {ua} 'iptables -i INPUT 1 -p tcp --dport 443 -j REJECT --reject-with tcp-reset'", "yellow")
            elif re.search(r"Googlebot", ua):
                cprint(f"BLOCK :: RESET (Googlebot) {client} -> {ua} 'iptables-i INPUT 1 -p tcp --dport 443 -j REJECT --reject-with tcp-reset'", "yellow")
            elif re.search(r"CensysInspect", ua):
                cprint(f"BLOCK :: RESET (Censys) {client} -> {ua} 'iptables-i INPUT 1 -p tcp --dport 443 -j REJECT --reject-with tcp-reset'", "yellow")
            else:
                #print(f"INFO :: Matched a user-agent that is either not recognized as a bot or is a bot we don't care about.")
                print(f"INFO :: client={client}, ua={ua}")

if __name__=='__main__':
    main()
