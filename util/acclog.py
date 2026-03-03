#!/usr/bin/env python3

"""
Google style here doc for acclog.py

(This should be remade into a module that can be used by all the scripts that would parse /tmp/access_log.)

args: 
    start_dir: The directory in which to search for files to combine.
    output: The file to write the collected logs to.

returns: void
    There is no return object, just the output file.
    When/if converted to a module, it would output the list of collected, distinct log lines.

Raises: None (yet)
"""
import os
import sys
import pprint
import argparse
from termcolor import cprint
import zipfile
import gzip
import io

# This isn't working for some reason.
def is_privileged_user() -> bool:
    """
    Checks if the current process has root/administrative privileges.

    This function determines if the script is being executed by the root user
    or with effective root capabilities on a Linux-based system by checking 
    the Effective User ID (EUID).

    Returns:
        bool: True if the process has root privileges (EUID 0), False otherwise.
        
    Example:
        >>> if not is_privileged_user():
        ...     print("Error: This script must be run as root.")
    """
    # On POSIX systems, root always has an UID of 0.
    # We check the effective UID to account for setuid binaries or 
    # elevated shells.
    # try:
    return os.geteuid() == 0
    # except AttributeError:
    #     # Fallback for non-POSIX platforms where geteuid() is not available.
    #     # In a production monorepo, this would likely log to a telemetry 
    #     # service like Google Cloud Logging or Meta's Scuba.
    #     return False

def is_gzip_compressed(filename: str, verbose: bool =False) -> bool:
    try:
        with gzip.open(filename, 'rb') as f:
            f.read(1) # Try to read a byte to trigger an error if not gzip
        return True
    except OSError:
        return False

def get_gzipped_lines(filename: str, verbose: bool =False) -> list:
    lines = list()
    if is_gzip_compressed(filename, verbose):
        iostream = io.open(filename, 'rb')
        with gzip.GzipFile(fileobj=iostream, mode='rb') as gz_stream:
            for line_bytes in gz_stream:
                # Decode bytes back into a string
                _decoded = line_bytes.decode('utf-8')
                if _decoded not in lines:
                    lines.append(_decoded)
    # sending to a set is probably not necessary here, but we don't want duplicate lines.
    return list(set(lines))

def parse_arguments() -> argparse.Namespace:
    p = argparse.ArgumentParser("Combines logs from the specified directory.")
    vqd = p.add_mutually_exclusive_group()
    vqd.add_argument('-v', '--verbose', dest='verbose', action='store_true', help='Adds output.')
    vqd.add_argument('-q', '--quiet', dest='quiet', action='store_true', help='suppresses all output, except errors.')
    vqd.add_argument('-D', '--debug', dest='debug', action='store_true', help='Debugging output.')
    p.add_argument('-d', '--start-dir', dest='start_dir', default='/var/log/nginx')
    p.add_argument('-o', '--output', dest='output', default='/tmp/access_log', help='The path to the output file.')
    return p.parse_args()

def main():
    #region Script Setup
    pp = pprint.PrettyPrinter(indent=4)

    args = parse_arguments()

    # if not os.geteuid == 0:
    #     cprint(f"You must be root.  Try 'sudo {sys.argv[0]}'", "red")
    #     exit(1)

    #endregion
    outlines = list()
    if not os.path.exists(args.start_dir):
        cprint(f"The specified starting directory ({args.start_dir}) does not exist.")
        exit(1)
    # open target log directory
    # get the file listing
    # loop through the file listing
    # add log lines to collection (list()?)
    for filename in os.listdir(args.start_dir):
        full_path = os.path.join(args.start_dir, filename)
        if args.verbose:
            print(f"INFO :: file path: {full_path}")
        # if it's compressed, decompress it
        #   stream if possible
        if zipfile.is_zipfile(full_path):
            print(f"INFO :: {full_path} is zip compressed.")
        elif is_gzip_compressed(full_path):
            print(f"INFO :: {full_path} is gzip compressed.")
            _lines = get_gzipped_lines(full_path)
            outlines.extend(_lines)
        else:
            # For now, assume that it's not compressed
            with open(full_path, 'r') as fp:
                outlines.extend(fp.readlines())

    # loop through the collection
    print(f"INFO :: There are {len(outlines)} total lines collected.")
    # write each uniqie log line to /tmp/access_log or the designated output file
    with open(args.output, 'w') as of:
        of.writelines(outlines)

if __name__=='__main__':
    main()