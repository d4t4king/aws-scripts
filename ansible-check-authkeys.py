#!/usr/bin/env python3

"""
Checks the number of authorized keys in /root/.ssh/authorized_keys against a stored value in
/root/root_auth_keys.dat
"""
import yaml
import pprint
import argparse
import os
import sys

from termcolor import cprint

#STOREFILE = '/root/root_auth_keys.dat'

def check_root_privileges() -> None:
    """
    Check if script is running as root.
    Exit if not running with sufficient privileges.
    """
    if os.geteuid() != 0:
        cprint("ERROR: This script must be run as root or with sudo", "red")
        print("Usage: sudo ./install-cpan-modules.py [options]")
        sys.exit(1)

def get_line_count(afile: str) -> int:
  """
  Get the line count, aka number of keys, if the authorized_keys file
  """
  count = len(open(afile).readlines( ))
  return count


def read_dat(store_file: str) -> dict:
  with open(store_file, 'r') as stream:
    try:
      print(yaml.safe_load(stream))
    except yaml.YAMLError as exc:
      print(exc)


def write_dat(yamldict: dict, store_file: str, debug: bool=False) -> bool:
  if debug:
    print("DEBUG: Data to be written: ")
    documents = yaml.dump(yamldict)
    print(documents)
    print("DEBUG: Writing the following data to " + store_file)
    pprint.pprint(yamldict)
  with open(store_file, 'w') as out:
    yaml.dump(yamldict, out)
  return True


def main():
  """Enter the main function"""
  check_root_privileges()

  # pretty printing for data objects
  pp = pprint.PrettyPrinter(indent=4)
  
  # parse the arguments
  parser = argparse.ArgumentParser()
  vqd = parser.add_mutually_exclusive_group()
  vqd.add_argument("-v", "--verbose", dest="verbose", required=False, action='store_true', help="increase output verbosity")
  vqd.add_argument("-q", "--quiet", dest="quiet", required=False, action="store_true", help="suppress output except for errors")
  vqd.add_argument("-D", "--debug", dest="debug", required=False, action='store_true', help="enable debug output")
  parser.add_argument("-w", "--write", dest="write", required=False, action='store_true', help="write current count to data file")
  parser.add_argument('-s', '--show-only', dest='showonly', required=False, action='store_true', help='show current count without writing to data file')
  parser.add_argument('-d', '--db-file', dest='dbfile', default='/root/root_auth_keys.dat', required=False, help='specify alternate data file location')
  parser.add_argument('-a', '--authfile', dest='authfile', default='/root/.ssh/authorized_keys', required=False, help='specify alternate authorized_keys file location')
  args = parser.parse_args()

  if args.debug:
    print("DEBUG: Arguments parsed:")
    pp.pprint(vars(args))

  stored = read_dat(args.dbfile)
  cnt = get_line_count(args.authfile)
  print("Current count is " + str(cnt))  

if __name__=='__main__':
  main()

