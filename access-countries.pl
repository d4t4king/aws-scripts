#!/usr/bin/perl -w

use strict;
use warnings;

use Geo::IP::PurePerl;
use Data::Dumper;

my $access = '/var/log/nginx/access.log';
my (%ips,%ccs,%cns);
my $gip = Geo::IP::PurePerl->new(GEOIP_STANDARD);

open IN, "<$access" or die "Couldn't open access log: $! \n";
while (my $line = <IN>) {
	chomp($line);
	my @fields = split(/\s+/, $line);
	my $ip = $fields[0];
	$ips{$ip}++;
	my $cc = $gip->country_code_by_addr($ip);
	next if ((!defined($cc)) || ($cc eq ""));
	$ccs{$cc}{$ip}++;
	$cns{$cc} = $gip->country_name_by_addr($ip);
}
close IN;

# print Dumper(%ips);
# exit 1;

# update the database
#system("wget -O /tmp/GeoIP.dat.gz http://geolite.maxmind.com/download/geoip/database/GeoLiteCountry/GeoIP.dat.gz > /dev/null 2>&1");
#system("gzip -d /tmp/GeoIP.dat.gz");
#system("cp -vf /tmp/GeoIP.dat /usr/local/share/GeoIP/");


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
	}
}

print OMAIL <<EOF;
</table>
EOF
#<br /><br /><hr width="90%"/>
#<table>
#<tr><td><h3>IP</h3></td><td><h3>Country Code</h3></td></tr>
#EOF

#foreach my $aip ( sort(keys(%ips)) ) {
#	my $cc = $gip->country_code_by_addr("$aip");
#	print OMAIL "<tr><td>$aip</td><td>$cc</td></tr>";
#}
#print OMAIL <<EOF;
#</table>
#</body></html>
#EOF

close OMAIL;

system("mail -t charles.heselton\@gmail.com -s \"IP Countries\" -a \"Content-Type: text/html\" < /tmp/$$.m");

unlink("/tmp/$$.m");
