#!/usr/bin/perl -w

use strict;
use warnings;

use Geo::IP::PurePerl;
use Term::ANSIColor;
use Getopt::Long;
my ($help, $nocolor);
GetOptions(
	'h|help'		=>	\$help,
	'nc|no-color'	=>	\$nocolor,
);

sub Usage() {
	print <<EOF;

$0 [-h] [-nc]

-h	|	--help			Displays this help message.
-nc	|	--no-color		Turns off colorized text.

EOF
}

if ($help) { &Usage(); }


