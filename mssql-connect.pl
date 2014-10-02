#!/usr/bin/perl -w

use strict;
use warnings;

use DBI;

#my $dbh = DBI->connect('DBI:Sybase="aws3.dataking.us"', 'charlie', 'I am the dataking!');
my $dbh = DBI->connect('DBI:ODBC:DNS', "charlie", 'Pepper123');
my $sth = $dbh->prepare('SELECT * FROM types');
my $rv = $sth->execute;
print "Return Value: $rv\n";
while (my $row = $sth->fetchrow_array) {
	print "$row\n";
}
$dbh->disconnect;
