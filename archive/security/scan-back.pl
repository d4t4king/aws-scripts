#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;

my @rows = `sqlite3 /home/ubuntu/access_data.db 'select * from ips where scanned="0"'`;

#print Dumper(@rows);
foreach my $row ( @rows ) {
	chomp($row);
	my ($ip, $cc, $cn, $scanned) = split(/\|/, $row);
	print "$row\n";
	if ($scanned != 1) {
		print "Scanning $ip...";
		system("nmap -A -sS -Pn -T3 -oA /home/ubuntu/nmap_arch/$ip $ip");
		print "done.\n";
		system("sqlite3 /home/ubuntu/access_data.db \"update ips set scanned='1' where ip='$ip'\"");
	}
}
