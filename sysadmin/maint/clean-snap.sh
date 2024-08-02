#!/bin/bash
#
echo "Clean up the snap cache by removing disabled snaps."

# CLOSE ALL SNAPS BEFORE RUNNING THIS!

set -eu
snap list --all | awk '/disabled/{print $1, $3' |
	while read snapname revision; do
		snap remove "$snapname" --revision="$revision"
	done
