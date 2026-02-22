#!/usr/bin/env python3

import argparse
import pprint

def parse_arguments():
    p = argparse.ArgumentParser()
    vqd = p.add_mutually_exclusive_group()
    vqd.add_argument('-v', '--verbose', dest='verbose', action='store_stre', help="Adds more output.")
    vqd.add_argument('-q', '--quiet', dest='quiet', action='store_true', help='Suppresses all output except erors.')
    vqd.add_argument('-D', '--debug', dest='debug', action='store_true', help='All the outputs for debugging.')
    p.add_argument('--iptables-path', dest='iptables_path', help='the path to the iptables binary') # This may not be required or used if we want to try the iptc library.
    p.add_argument('--iptables-outfile', dest='iptables_out', help='the output file to write to')
    p.add_argument('--iptables-err', dest='iptables_err', default='/tmp/iptables.err', help='the output file to write errors')
    return p.parse_args()

def main():
    args = parse_arguments()
    pass

if __name__=='__main__':
    main()