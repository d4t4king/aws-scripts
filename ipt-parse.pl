#!/usr/bin/perl -w

use strict;
use warnings;

use Geo::IP::PurePerl;
use Term::ANSIColor;
use Sort::Key::IPv4 qw(ipv4sort);
use Net::IPv4Addr qw( :all );
use Getopt::Long;
my ($help, $nocolor, $table, $automate, $noauto);
GetOptions(
	'h|help'			=>	\$help,
	'nc|no-color'		=>	\$nocolor,
	't|table'			=>	\$table,
	'automate'			=>	\$automate,
	'na|no-automate'	=>	\$noauto,
);

sub Usage() {
	print <<EOF;

$0 [-h] [-nc] [-t] [--automate]

-h	|	--help			Displays this help message.
-nc	|	--no-color		Turns off colorized text.
-t	|	--table			Prints output in an HTML table.  Forces --no-color.
		--automate		Automatically sets iptables rules based on certain 
						conditions.  WARNING: This could lock you out of your
						system temporarily, and requires a reboot to backout!
-na	|	--no-automate	Completely skips automatic addition of iptables rules,
						after parsing the output.  Ironically, this is good
						for running automatic reporting (via cron).

EOF
}

if ($help) { &Usage(); }
if ($table) { $nocolor=1; }

my $hostname = `hostname -f`;
chomp($hostname);
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

if ($noauto) {
	exit 0;
} else {
	my $src_ref = &source_net_count(keys %sources);
	use IPTables::ChainMgr;
	my %opts = (
		iptables	=>	'/sbin/iptables',
		iptout		=>	'/tmp/iptables.out',
		ipterr		=>	'/tmp/iptables.err',
		verbose		=>	0,
		debug		=>	0,
			### advanced options
 		'ipt_alarm' => 5,					### max seconds to wait for iptables execution.
		'ipt_exec_style' => 'waitpid', 		### can be 'waitpid',
											### 'system', or 'popen'.
		'ipt_exec_sleep' => 1,				### add in time delay between execution of
											### iptables commands (default is 0).
	);
	
	our $ipt_obj = new IPTables::ChainMgr(%opts)
			or die "[*] Could not acquire IPTables::ChainMgr object";

	if ($automate) {
		foreach my $pkt (keys %packets) {
			# TCP: 122.225.109.220:42060 => 172.31.41.85:22 (SYN)
			print "$pkt\n";
			if ($pkt =~ /(?:UDP|TCP)\: (.*) \=\> /) {
				my $src = $1;
				$src =~ s/(.*)\:.*/$1/;
				print "SRC-->  "; &nprintcyan($src); print "\n";
				my ($o, $t, $tt, $f) = split(/\./, $src);
				my $first_three = "$o.$t.$tt";
				my ($rule_num, $rule_count) = $ipt_obj->find_ip_rule("$src", "0.0.0.0/0", "filter", "INPUT", "LOGNDROP", {});
				if ($rule_num != 0) {
					&printblue("Found $rule_num of $rule_count");
				} else {
					#print "Found source subnet $src_ref->{$first_three} times.\n";
					&printyellow("Rule not found with source $src."); 
					#readline();
					print "Creating rule to block $src\n";
					my ($rv, $out_ar, $errs_ar) = $ipt_obj->add_ip_rule("$src/32", "0.0.0.0/0", 1, "filter", "INPUT", "LOGNDROP", {});
					&printgreen("$rv, ".join("|", @{$out_ar}).", ".join("|", @{$errs_ar}));
				}
			} else { &printred("Didn't match source IP."); }
		}

	} else {
		if ($nocolor) {
			print <<EOF;

This script can automatically add iptables rules
to you system's firewall.  Do you want to continue?
(Yes [y] or No [n])?
EOF
		} else {
			&printblue("\nThis script can automatically add iptables rules
to you system's firewall.  Do you want to continue?
(Yes [y] or No [n])?");
		}

		my $ans = readline();
		chomp($ans);
		if ($ans =~ /(?:[yY](?:es)?)/) {
			# proceed to the blocking

			foreach my $pkt (keys %packets) {
				# TCP: 122.225.109.220:42060 => 172.31.41.85:22 (SYN)
				print "$pkt\n";
				if ($pkt =~ /(?:UDP|TCP)\: (.*) \=\> /) {
					my $src = $1;
					$src =~ s/(.*)\:.*/$1/;
					print "SRC-->  "; &nprintcyan($src); print "\n";
					my ($o, $t, $tt, $f) = split(/\./, $src);
					my $first_three = "$o.$t.$tt";
					my ($rule_num, $rule_count) = $ipt_obj->find_ip_rule("$src", "0.0.0.0/0", "filter", "INPUT", "LOGNDROP", {});
					if ($rule_num != 0) {
						&printblue("Found $rule_num of $rule_count");
					} else {
						#print "Found source subnet $src_ref->{$first_three} times.\n";
						&printyellow("Rule not found with source $src."); 
						#readline();
						print "Create rule to block $src?\n";
						$ans = readline();
						chomp($ans);
						if ($ans =~ /(?:[yY](?:es)?)/ || $ans eq "\n") {
							my ($rv, $out_ar, $errs_ar) = $ipt_obj->add_ip_rule("$src/32", "0.0.0.0/0", 1, "filter", "INPUT", "LOGNDROP", {});
							&printgreen("$rv, ".join("|", @{$out_ar}).", ".join("|", @{$errs_ar}));
						}	
					}
				} else { &printred("Didn't match source IP."); }
			}	
		} else {
			exit 0;
		}
	}
}



#######################################################################
sub insert_ip_jump_rule($$$$) {
	# IPChains::ChainMgr oject, ip, from_chain, to_chain
	my ($ipt_obj, $ip, $from_chain, $to_chain) = @_;
	my ($rv, $out_ar, $errs_ar) = $ipt_obj->run_ipt_cmd("/sbin/iptables -I $from_chain 1 -s $ip -j $to_chain");
	return($rv, $out_ar, $errs_ar);
}
sub printyellow($) {
	my $l = shift(@_);
	print color 'yellow'; 
	print "$l";
	print color 'reset';
	print "\n";
}
sub printblue($) {
	my $l = shift(@_);
	print color 'bold blue'; 
	print "$l";
	print color 'reset';
	print "\n";
}
sub nprintcyan($) {
	my $l = shift(@_);
	print color 'bold cyan'; 
	print "$l";
	print color 'reset';
}
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

sub source_net_count(@) {
	my @srcs = @_;
	my (%first, %second, %third, %fourth);
	my @sorted = ipv4sort(@srcs);
	foreach my $s ( @sorted ) {
		my ($one, $two, $three, $four) = split(/\./, $s);
		$first{$one}++; $second{"$one.$two"}++;
		$third{"$one.$two.$three"}++;
	}

	return \%third;
}

