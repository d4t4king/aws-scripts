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

my ($clientip, $datestring, $request, $httpstatus, $ua);
my @unmatched;
my (%clients, %countries, %requests, %requestips, %uaips, %uas);
open LOG, "</tmp/access_log" or die "Couldn't open access.log: $! \n";
while (my $line = <LOG>) {
	chomp($line);
	if ($line =~ /((?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))\s*\-\s*.*?\s*\[(.*?)\]\s*\"(.*?)\"\s*(\d+)\s*\d+\s*\".*?\"\s*\"(.*?)\"/) {
		$clientip = $1; $datestring = $2; $request = $3; $httpstatus = $4; $ua = $5;
		#print "$clientip | $request | $httpstatus\n";
		$clients{$clientip}++;
		$requests{$request}{$clientip}++;
		$requestips{$clientip}{$request}++;
		$uaips{$clientip}{$ua}++;
		$uas{$ua}++;
	} else {
		push @unmatched, $line;
	}
}
close LOG;

print color "bold red"; print "=" x 72; print color "reset"; print "\n";

my $gi = Geo::IP::PurePerl->new(GEOIP_STANDARD);
foreach my $c ( ipv4sort keys %clients ) {
	my @rec = `whois $c`;
	my ($country, $org);
	foreach my $line ( @rec ) {
		chomp($line);
		given($line) {
			when ($line =~ /^country:[\s\t]*(.*)/i) { $country = $1; }
			when ($line =~ /^orgname:[\s|\t]*(.*)/i) { my $tmp = $1; if ((defined($org)) && ($org ne "")) { $org .= " $tmp"; } else { $org = $tmp } }
			when ($line =~ /^descr:[\s|\t]*(.*)/i) { my $tmp = $1; if ((defined($org)) && ($org ne "")) { $org .= " $tmp"; } else { $org = $tmp; } }
			when ($line =~ /^owner:[\s|\t]*(.*)/i) { my $tmp = $1; if ((defined($org)) && ($org ne "")) { $org .= " $tmp"; } else { $org = $tmp; } }
		}
	}
	my $cc = $gi->country_code_by_addr($c);
	my $cn = $gi->country_name_by_addr($c);
	$countries{$cn}++;
	if ((!defined($org)) || ($org eq "")) { $org = "NOT DEFINED"; }
	print color 'green'; print "$c"; print color 'reset'; print "\t :: $country :: $cc :: "; print color 'yellow'; print "$cn"; print color 'reset';
	if (length($cn) > 16) { 
		print "\t:: "; print color 'cyan'; print "$org"; print color 'reset'; print color 'green'; print " ( ".join(" ", keys(%{$uaips{$c}}))." ) "; print color 'reset'; print "\n"; 
	} elsif (length($cn) > 8) { 
		print "\t\t:: "; print color 'cyan'; print "$org"; print color 'reset'; print color 'green'; print " ( ".join(" ", keys(%{$uaips{$c}}))." ) "; print color 'reset'; print "\n"; 
	} else { 
		print "\t\t\t:: "; print color 'cyan'; print "$org"; print color 'reset'; print color 'green'; print " ( ".join("", keys(%{$uaips{$c}}))." ) "; print color 'reset'; print "\n"; 
	}
	
	my $uri = URI::Encode->new( { encode_reserved => 0 } );
	foreach my $req ( keys %{$requestips{$c}} ) { 
		if ($req =~ /(?:GET|HEAD)\s*\/\s*/) { next; } 
		if ($req =~ /\%[0-9a-fA-F][0-9a-fA-F]/) {
			my $dcd = $uri->decode($req);
			print color 'bold red'; print "\\_> $dcd\n"; print color 'reset'; 
		} elsif ($req =~ /\\x[0-9a-fA-F][0-9a-fA-F]/) {
			#$req =~ s/\\//g; $req =~ s/x//g;
			$req =~ s{\\x(..)}{chr hex $1}eg;
			print color 'bold red'; print "\\_> $req\n"; print color 'reset';
		} else {
			print "\\_> $req\n";
		}
	}

	foreach my $ua ( keys %{$uaips{$c}} ) {
		given ($ua) {
			when (/ZmEu/) {
				print "BLOCK (ZmEu):  $c -> $ua \'iptables -I INPUT -s $c -j DROP\'\n";
			}
			when (/masss?can/) {
				print "BLOCK (masscan):  $c -> $ua \'iptables -I INPUT -s $c -j DROP\'\n";
			}
		}
	}				

}

print color 'bold red'; print scalar(@unmatched)." unmatched lines.\n"; print color 'reset';
foreach my $line ( @unmatched ) {
	chomp($line);
	print color 'bold white on_blue'; print $line; print color 'reset'; print "\n";
}


#foreach my $ua (keys %uas) {
#	my $data = `/usr/bin/sqlite3 /usr/share/nginx/html/db/useragents "SELECT uas,hitcount from useragents where uas='$ua'"`;
#	chomp($data);
#	#print Dumper($data);
#	my ($dbus, $hc) = split(/\|/, $data);
#	if ((!defined($data)) || ($data eq "")) {
#		system("/usr/bin/sqlite3 /usr/share/nginx/html/db/useragents \"insert into useragents values('$ua', '', '$uas{$ua})\"");
#	}
#}
