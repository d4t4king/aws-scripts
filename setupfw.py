#!/usr/bin/env python

import iptc
import pprint

def main():
    tcp_chain = iptc.Chain(iptc.Table(iptc.Table.FILTER), "TCP")
    udp_chain = iptc.Chain(iptc.Table(iptc.Table.FILTER), 'UDP')


if __name__=='__main__':
    main()

