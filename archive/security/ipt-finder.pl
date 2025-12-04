#!/usr/bin/perl -w

use strict;
use warnings;

use Term::ANSIColor;
use IPTables::ChainMgr;

my %opts = (
	'iptables'			=>	'/sbin/iptables',
	'iptout'			=>	'/tmp/iptables.out',
	'ipterr'			=>	'/tmp/iptables.err',
	'debug'				=>	0,
	'verbose'			=>	1,

	### advanced options
	'ipt_alarm'			=>	5,				### max seconds to wait for iptables execution.
	'ipt_exec_style'	=>	'waitpid',		### can by 'waitpid', 'system' or 'popen'.
	'ipt_exec_sleep'	=>	0,				### add in time delay between execution of 
											### iptables commands (default is 0).
);

my $ipt_obj = new IPTables::ChainMgr(%opts)
	or die "[*] Could not acquire IPTables::ChainMgr object";

my $rv = 0;
my $out_arr = [];
my $errs_arr = [];
my $rule_num = 0;

($rv, $out_arr, $errs_arr) = $ipt_obj->chain_exists('filter', 'LOGNDROP');
#print "$rv, ".join("|", @{$out_arr}).", ".join("|", @{$errs_arr})."\n";
if ($rv) {
	&nprintgreen("Chain exists.");
	($rv, $rule_num) = $ipt_obj->find_ip_rule('116.10.191.188', '0.0.0.0/0', 'filter', 'INPUT', 'LOGNDROP', {});
	print "$rv, $rule_num\n";
	if ($rv) {
		&nprintgreen("Rule found.");
	} else {
		&nprintred("Could not find rule.\n");
	}
} 

#######################################################################
sub nprintgreen($) {
	my $L = shift(@_);
	print color 'bold green';
	print "$L";
	print color 'reset';
	print "\n";
}
sub nprintred($) {
	my $L = shift(@_);
	print color 'bold red';
	print "$L";
	print color 'reset';
	print "\n";
}
