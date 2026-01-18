#!/usr/bin/perl -w

use strict;
use warnings;
use Term::ANSIColor;
use Getopt::Long;
use Data::Dumper;
use Digest::MD5;
use Digest::SHA qw( sha256_hex );
use Digest::Tiger;
use File::Find;
use File::Path;

our @db_files;

unless (defined($ARGV[0])) { die colored("You must specify a path as an argument! \n", "bold red"); }

find(\&subfiles, "$ARGV[0]");

foreach my $file ( @db_files ) {
	my @file_info = stat($file);
	#print Dumper(@file_info);
	my $md5 = calc_md5($file);
	my $sha256 = calc_sha256($file);
	my $tiger = calc_tiger($file);
	print "$md5|$sha256|$tiger|$file|$file_info[7]|".sprintf("%04o", $file_info[2])."| | \n";
}

sub subfiles {
	-f and push @db_files, $File::Find::name;
}

sub calc_md5 {
	my $filename = shift(@_);
	open FILE, "$filename" or die colored("Couldn't open file: $filename : $! \n", "bold red");
	binmode(FILE);
	my $md5 = Digest::MD5->new->addfile(*FILE)->hexdigest;
	close FILE or die colored("There was a problem closing the file ($filename): $! \n", "bold red");
	return $md5;
}

sub calc_sha256 {
	my $filename = shift(@_);
	open FILE, "$filename" or die colored("Couldn't open file: $filename : $! \n", "bold red");
	binmode(FILE);
	my $sha256 = Digest::SHA->new('sha256')->addfile(*FILE)->hexdigest;
	close FILE or die colored("There was a problem closing the file ($filename): $! \n", "bold red");
	return $sha256;
}

sub calc_tiger {
	my $filename = shift(@_);
	open FILE, "$filename" or die colored("Couldn't open file: $filename : $! \n", "bold red");
	binmode(FILE);
	my $tiger = Digest::Tiger::hexhash(<FILE>);
	close FILE or die colored("There was a problem closing the file ($filename): $! \n", "bold red");
	return $tiger;
}
