#!/usr/bin/perl -w

use warnings;
use strict;
use Term::ANSIColor;

sub install_module() {
	my $mod_name = shift(@_);

	my $query_str = "http://search.cpan.org/search?query=$mod_name&mode=all";
	
	#eval{ use WWW::Mechanize; };
	#if ($@) { print colored("$@\n";, "red"); }
	use Data::Dumper;

	#my $mech = WWW::Mechanize->new();
	#$mech->get($query_str);

	#print Dumper($mech);

	my $wget = `which wget`;
	chomp($wget);
	my $curl = `which curl`;
	chomp($curl);

	my @output = `$curl -# $query_str 2>&1`;
	print @output."\n";
}

chomp($ARGV[0]);
&install_module("$ARGV[0]");
