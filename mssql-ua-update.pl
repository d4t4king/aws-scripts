#!/usr/bin/perl -w

use strict;
use warnings;

use DBI;
use Data::Dumper;

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
while (my @row = $sth->fetchrow_array) {
	#print "$row[0],$row[1]\n";
	$types{"$row[0]"} = "$row[1]";
	$type_ids{"$row[1]"} = "$row[0]";
}

# get all the user-agents from the mssql db
$dbh->{LongReadLen} = '255';
$sth = $dbh->prepare('SELECT id,useragent,hitcount,type_id FROM useragents2');
$sth->execute;
while (my @row = $sth->fetchrow_array) { 
	push @sql_uas, $row[1]; 
	$sql_uas{$row[1]}{'ua_id'}		=	$row[0];
	$sql_uas{$row[1]}{'hc'}			=	$row[2];
	$sql_uas{$row[1]}{'type_id'}	=	$type_ids{$row[3]};
}

# get the records from the
@sqlite_uas = `$sqlite $ldb "select * from useragents"`;

# loop through sqlite3 records and add as appropriate
my $found = 0; my $total = 0; my $added = 0; my $updated = 0;
my $errs = 0;
foreach my $rec ( @sqlite_uas ) {
	chomp($rec);
	$total++;
	my ($ua, $type, $hitcount) = split(/\|/, $rec);
	if (exists($sql_uas{$ua})) {
		$found++;
		my $sql = "UPDATE useragents2 SET hitcount='".($hitcount + $sql_uas{$ua}{'hc'})."' WHERE ID='$sql_uas{$ua}{'ua_id'}'";
		$sth = $dbh->prepare($sql);
		$sth->execute;
		$updated++;
	} else {
		if ($ua =~ /java.in/) { print STDERR "Ignoring user-aget: $ua\n"; $errs++; next; }
		my $sql = "INSERT INTO useragents2 VALUES (N'$ua', '$hitcount', '$type_ids{$type}');";
		#print "SQL:  $sql\n";
		$sth = $dbh->prepare($sql);
		$sth->execute;
		$added++;
	}
}

print "Found $found out of $total.  Added: $added.  Errors: $errs\n";

$dbh->disconnect;
