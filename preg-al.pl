#!/usr/bin/perl -w

use strict;
use warnings;

open IN, "</var/log/nginx/access.log" or die "Couldn't open access log: $! \n";
while (my $line = <IN>) {
	if ($line =~ /((?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))\s*(.)\s*(.)\s*\[(\d\d?\/.*\d{4}\:\d\d?\:\d\d?:\d\d?\s*\+\d+)\]\s*\"(.*)\"\s*(\d{3})\s(\d+)\s\"(.*)\"\s*\"(.*)\"\s*\"(.*)\"/ms) {
		print "1=$1; 2=$2; 3=$3; 4=$4; 5=$5; 6=$6; 7=$7; 8=$8; 9=$9\n";
	}
}
close IN;
