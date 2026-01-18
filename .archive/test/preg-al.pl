#!/usr/bin/perl -w

use strict;
use warnings;

my @unmatched;
open IN, "</var/log/nginx/access.log" or die "Couldn't open access log: $! \n";
while (my $line = <IN>) {
	chomp($line);
	#if ($line =~ /((?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))\s*(.)\s*(.)\s*\[(\d\d?\/.*\d{4}\:\d\d?\:\d\d?:\d\d?\s*\+\d+)\]\s*\"(.*)\"\s*(\d{3})\s(\d+)\s\"(.*)\"\s*\"(.*)\"\s*\"(.*)\"/ms) {
	#69.58.178.57 - - [09/Sep/2014:15:55:43 +0000] "GET / HTTP/1.1" 200 1250 "-" "Mozilla/5.0 (X11; Ubuntu; Linux i686; rv:14.0; ips-agent) Gecko/20100101 Firefox/14.0.1"
	my $ip = qr/(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)/;
	my $datestr = qr/\d\d?\/\w+\/\d{4}\:\d\d?\:\d\d?\:\d\d+ \+\d{4}/;
	if ($line =~ /($ip)\s*-\s*(.*?)\s*\[($datestr)\]\s*\"(.*?)\"\s*(\d{3})\s*(\d+)\s*\"(.*?)\"\s*\"(.*?)\"/x) {
		print "1=$1; 2=$2; 3=$3; 4=$4; 5=$5; 6=$6; 7=$7; 8=$8; \n"; #9=$9\n";
	} else {
		push @unmatched, $line;
	}
}
close IN;

print scalar(@unmatched)." unmatched lines.\n";
