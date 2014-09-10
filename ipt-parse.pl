#!/usr/bin/perl -w

use strict;
use warnings;

use Geo::IP::PurePerl;
use Term::ANSIColor;
use Getopt::Long;
my ($help, $nocolor, $table);
GetOptions(
	'h|help'		=>	\$help,
	'nc|no-color'	=>	\$nocolor,
	't|table'		=> \$table,
);

sub Usage() {
	print <<EOF;

$0 [-h] [-nc]

-h	|	--help			Displays this help message.
-nc	|	--no-color		Turns off colorized text.
-t	|	--table			Prints output in an HTML table.  Forces --no-color.

EOF
}

if ($help) { &Usage(); }
if ($table) { $nocolor=1; }

my (%sources, %dests, %dpts, %spts, %flags, %protos, %packets);
open FILE, "</var/log/parsed-iptables" or die "Couldn't open logfile: $! \n";
while (my $line = <FILE>) {
	chomp($line);
	# Wed Sep 10 17:15:13 2014 aws1 kernel [12974860.556642] iptables-denied: IN=eth0 OUT= MAC=02:53:22:c2:cc:ff:02:40:0f:81:dd:60:08:00 SRC=59.55.141.120 DST=172.31.41.85 LEN=40 TOS=0x00 PREC=0x00 TTL=100 ID=256 PROTO=TCP SPT=34222 DPT=22 WINDOW=16384 RES=0x00 SYN URGP=0
	my ($src, $dst, $spt, $dpt, $proto, $flags);
	if ($line =~ /SRC=(.*) DST=(.*) LEN/) { $src=$1; $dst=$2; }
	if ($line =~ /PROTO=(.*) SPT=(.*) DPT=(.*?) /) { $proto=$1; $spt=$2; $dpt=$3; }
	if ($line =~ /RES=0x[0-9a-fA-F]+ (.*) URGP=0/) { $flags=$1; }
	$sources{$src}++; $dests{$dst}++; $dpts{$dpt}++; $spts{$spt}++;
	$protos{$proto}++; $flags{$flags}++;
	my $str = "$proto: $src:$spt => $dst:$dpt ($flags)";
	$packets{$str}++;
}
close FILE;


my $i = 0;
if ($table) { print "<table border=\"1\">\n"; }
if ($nocolor) { 
	if($table) { print "\t<tr><td colspan=\"2\">"; }
	print " ======== Top 10 Packets ======== "; 
	if ($table) { print "</td></tr>\n"; }
	else { print "\n"; }
}
else { &printred(" ======== Top 10 Packets ======== "); }
if ($table) { print "\t<tr><td>Packet</td><td>Count</td></tr>\n"; }
foreach my $p ( sort {$packets{$b} <=> $packets{$a}} keys %packets ) {
	if ($table) { print "\t<tr><td>$p</td><td>$packets{$p}</td><tr>\n"; } 
	else { print "$p\t\t$packets{$p}\n"; }
	$i++;
	if ($i >= 10) { last; }
}

$i = 0;
if ($nocolor) { 
	if ($table) { print "\t<tr><td colspan=\"3\">"; }
	print " ======== Top 10 Source IPs ======== "; 
	if ($table) { print "</td></tr>\n"; }
	else { print "\n"; }
} else { &printred(" ======== Top 10 Source IPs ======== "); }
if ($table) { print "\t<tr><td>IP</td><td>Country</td><td>Count</td></tr>\n"; }
my $gip = Geo::IP::PurePerl->new(GEOIP_STANDARD);
foreach my $s ( sort { $sources{$b} <=> $sources{$a} } keys %sources ) {
	my $country = $gip->country_name_by_addr($s);
	if ($table) {
		print "\t<tr><td>$s</td><td>$country</td><td>$sources{$s}</td></tr>\n";
	} else {
		print "$s\t\t";
		if ($nocolor) { print "$country\t\t"; }
		else { &nprintgreen("$country\t\t"); }
		print "$sources{$s}\n";
	}
	$i++;
	if ($i >= 10) { last; }
}
$i = 0;
if ($nocolor) { 
	if ($table) { print "\t<tr><td colspan=\"2\">"; }
	print " ======== Top 10 Destination Ports ======== ";
	if ($table) { print "</td></tr>\n"; }
	else { print "\n"; }
} else { &printred(" ======== Top 10 Destination Ports ======== "); }
if ($table) { print "\t<tr><td>Port</td><td>Count</td></tr>\n"; }
foreach my $d ( sort { $dpts{$b} <=> $dpts{$a} } keys %dpts ) {
	if ($table) { print "\t<tr><td>$d</td><td>$dpts{$d}</td></tr>\n"; }
	else { print "$d\t\t$dpts{$d}\n"; }
	$i++;
	if ($i >= 10) { last; }
}
if ($table) { print "</table>\n"; }

sub nprintgreen($) {
	my $l = shift(@_);
	print color 'bold green'; 
	print "$l";
	print color 'reset';
}
sub printgreen($) {
	my $l = shift(@_);
	print color 'bold green'; 
	print "$l";
	print color 'reset';
	print "\n";
}
sub printred($) {
	my $l = shift(@_);
	print color 'bold red'; 
	print "$l";
	print color 'reset';
	print "\n";
}
