#!/usr/bin/perl -w

use strict;
use warnings;
no if $] >= 5.018, warnings => "experimental::smartmatch";
use feature qw(switch);
use Term::ANSIColor;
use Sort::Key::IPv4 qw(ipv4sort);;
use Data::Dumper;
use Geo::IP::PurePerl;
use URI::Encode;
use Net::IPv4Addr qw( :all );
my ($help, $nocolor);
use Getopt::Long;
GetOptions(
	'h|help'		=>	\$help,
	'nc|no-color'	=>	\$nocolor,
);

&usage if ($help);

my ($clientip, $datestring, $request, $httpstatus, $ua);
my @unmatched;
my (%clients, %countries, %requests, %requestips, %uaips);
open LOG, "</var/log/nginx/access.log" or die "Couldn't open access.log: $! \n";
#open LOG, "</tmp/access_log" or die "Couldn't open access.log: $! \n";
while (my $line = <LOG>) {
	chomp($line);
	next if ($line =~ /^$/);
	if ($line =~ /((?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))\s*\-\s*.*?\s*\[(.*?)\]\s*\"(.*?)\"\s*(\d+)\s*\d+\s*\".*?\"\s*\"(.*?)\"/) {
		$clientip = $1; $datestring = $2; $request = $3; $httpstatus = $4; $ua = $5;
		#print "$clientip | $request | $httpstatus\n";
		$clients{$clientip}++;
		$requests{$request}{$clientip}++;
		$requestips{$clientip}{$request}++;
		$uaips{$clientip}{$ua}++;
		#$uas{$ua}++;
	} elsif (/((?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))\s*(.)\s*(.)\s*\[(\d\d?\/.*\d{4}\:\d\d?\:\d\d?:\d\d?\s*\+\d+)\]\s*\"(.*)\"\s*(\d{3})\s(\d+)\s\"(.*)\"\s*\"(.*)\"\s*\"(.*)\"/ms) {
		$clientip = $1; $datestring = $3; $request = $4; $httpstatus = $5; $ua = $8;
		#print "$clientip | $request | $httpstatus\n";
		$clients{$clientip}++;
		$requests{$request}{$clientip}++;
		$requestips{$clientip}{$request}++;
		$uaips{$clientip}{$ua}++;
		#$uas{$ua}++;
	} else {
		push @unmatched, $line;
	}
}
close LOG;

if ($nocolor) {
	print "=" x 72; print "\n";
} else {
	print color "bold red"; print "=" x 72; print color "reset"; print "\n";
}

my $gi = Geo::IP::PurePerl->new(GEOIP_STANDARD);
foreach my $c ( ipv4sort keys %clients ) {
	my @rec = `whois $c`;
	my ($country, $org);
	foreach my $line ( @rec ) {
		chomp($line);
		given($line) {
			when ($line =~ /^country:[\s\t]*(.*)/i) { $country = $1; }
			when ($line =~ /^orgname:[\s|\t]*(.*)/i) { my $tmp = $1; if ((defined($org)) && ($org ne "")) { $org .= " $tmp"; } else { $org = $tmp } }
			when ($line =~ /^descr:[\s|\t]*(.*)/i) { my $tmp = $1; if ((defined($org)) && ($org ne "")) { $org .= $tmp; } else { $org = $tmp; } }
			when ($line =~ /^owner:[\s|\t]*(.*)/i) { my $tmp = $1; if ((defined($org)) && ($org ne "")) { $org .= $tmp; } else { $org = $tmp; } }
		}
	}
	my $cc = $gi->country_code_by_addr($c);
	my $cn = $gi->country_name_by_addr($c);
	$countries{$cn}++;
	if ((!defined($org)) || ($org eq "")) { $org = "NOT DEFINED"; }
		if ($nocolor) {
			print "$c \t :: $country :: $cc :: ";
		} else {
			print color 'green'; print "$c"; print color 'reset'; print "\t :: $country :: $cc :: "; print color 'yellow'; print "$cn"; print color 'reset';
		}
	if (length($cn) > 16) { 
		if ($nocolor) {
			print "\t:: $org ( ".join(" ", keys(%{$uaips{$c}}))." ) \n";
		} else {
			print "\t:: "; print color 'cyan'; print "$org"; print color 'reset'; print color 'green'; print " ( ".join(" ", keys(%{$uaips{$c}}))." ) "; print color 'reset'; print "\n"; 
		}
	} elsif (length($cn) > 8) { 
		if ($nocolor) {
			print "\t\t:: $org ( ".join(" ", keys(%{$uaips{$c}}))." ) \n";
		} else {
			print "\t\t:: "; print color 'cyan'; print "$org"; print color 'reset'; print color 'green'; print " ( ".join(" ", keys(%{$uaips{$c}}))." ) "; print color 'reset'; print "\n"; 
		}
	} else { 
		if ($nocolor) {
			print "\t\t\t:: $org ( ".join(" ", keys(%{$uaips{$c}}))." ) \n";
		} else {
			print "\t\t\t:: "; print color 'cyan'; print "$org"; print color 'reset'; print color 'green'; print " ( ".join("", keys(%{$uaips{$c}}))." ) "; print color 'reset'; print "\n"; 
		}
	}
	
	my $uri = URI::Encode->new( { encode_reserved => 0 } );
	foreach my $req ( keys %{$requestips{$c}} ) { 
		if ($req =~ /(?:GET|HEAD)\s*\/\s*/) { next; } 
		if ($req =~ /\%[0-9a-fA-F][0-9a-fA-F]/) {
			my $dcd = $uri->decode($req);
			if ($nocolor) {
				print "\\_> $dcd\n";
			} else {
				print color 'bold red'; print "\\_> $dcd\n"; print color 'reset'; 
			}
		} elsif ($req =~ /\\x[0-9a-fA-F][0-9a-fA-F]/) {
			#$req =~ s/\\//g; $req =~ s/x//g;
			$req =~ s{\\x(..)}{chr hex $1}eg;
			if ($nocolor) {
				print "\\_> $req\n";
			} else {
				print color 'bold red'; print "\\_> $req\n"; print color 'reset';
			}
		} else {
			print "\\_> $req\n";
		}
	}

	foreach my $ua ( keys %{$uaips{$c}} ) {
		given ($ua) {
			when (/ZmEu/) {
				print "BLOCK (ZmEu):  $c -> $ua \'iptables -I INPUT 1 -s $c -j DROP\'\n";
				&add_ipt_block($c);
			}
			when (/masss?can/) {
				print "BLOCK (masscan):  $c -> $ua \'iptables -I INPUT 1 -s $c -j DROP\'\n";
				&add_ipt_block($c);
			}
		}
	}				
}

