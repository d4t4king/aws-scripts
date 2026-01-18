#!/usr/bin/env python3

import pprint
import argparse


def main():
    # read in the template
    # read the output from `iptables-save`
    # check what is in the template, but not in the local rules
    # check what is in the local rules, but not in the template
    # print differences for each rule set
    # optionally, write missing rules from the template to the local rules
    pass

if __name__ == "__main__":
    main()
