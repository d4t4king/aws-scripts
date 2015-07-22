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
$sth = $dbh->prepare('SELECT id,useragent,hitcount,type_id FROM useragents2 where type_id="0" ORDER BY useragent');
$sth->execute;
while (my @row = $sth->fetchrow_array) {
	push @sql_uas, $row[1];
	$sql_uas{$row[1]}{'ua_id'}      =   $row[0];
	$sql_uas{$row[1]}{'hc'}         =   $row[2];
	$sql_uas{$row[1]}{'type_id'}    =   $type_ids{$row[3]};
}

my %to_write = ();;
foreach my $ua ( sort keys %sql_uas ) {
	$sth = $dbh->prepare("SELECT id FROM useragents2 WHERE useragent='".quotemeta($ua)."'");
	$sth->execute();
	my $found = 0;
	while (my @row = $sth->fetchrow_array) {
		$found = $row[0];
	}
	#print colored("Record ID: $found\n", "magenta");
	if ($found > 0) {
		$sth = $dbh->prepare("DELETE FROM useragents2 WHERE id='$found'");
		$sth->execute();
	}	
	$sth = $dbh->prepare("SELECT id FROM useragents2 WHERE useragent LIKE 'Mozilla3.0%'");
	$sth->execute();
	$found = 0;
	while (my @row = $sth->fetchrow_array) {
		$found = $row[0];
	}
	#print colored("Record ID: $found\n", "magenta");
	if ($found > 0) {
		$sth = $dbh->prepare("DELETE FROM useragents2 WHERE id='$found'");
		$sth->execute();
	}	
	given ($ua) {
		when (/Firefox\/[0-9.]+$/) {
			print colored("browser likely\n", "green");
			push @{$to_write{'browser likely'}}, $ua;
		}
		# Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)
		when (/Mozilla\/[0-9.]+ \(compatible; MSIE [0-9.]+; Windows NT [0-9.]+; .* \)/s) {
			print colored("browser likely\n", "green");
			push @{$to_write{'browser likely'}}, $ua;
		}
		# Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US;
		# Mozilla/5.0 (Windows; U; Windows NT 5.1;
		when (/Mozilla\/[0-9.]+ \(Windows; U; Windows NT [0-9.]+; (?:[a-z]{2}(?:-[a-zA-Z]{2})?).*\)/) {
			print colored("browser likely\n", "green");
			push @{$to_write{'browser likely'}}, $ua;
		}
		when (/Mozilla\/5.0 \(compatible; MSIE [0-9.]+; Windows NT [0-9.]+;/) {
			print colored("browser likely\n", "green");
			push @{$to_write{'browser likely'}}, $ua;
		}
		when (/Windows-Media-Player/) {
			print colored("media-player\n", "green");
			push @{$to_write{'media-player'}}, $ua;
		}
		when (/(?:(?:\/|(?:\\x|%)5[cC]|%2[fF])\.\.(?:\/|(?:\\x|%)5[cC]|%2[fF]))+/) {
			print colored("amature hax\n", "green");
			push @{$to_write{'amateur hax'}}, $ua;
		}
		when (/chroot-apach0day/) {
			print colored("amateur hax\n", "green");
			push @{$to_write{'amateur hax'}}, $ua;
		}
		when (/Mozilla\/42.0 \(compatible; MSIE 28.0; Win128\)/) {
			print colored("amateur hax\n", "green");
			push @{$to_write{'amateur hax'}}, $ua;
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
		when (/^Mozilla\/5.0 .* Chrome\/[0-9.]+.*Safari\/[0-9.]+$/) {
			print colored("browser likely\n", "green");
			push @{$to_write{'browser likely'}}, $ua;
		}
		when (/^Mozilla\/5.0 .* Firefox\/[23]\d.\d$/) {
			print colored("browser likely\n", "green");
			push @{$to_write{'browser likely'}}, $ua;
		}
		when (/(?:^Opera|PLAYSTATION 3)/) {
			print colored("browser likely\n", "green");
			push @{$to_write{'browser likely'}}, $ua;
		}
		when (/Mozilla\/5.0 \(Macintosh; (?:U;\s*)?Intel Mac OS X.*Safari/) {
			print colored("browser likely\n", "green");
			push @{$to_write{'browser likely'}}, $ua;
		}
		when (/(?:[Ss]can(?:ner)?|Porkbun\/Mustache|Morfeus Fucking Scanner|Hivemind|wscheck.com|SSL Labs|the beast|StatsInfo|COMODO SSL Checker|netscan.gtisc.gatech.edu|thunderstone|project25499.com|Nmap Scripting Engine|Netcraft Web Server Survey|panscient.com|NetcraftSurveyAgent|WhatWeb|NeohapsisLab|w3af|shellshock-scan|webinspect|[Vv]alidator|Google-Site-Verification|[Cc]loud mapping)/) {
			print colored("scanner\n", "green");
			push @{$to_write{'scanner'}}, $ua;
		}
		when (/(?:[Bb][Oo][Tt]|crawler|AppEngine|Test|IBM WebExplorer \/v0.94|DomainWho.is|Robocop|hosterstats|revolt|AccServer|paros|[Bb]rutus|wispr|immoral|LinkWalker|Validation|ImageWalker|spider|[Cc]rawler|TrackBack|SEOstats|Ask Jeeves)/) {
			print colored("bot\n", "green");
			push @{$to_write{'bot'}}, $ua;
		}
		when (/^\(\)\s*\{\s*[a-z:]+;\s*\};.*/) {
			print colored("shellshock\n", "green");
			push @{$to_write{'shellshock'}}, $ua;
		}
		when (/(?:iPhone|iPad|[Mm]obile|[Aa]ndroid|[Nn]okia)/) {
			print colored("mobile\n", "green");
			push @{$to_write{'mobile'}}, $ua;
		}
		when (/Go 1.1 package http/) {
			print colored("Go\n", "green");
			push @{$to_write{'automaton'}}, $ua;
		}
		when (/HTTP_Request2/) {
			print colored("php\n", "green");
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
		when (/wget/i) {
			print colored("wget\n", "green");
			push @{$to_write{'automaton'}}, $ua;
		}
		when (/Mozilla\/4.0 \(compatible; MSIE [0-9.]+;/) {
			print colored("browser likely\n", "green");
			push @{$to_write{'browser likely'}}, $ua;
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