if ($nocolor) {
	print scalar(@unmatched)." unmatched lines.\n";
} else {
	print color 'bold red'; print scalar(@unmatched)." unmatched lines.\n"; print color 'reset';
}
foreach my $line ( @unmatched ) {
	chomp($line);
	if ($nocolor) {
		print $line;
	} else {
		print color 'bold white on_blue'; print $line; print color 'reset'; print "\n";
	}
}

sub add_ipt_block($) {
	my $ip = shift(@_);
	
	use IPTables::ChainMgr;
	my %opts = (
		'iptables'			=>	'/sbin/iptables',
		'iptout'			=>	'/tmp/iptables.out',
		'ipterr'			=>	'/tmp/iptables.err',
		'debug'				=>	0,
		'verbose'			=>	0,
		## advanced options
		'ipt_alarm'			=>	5,
		'ipt_exec_style'	=>	'waitpid',
		'ipt_exec_sleep'	=>	0,
	);

	my $ipt_obj = new IPTables::ChainMgr(%opts)
		or die "[*] Could not acquire IPTables::ChainMgr object";
	### check for the LOGNDROP chain
	my ($rv, $out_arr, $errs_arr) = $ipt_obj->chain_exists('filter', 'LOGNDROP');
	if ($rv) { print "LOGNDROP chain exists.\n"; }
	else { $ipt_obj->create_chain('filter', 'LOGNDROP'); print "LOGNDROP chain created.\n"; }

	### chek to see if an input rule already exists
	($rv, $out_arr, $errs_arr) = $ipt_obj->find_ip_rule($ip, '0.0.0.0/0', 'filter', 'INPUT', 'LOGNDROP', {});
	if ($rv) {
		print "Rule exists.  Skipping.\n";
		return 0;
	} else {
		### add the rule
		if ($ip eq "66.27.87.243"      ||
			$ip eq "54.201.84.16"      ||
			$ip eq "54.68.91.48"       ||
			$ip eq "50.112.189.69"     ||
			$ip eq "54.68.176.135"     ||
			$ip eq "54.191.148.250"    ||
			$ip eq "54.69.1.206"       ||
			ipv4_in_network("161.209.0.0", $ip)) {
			print "Belligerently refusing to block $ip!\n";
			return 0;
		}

		($rv, $out_arr, $errs_arr) = $ipt_obj->add_ip_rule($ip, '0.0.0.0/0', 1, 'filter', 'INPUT', 'LOGNDROP', {});
		return $rv;
	}
}

sub usage {

	print <<END;

$0 -h|--help -nc|--nocolor

This script parses the active access log.

Options:

-h|--help				Displays this useful message then exits.
-nc|--nocolor				Turns off the color display.  This is useful for redirecting output, or running from cron.

END

	exit 0;
}
