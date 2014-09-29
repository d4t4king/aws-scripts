#!/usr/bin/perl -w

use strict;
use warnings;

use Data::Dumper;

my (@template, @l_exc, @t_exc);
my (%template, %l_exc, %t_exc);
# slurp in the template file.
open IN, "</root/iptables-template" or die "Could not open template file: $! \n";
while (my $line = <IN>) {
	chomp($line);
	push @template, $line;
	$template{$line}++;
}
close IN or die "Could not close templat file: $! \n";

# get the local rules
my @iptables = `/sbin/iptables-save`;
my %iptables;
foreach my $r ( @iptables ) {
	chomp($r);
	$iptables{$r}++;
}

#print Dumper(%template);
#print "=====================================\n";
#print Dumper(%iptables);
#exit 0;

# set local exceptions, i.e. things that are in the template but not local.
foreach my $r ( keys %template ) {
	chomp($r);
	if (exists($iptables{$r})) { next; } 
	elsif ($r =~ /^#/) { next; }		# ignore comments
	else { $l_exc{$r}++; }
}

# set template excpetions, i.e. things NOT in the template that are local.
foreach my $r ( @iptables ) {
	chomp($r);
	if (exists($template{$r})) { next; }
	elsif ($r =~ /^#/) { next; }		# ignore comments
	else { $t_exc{$r}++; }
}

print "Local excpetions (In template, NOT in local):\n";
#print Dumper(%l_exc);
foreach my $rule ( sort keys %l_exc ) { 
	# ignore chain policies that are passing/dropping packets
	next if ($rule =~ /:INPUT DROP \[\d+\:\d+]/);
	print "$rule\n"; 
}
print "Template exceptionsi (in local, NOT in template):\n";
#print Dumper(%t_exc);
foreach my $rule ( sort keys %t_exc ) { print "$rule\n"; }

