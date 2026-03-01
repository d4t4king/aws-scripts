#!/usr/bin/env python3

import argparse
import pprint
import re
import ipaddress as IP
from termcolor import cprint
import sys
import os


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
    return p.parse_args()

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
    countries = {}
    requests = {}
    requestips = {}
    uaips = {}
    unmatched = []
    msg_type_count = {}

    # [Fri Feb 20 00:00:06.259891 2026] [core:notice] [pid 884:tid 884] AH00094: Command line: '/usr/sbin/apache2'
    core_notice_rgx = re.compile(r"\s+\[core:notice\]\s+")
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
                print(f"INFO :: Adding increment 1 to blank line total: {msg_type_count['blank']}")
                continue
            if re.search(core_notice_rgx, line):
                if 'core_notice' in msg_type_count.keys():
                    msg_type_count['core_notice'] += 1
                else:
                    msg_type_count['core_notice'] = 1
                print(f"INFO :: Adding increment 1 to core_notice line total: {msg_type_count['core_notice']}")
                # This is mainly about service start and stop.  We don't really care about these messages.
                continue
            if re.search(nginx_log_1_rgx, line):
                print(f"INFO :: Matched a line to analyze (1)...")
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
                #       user-agents per client
                # uaips.setdefault(clientip, {})
                # uaips[clientip][ua] = uaips[clientip].get(ua, 0) + 1
                if clientip in uaips.keys():
                    if ua in uaips[clientip].keys():
                        uaips[clientip][ua] += 1
                    else:
                        uaips[clientip][ua] = 1
            else:
                #   collect unmatched lines (presumably for processing later)
                unmatched.append(line)
                print(f"INFO :: Did not match a line to analyze...(count: {len(unmatched)})")

    cprint(f"CLIENTS: ", 'yellow', end="")
    print(f"({len(clients.keys())} unique clients)")
    pp.pprint(clients)
    cprint(f"REQUESTS: ", 'yellow', end="")
    print(f"({len(requests.keys())} unique requests)")
    pp.pprint(requests)
    cprint(f"REQUESTIPS: ", 'yellow', end="")
    print(f"({len(requestips.keys())} unique requester ips)")
    pp.pprint(requestips)
    cprint(f"UAIPS: ", 'yellow', end="")
    print(f"({len(uaips.keys())} unique user-agents)")
    pp.pprint(uaips)
    cprint(f"UNMATCHED: ", 'red', end="")
    print(f"({len(unmatched)} unmatched lines)")
    pp.pprint(unmatched)
    cprint(f"MSG_TYPE_COUNT: ", 'green')
    pp.pprint(msg_type_count)

    # loop through clients looking up country-code/country-name for each IP address
    for client in clients.keys():
    #   get country, organization, description, and owner
    # collect countries by hit count
    # 

        # loop through the requests
        for req in requests[client].keys():
        #   skip empty requests (GET|HEAD requests with no path)
            if re.search(r"(?:GET|HEAD)\s*\/\s*", req):
                continue
            if re.search(r"\%\w\w", req):
                print(f"INFO :: Matched possible unicode(?) encoded request.")
            elif re.search(r"\\x[0-9a-fA-F][0-9a-fA-F]", req):
                print(f"INFO :: Matched possible hex encoded request.")
            else:
                print(f"INFO :: Matched a request that is either not encoded or encoding in unrecognized.")
            print(f"{req}")

        # loop through the user-agents
        for ua in uaips[client].keys():
            #   block any client IPs that have bot user-agents
            if re.search(r"ZmEu", ua):
                print(f"INFO :: BLOCK (ZmEu): {client} -> {ua} 'iptables -I INPUT 1 -s {client} -j DROP'")
            elif re.search(r"masss?can", ua):
                print(f"INFO :: BLOCK (masscan): {client} -> {ua} 'iptables -I INPUT 1 -s {client} -j DROP'")
            else:
                print(f"INFO :: Matched a user-agent that is either not recognized as a bot or is a bot we don't care about.")

if __name__=='__main__':
    main()