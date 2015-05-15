#!/usr/bin/perl -w

use strict;
use warnings;
no if $] >= 5.018, warnings => "experimental::smartmatch";
use feature qw/switch/;

use DBI;
use Data::Dumper;
use Term::ANSIColor;

my $webdir = '/www';
my $webdbdir = "$webdir/db";
my $ldb = "$webdbdir/useragents";
my $sqlite = '/usr/bin/sqlite3';

my (%types, %type_ids, %sql_uas);
my (@sqlite_uas);
my (@sql_uas);

my $dbh = DBI->connect('DBI:ODBC:DNS', "charlie", 'Pepper123') or
	die "Unable to connect to the server/database: $DBI::errstr";
my $sth = $dbh->prepare('SELECT * FROM types');
my $rv = $sth->execute;
#print "Return Value: $rv\n";

# get all the types and set up the reference hashes
while (my @row = $sth->fetchrow_array) {
	#print "$row[0],$row[1]\n";
	$types{"$row[0]"} = "$row[1]";
	$type_ids{"$row[1]"} = "$row[0]";
}

# get all the user-agents from the mssql db
$dbh->{LongReadLen} = '65535';
$sth = $dbh->prepare('SELECT id,useragent,hitcount,type_id FROM useragents2 where type_id="0"');
$sth->execute;
while (my @row = $sth->fetchrow_array) {
	push @sql_uas, $row[1];
	$sql_uas{$row[1]}{'ua_id'}      =   $row[0];
	$sql_uas{$row[1]}{'hc'}         =   $row[2];
	$sql_uas{$row[1]}{'type_id'}    =   $type_ids{$row[3]};
}

my %to_write = ();;
foreach my $ua ( sort keys %sql_uas ) {
	given ($ua) {
		when (/(?:(?:\/|(?:\\x|%)5[cC]|%2[fF])\.\.(?:\/|(?:\\x|%)5[cC]|%2[fF]))+/) {
			print colored("amature hax\n", "green");
			push @{$to_write{'hax'}}, $ua;
		}
		when (/^\\x22/) {
			print colored("malware\n", "green");
			push @{$to_write{'malware'}}, $ua;
		}
		when (/(?:ByZr|ZmEu)/) {
			print colored("malware\n", "green");
			push @{$to_write{'malware'}}, $ua;
		}
		when (/facebookexternalhit/) {
			print colored("automaton\n", "green");
			push @{$to_write{'automaton'}}, $ua;
		}
		when (/^Mozilla\/5.0 .* Chrome\/[234]\d.\d.\d{3,4}.\d/) {
			print colored("browser likely\n", "green");
			push @{$to_write{'browser likely'}}, $ua;
		}
		when (/^Mozilla\/5.0 .* Firefox\/[23]\d.\d$/) {
			print colored("browser likely\n", "green");
			push @{$to_write{'browser likely'}}, $ua;
		}
		when (/Mozilla\/5.0 \(Macintosh; (?:U;\s*)?Intel Mac OS X.*Safari/) {
			print colored("browser likely\n", "green");
			push @{$to_write{'browser likely'}}, $ua;
		}
		when (/(?:scanner|Porkbun\/Mustache|Morfeus Fucking Scanner|Hivemind|wscheck.com|SSL Labs|the beast|StatsInfo|COMODO SSL Checker|netscan.gtisc.gatech.edu|thunderstone|project25499.com|Nmap Scripting Engine|Netcraft Web Server Survey|panscient.com|NetcraftSurveyAgent|WhatWeb|NeohapsisLab)/) {
			print colored("scanner\n", "green");
			push @{$to_write{'scanner'}}, $ua;
		}
		when (/(bot|crawler|AppEngine|Test|IBM WebExplorer \/v0.94|DomainWho.is|Robocop|hosterstats|revolt|AccServer)/) {
			print colored("bot\n", "green");
			push @{$to_write{'bot'}}, $ua;
		}
		when (/^\(\)\s*\{\s*[a-z:]+;\s*\};.*/) {
			print colored("shellshock\n", "green");
			push @{$to_write{'shellshock'}}, $ua;
		}
		when (/(?:iPhone|iPad|[Mm]obile|[Aa]ndroid)/) {
			print colored("mobile\n", "green");
			push @{$to_write{'mobile'}}, $ua;
		}
		when (/Go 1.1 package http/) {
			print colored("Go\n", "green");
			push @{$to_write{'automaton'}}, $ua;
		}
		when (/perl/i) {
			print colored("Go\n", "green");
			push @{$to_write{'automaton'}}, $ua;
		}
		when (/PycURL\/7.19.7/) {
			print colored("pycurl\n", "green");
			push @{$to_write{'automaton'}}, $ua;
		}
		when (/python/i) {
			print colored("python\n", "green");
			push @{$to_write{'automaton'}}, $ua;
		}
		when (/java/i) {
			print colored("java\n", "green");
			push @{$to_write{'automaton'}}, $ua;
		}
		when (/curl/) {
			print colored("curl\n", "green");
			push @{$to_write{'automaton'}}, $ua;
		}
		default { print colored("No match: $ua\n", "yellow"); }
	}
}

#print Dumper(%to_write);
foreach my $t ( sort keys %to_write ) {
	foreach my $ua ( sort @{$to_write{$t}} ) {
		print "UPDATE useragents2 SET type_id='$type_ids{$t}' where useragent='$ua';\n";
		$sth = $dbh->prepare("UPDATE useragents2 SET type_id='$type_ids{$t}' where useragent='$ua';");
		
		$sth->execute();
	}
}
