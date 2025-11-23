#!/usr/bin/env python3
"""
Set up a basic firewall. 

This script will attempt to detect services and open ports
already running on the system and create ACCEPT rules for
those ports and services.

It will also attempt to set up some very basic rules
for a simple, stateful iptables firewall.

"""

import iptc
import pprint

def get_ifaces():
    """
    Get the network interfaces from /proc/net/dev

    Returns:
        ifaces (list): returns the list of network interfaces
            not including lo
    """
    ifaces = list()
    with open('/proc/net/dev', 'r') as dev:
        for l in dev:
            # skip the header row(s)
            if 'Inter-' in l: continue
            if 'face' in l: continue
            # skip lo, we'll handle that specifically
            if 'lo' in l: continue
            _if = l.split(':')[0]
            if _if not in ifaces:
                ifaces.append(_if)
    return ifaces

def main():
    pp = pprint.PrettyPrinter(indent=4)
    tcp_chain = iptc.Chain(iptc.Table(iptc.Table.FILTER), "TCP")
    udp_chain = iptc.Chain(iptc.Table(iptc.Table.FILTER), 'UDP')
    log_chain = iptc.Chain(iptc.Table(iptc.Table.FILTER), 'LOGGING')
    inp_chain = iptc.Chain(iptc.Table(iptc.Table.FILTER), 'INPUT')
    out_chain = iptc.Chain(iptc.Table(iptc.Table.FILTER), 'OUTPUT')
    fwd_chain = iptc.Chain(iptc.Table(iptc.Table.FILTER), 'FORWARD')

    # anything coming in from lo, allow
    rule = iptc.Rule()
    rule.in_interface = 'lo'
    t = rule.create_target("ACCEPT")

    pp.pprint(dir(inp_chain.table))

    ifaces = get_ifaces()
    pp.pprint(ifaces)

    fwd_chain.set_policy(iptc.Policy.DROP)

    

if __name__=='__main__':
    main()

