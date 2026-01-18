#!/usr/bin/env python3

import pprint
import argparse
import yaml
import os

from termcolor import cprint

def main():
    # pretty printing for objects
    pp = pprint.PrettyPrinter(indent=4)

    # parse command line arguments
    parser = argparse.ArgumentParser()
    parser.add_argument('-i', '--input', dest="inputfile", required=True, help="Input YAML file")
    args = parser.parse_args()

    # read YAML file
    if os.path.exists(args.inputfile):
        with open(args.inputfile, 'r') as f:
            data = yaml.safe_load(f)
    else:
        cprint(f"File not found: {args.inputfile}", 'red')
        exit(1)
    
    hosts = dict()
    #pp.pprint(data['allhosts'])
    for k1 in data.keys():
        if 'hosts' in data[k1].keys():
            #pp.pprint(data[k1])
            #pp.pprint(data[k1]['hosts'])
            for k2 in data[k1]['hosts'].keys():
                #pp.pprint(data[k1]['hosts'][k2])
                if data[k1]['hosts'][k2] is not None:
                    if 'ansible_host' in data[k1]['hosts'][k2].keys():
                        hostname = k2.replace('_', '.')
                        print(f"{data[k1]['hosts'][k2]['ansible_host']}\t{hostname}")

if __name__ == "__main__":
    main()
