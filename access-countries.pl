#!/usr/bin/perl -w

use strict;
use warnings;

use Geo::IP::PurePerl;
use Data::Dumper;
use Term::ANSIColor;
use Getopt::Long qw( :config no_ignore_case bundling );

my ($help, $verbose, $log);
$verbose = 0;
GetOptions(
	'h|help'		=>	\$help,
	'v|verbose+'	=>	\$verbose,
	'l|log=s'		=>	\$log,
);

#my $access = '/var/log/nginx/access.log';
my $access;
if (defined($log)) {
	$access = $log;
} else {
	$access = '/tmp/access_log';
}
my (%ips,%ccs,%cns);
my $gip = Geo::IP::PurePerl->new(GEOIP_STANDARD);
my $hostname = `hostname -f`;
chomp($hostname);

open IN, "<$access" or die "Couldn't open access log: $! \n";
while (my $line = <IN>) {
	chomp($line);
	next if ($line =~ /^$/);
	my @fields = split(/\s+/, $line);
	my $ip = $fields[0];
	$ips{$ip}++;
	my $cc = $gip->country_code_by_addr($ip);
	next if ((!defined($cc)) || ($cc eq ""));
	$ccs{$cc}{$ip}++;
	$cns{$cc} = $gip->country_name_by_addr($ip);
}
close IN;

# update the database
#system("wget -O /tmp/GeoIP.dat.gz http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz > /dev/null 2>&1");
#system("gzip -d /tmp/GeoIP.dat.gz");
#system("cp -vf /tmp/GeoIP.dat /usr/local/share/GeoIP/");

# check if the database file exists
my $dbfile = '/www/db/countries.db';
if ( ! -f $dbfile ) {
	system("sqlite3 $dbfile 'CREATE TABLE countries (ip varchar(255), country_code varchar(4), country_name varchar(255), hitcount INTEGER);'");
}
if (( -f $dbfile ) && ( -z $dbfile )) {
	system("sqlite3 $dbfile 'CREATE TABLE countries (ip varchar(255), country_code varchar(4), country_name varchar(255), hitcount INTEGER);'");
}

my %records;
my @results = `sqlite3 $dbfile 'select ip, hitcount from countries';`;
foreach my $rec ( @results ) {
	chomp($rec);
	my ($dip, $dhc) = split(/\|/, $rec);
	$records{$dip} = $dhc;
}	

open OMAIL, ">/tmp/$$.m" or die "Couldn't open file ($$.m) for writing: $! \n";
print OMAIL <<EOF;
<html><body>
<table border="1">
EOF
foreach my $c ( sort(keys(%ccs)) ) {
	next if ((!defined($c)) || ($c eq ""));
	print OMAIL "<tr><td>$c</td><td>$cns{$c}</td><td>&nbsp;</td></tr>\n";
	foreach my $ip ( keys(%{$ccs{$c}}) ) {
		next if ((!defined($ip)) || ($ip eq ""));
		print OMAIL "<tr><td>&nbsp;</td><td>$ip</td><td>$ccs{$c}{$ip}</td></tr>\n";
		if (exists($records{$ip})) {
			my $total = $ccs{$c}{$ip} + $records{$ip};
			my $ec = system("sqlite3 /www/db/countries.db \"update countries set hitcount=$total where ip='$ip';\"");
			print "===> $ec <===\n";
		} else {
			my $ec = system("sqlite3 /www/db/countries.db \"insert into countries (ip, country_code, country_name, hitcount) values( '$ip', '$c', '$cns{$c}', '$ccs{$c}{$ip}')\";");
			print "===< $ec >===\n";
		}
	}
}

print OMAIL <<EOF;
</table>
EOF
close OMAIL;

system("mail -s \"IP Countries: $hostname\" -a \"Content-Type: text/html\" charles.heselton\@gmail.com < /tmp/$$.m");

unlink("/tmp/$$.m");
