#!/usr/bin/perl -w

use warnings;
use strict;

use XML::Simple;
use Term::ANSIColor;
use Data::Dumper;
use Cwd;
#use WWW::Mechanize;

my @scans;
my $archdir = '/home/ubuntu/nmap_arch';
opendir(DIR, $archdir) or die "Couldn't open read directory: $! \n";
while ( my $file = readdir(DIR) ) {
	#print "$file\n";
	my %scaninfo;
	my @parts = split(/\./, $file);
	next if ((!defined($parts[-1])) || ($parts[-1] eq ""));
	#print "$parts[-1]\n";
	if ($parts[-1] eq 'xml') {
		#print "$file\n";
		my $xml;
		eval{ $xml = XMLin("$archdir/$file", KeyAttr => ['portid', 'name'], ForceArray => qr/\b(?:port|osmatch)\b/); };
		#if ($@) { die "$@\n"; }
		next if ($@);
		#print Dumper($xml->{'host'});

		$scaninfo{'status'}		=	$xml->{'host'}{'status'}{'state'};
		$scaninfo{'addr'}		=	$xml->{'host'}{'address'}{'addr'};
		$scaninfo{'addr_type'}	=	$xml->{'host'}{'address'}{'addrtype'};
		$scaninfo{'starttime'}	=	$xml->{'host'}{'starttime'};
		$scaninfo{'endtime'}	=	$xml->{'host'}{'endtime'};
		$scaninfo{'hostname'}	=	$xml->{'host'}{'hostnames'}{'hostname'}{'name'};
		$scaninfo{'distance'}	=	$xml->{'host'}{'distance'}{'value'};
		if ((!defined($scaninfo{'hostname'})) || ($scaninfo{'hostname'} eq "")) { 
			$scaninfo{'hostname'} = "unresolved"; 
		}

		#print Dumper($scaninfo{'hostname'});
		foreach my $port ( sort keys %{$xml->{'host'}{'ports'}{'port'}} ) {
			#print Dumper($port);
			my %svcs;
			if ($xml->{'host'}{'ports'}{'port'}{$port}{'state'}{'state'} eq "open") {
				my $str = "$xml->{'host'}{'ports'}{'port'}{$port}{'protocol'}/$port";
				$svcs{$str} = $xml->{'host'}{'ports'}{'port'}{$port}{'service'}{'name'};
			
				push @{$scaninfo{'openports'}}, \%svcs;
			}
			#print Dumper(%svcs);
		}

		#print color 'bold green';
		#print scalar(keys(%svcs));
		#print color 'reset';
		if ((!defined($scaninfo{'openports'})) || (scalar(@{$scaninfo{'openports'}}) == 0)) {
			my %svcs;
			$svcs{'none'} = 'none';
			push @{$scaninfo{'openports'}}, \%svcs;
		}
		#print color 'bold red';
		#print scalar(keys(%svcs));
		#print color 'reset';
		
		foreach my $key ( sort keys %{$xml->{'host'}{'os'}{'osmatch'}} ) {
			my %os;
			$os{$key} = $xml->{'host'}{'os'}{'osmatch'}{$key}{'accuracy'};
			push @{$scaninfo{'osmatch'}}, \%os;
		}

		if ((!defined($scaninfo{'osmatch'})) || (scalar(@{$scaninfo{'osmatch'}}) == 0)) {
			my %os;
			$os{'none'} = 'none';
			push @{$scaninfo{'osmatch'}}, \%os;
		}
		#print Dumper(%scaninfo);
		#print Dumper($xml->{'host'});
		#last;
		push @scans, \%scaninfo;
	}
}
closedir(DIR);

my @webs;
print "IP,Hostname,Start Time,End Time,Open Ports,OS Matches\n";
foreach my $scan ( @scans ) {
	#print Dumper($scan);
	#last;
	# Have to unwrap the openports hash
	my $openports;
	eval {
		foreach my $ref ( sort @{$scan->{'openports'}} ) {
			if (defined($openports)) {
				$openports .= ":".join('', keys(%{$ref}));
			} else {
				$openports = join('', keys(%{$ref}));
			}
		}
	};
	if ($@) { print "ERROR: $@\n"; }
	# Have to unqrap the osmatch hash
	my $osmatches;
	foreach my $ref ( sort @{$scan->{'osmatch'}} ) {
		if (defined($osmatches)) {
			$osmatches .= ":".join('', keys(%{$ref}));
		} else {
			$osmatches = join('', keys(%{$ref}));
		}
	}
			
	print "$scan->{'addr'},$scan->{'hostname'},".localtime($scan->{'starttime'}).",";
	print localtime($scan->{'endtime'}).",$openports,$osmatches\n";
	foreach my $ref ( sort @{$scan->{'openports'}} ) {
		if (exists($ref->{'tcp/80'})) {
			print "$scan->{'addr'},$scan->{'hostname'}\n";
			push @webs, $scan->{'addr'};
			last;
		}
	}
}

my $cwd = getcwd();
if ( ! -d "/home/ubuntu/mirrors/" ) { mkdir "/home/ubuntu/mirrors"; }
chdir "/home/ubuntu/mirrors/";
foreach my $ip ( @webs ) {
	next if ($ip eq '66.27.87.243');	# Don't mirror my site.
	#my $web = WWW::Mechanize->new();
	#$web->get($ip);
	system("wget -q -t 1 -T 5 -m $ip");
}
chdir "$cwd";
