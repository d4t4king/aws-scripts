#!/usr/bin/perl -w

use v5.14;
use strict;
use warnings;
use threads;
use Data::Dumper;
use Geo::IP::PurePerl;
use XML::Simple;
use MIME::Lite;
use Net::IPv4Addr qw( :all );

my ($ip, $datestr, $req, $httpcode, $bytes, $ua);
my (%uas, %ips, %pmal, %dbuas, %dbips);
my (@unmatched);
my $hostname = `hostname -f`;
chomp($hostname);

my $gip = Geo::IP::PurePerl->new(GEOIP_STANDARD);
%dbuas = &get_sqlite_data("select ua from useragents");

%dbips = &get_sqlite_data("select ip from ips");

my $ip_rgx = qr/(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)/;
my $ds_rgx = qr/\d\d?\/.*\d{4}\:\d\d?\:\d\d?:\d\d?\s*\+\d+/;
open IN, "</var/log/nginx/access.log" or die "Couldn't open access log: $! \n";
while (my $line = <IN>) {
	if ($line =~ /($ip_rgx)\s*-\s*
					(.*?)			#HTTP user
					\s*\[($ds_rgx)\]\s*\"
					(.*)\"\s*		#request
					(\d{3})			#HTTP Code
					\s*(\d+)		#bytes sent
					\s*\"(.*)\"		#referrer
					\s*\"(.*)\"		#useragent
				/msx) {
		#print "1=$1; 2=$2; 3=$3; 4=$4; 5=$5; 6=$6; 7=$7; 8=$8; 9=$9\n";
		$ip = $1; $datestr = $3; $req = $4; $httpcode = $5; $bytes = $6; $ua = $8;
		#print "Found: $ip, $ua, $httpcode, $req\n";
		$uas{$ua}++; $ips{$ip}++;
		#print "REQ: $req\n";
		if ($req =~ /^(?:GET|HEAD) \/ HTTP\/1.[01]/) {
			# do nothing
		} elsif ($req =~ /^GET \/favicon\.ico/) {
			# do nothing
		} elsif ($req =~ /^GET \/clientaccesspolicy\.xml/ ) {
			# do nothing
		} elsif ($req =~ /^GET \/db\.php/) { 
			# still do nothing
		} elsif ($req =~ /^GET \/robots\.txt/) {
			# nope
		} elsif ($req =~ /^HEAD \/db\.php/) {
			# uh, uh
		} elsif ($req =~ /^(?:GET|HEAD) \/movies.php/) {
			# nothing
		} elsif (ipv4_in_network("161.209.0.0/16", $ip)) {
			# skip
		} elsif ($ip eq "66.27.87.243") {
			#skip
		} else {
			$pmal{$ip} = $req;
		}
	} elsif($line =~ /((?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))\s*(.)\s*(.)\s*\[(\d\d?\/.*\d{4}\:\d\d?\:\d\d?:\d\d?\s*\+\d+)\]\s*\"(.*)\"\s*(\d{3})\s(\d+)\s\"(.*)\"\s*\"(.*)\"\s*\"(.*)\"/ms) {
		#print "1=$1; 2=$2; 3=$3; 4=$4; 5=$5; 6=$6; 7=$7; 8=$8; 9=$9\n";
		$ip = $1; $datestr = $3; $req = $4; $httpcode = $5; $bytes = $6; $ua = $7;
		#print "Found: $ip, $ua, $httpcode, $req\n";
		$uas{$ua}++; $ips{$ip}++;
		#print "REQ: $req\n";
		if ($req =~ /^(?:GET|HEAD) \/ HTTP\/1.[01]/) {
			# do nothing
		} elsif ($req =~ /^GET \/favicon\.ico/) {
			# do nothing
		} elsif ($req =~ /^GET \/clientaccesspolicy\.xml/ ) {
			# do nothing
		} elsif ($req =~ /^GET \/db\.php/) { 
			# still do nothing
		} elsif ($req =~ /^GET \/robots\.txt/) {
			# nope
		} elsif ($req =~ /^HEAD \/db\.php/) {
			# uh, uh
		} elsif ($req =~ /^(?:GET|HEAD) \/movies.php/) {
			# nothing
		} elsif (ipv4_in_network("161.209.0.0/16", $ip)) {
			# skip
		} elsif ($ip eq "66.27.87.243") {
			#skip
		} else {
			$pmal{$ip} = $req;
		}
	} else {
		push @unmatched, $line;
	}
}
close IN;

#foreach my $ua (sort { $uas{$b}<=>$uas{$a} } keys %uas) {
#	print "$ua\t$uas{$ua}\n";
#}

print scalar(@unmatched)." unmatched lines.\n";
print "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@\n";
foreach my $p (sort keys %pmal ) {
	print "$p -> $pmal{$p}\n";
	#my $scanned = &is_scanned($p);
	#print STDERR "Scanned: $scanned\n";
	#my $thr = threads->create(sub { system("nmap -A -T3 -sS -oA $p $p"); return $?; });
	if (!&is_scanned($p)) {
		system("sudo nmap -A -T3 -sS -Pn -oA nmap_arch/$p $p >/dev/null 2>&1 &");
		&mark_scanned($p);
	}
}
print "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@\n";

foreach my $ua ( keys %uas ) {
	if (!exists($dbuas{$ua})) {
		#my $u = quotemeta($ua);
		#print "|$ua|\n";
		system("sqlite3 /home/ubuntu/access_data.db 'insert into useragents values(\"$ua\")'");
	}
}

foreach my $ip ( keys %ips ) {
	if (!exists($dbips{$ip})) {
		my $cc = $gip->country_code_by_addr($ip);
		my $name = $gip->country_name_by_addr($ip);
		#print "$ip,$cc,$name\n";
		system("sqlite3 /home/ubuntu/access_data.db 'insert into ips values(\"$ip\",\"$cc\",\"$name\",0)'");
	}
}


sub is_scanned() {
	my $ip = shift(@_);
	my $bool = `sqlite3 /home/ubuntu/access_data.db 'select scanned from ips where ip=\"$ip\"'`;
	if ((!defined($bool)) || ($bool eq "")) { $bool = 0; }
	#print STDERR "bool == $bool\n";
	return $bool;
}

sub mark_scanned() {
	my $ip = shift(@_);
	system("sqlite3 /home/ubuntu/access_data.db 'update ips set scanned=\"1\" where ip=\"$ip\"'");
}

# query the sqlite database for info.
# takes a sql string, 
# returns a hash
sub get_sqlite_data() {
	my $query = shift(@_);

	my %tmp;
	my @tmp = `sqlite3 /home/ubuntu/access_data.db "$query"`;
	foreach my $t ( @tmp ) {
		chomp($t);
		$tmp{$t}++;
	}

	return %tmp;
}
