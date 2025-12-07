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
    
    pp.pprint(data)

if __name__ == "__main__":
    main()