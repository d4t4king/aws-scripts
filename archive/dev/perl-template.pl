#!/usr/bin/perl -w

use strict;
use warnings;

use Geo::IP::PurePerl;
use Term::ANSIColor;
use Getopt::Long qw( :config no_ignore_case bundling );
my ($help, $nocolor, $verbose);
$verbose = 0;
GetOptions(
	'h|help'		=>	\$help,
	'v|verbose+'		=>	\$verbose,
	'nc|no-color'		=>	\$nocolor,
);

sub Usage() {
	print <<EOF;

$0 [-h] [-v] [-nc]

-h	|	--help			Displays this help message.
-v	|	--verbose		Display more output.  More repetitions increases verbosity.
-nc	|	--no-color		Turns off colorized text.

EOF

	return 1;			# return true! (if perl had booleans)
}

if ($help) { &Usage(); }


