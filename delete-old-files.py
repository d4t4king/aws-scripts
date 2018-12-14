#!/usr/bin/python3

import os
import sys
import os.path
import argparse
import datetime

def parse_args():
	parser = argparse.ArgumentParser(description="Delete old files.")
	parser.add_argument('-v', '--verbose', dest="verbosity", \
		action="store_true", help="Increase output verbosity.")
	parser.add_argument('-d', '--directory', dest="workdir", \
		help="Specify the directory to search for old files.")
	args = parser.parse_args()
	return args

def main():
	args = parse_args()

	now = datetime.datetime.now()
	for (dirpath, dirnames, filenames) in os.walk(args.workdir):
		for f in filenames:
			fqfile = os.path.join(dirpath, f)
			if os.path.isfile(fqfile):
				datediff = (float(now.strftime('%s')) - os.path.getmtime(fqfile)) / 86400
				if args.verbosity:
					print("Got mtime ({0}); now ({1}); diff ({2})".format(os.path.getmtime(fqfile), now.strftime('%s'), datediff))
				if datediff >= 90:
					print("{0}, {1:.2f}, {2:.2f}".format(fqfile, os.path.getmtime(fqfile), datediff))
					os.remove(fqfile)

if __name__ == '__main__':
	main()
