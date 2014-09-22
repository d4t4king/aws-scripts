#!/usr/bin/perl -w

use strict;
use warnings;
no if $] >= 5.018, warnings => "experimental::smartmatch";
use feature qw(switch);

use Data::Dumper;
use IPTables::ChainMgr;

my %opts = (
	'iptables'	=>	'/sbin/iptables',
	'iptout'	=>	'/tmp/iptables.out',
	'ipterr'	=>	'/tmp/iptables.err',
	'debug'		=>	0,
	'verbose'	=>	0,
	### advanced options
	'ipt_alarm'			=>	5,			### max seconds to wait for iptables execution
	'ipt_exec_style'	=>	'waitpid',	### can be 'waitpid', 'system' or 'popen'
	'ipt_exec_sleep'	=>	0,			### add in time delay before execution of
										### iptables commands (default is 0).
);

my @existing_chains;
my @created_chains;
my @existing_rules;
my @created_rules;

my $ipt_obj = new IPTables::ChainMgr(%opts)
	or die "[*] Could not acquire IPTables::ChainMgr object";

my $rv = 0;
my $out_arr = [];
my $errs_arr = [];
my $num_rules = 0;
my @chains;				# = [ 'LOGNDROP', 'fail2ban-ssh', 'monitorix_IN_' ];
push(@chains, 'LOGNDROP', 'fail2ban-ssh', 'monitorix_IN_');

#print Dumper(@chains);
#exit 1;

foreach my $chain ( @chains ) {
	given ($chain) {
		when (/(?:LOGNDROP|fail2ban-ssh)/) {
			($rv, $out_arr, $errs_arr) = $ipt_obj->chain_exists('filter', $chain);
			if ($rv) {	# 1 = true
				print "$chain chain exists.\n";
				push(@existing_chains, "$chain");
				if ($chain eq "LOGNDROP") {
					($rv, $num_rules) = $ipt_obj->find_ip_rule('0.0.0.0/0', '0.0.0.0/0', 'filter', 'LOGNDROP', 'DROP', {});
					if ($rv) {
						print "LOGNDROP/DROP rule exists in position $rv.\n";
						push(@existing_rules, '0.0.0.0/0, 0.0.0.0/0, filter, LOGNDROP, DROP');
					} else {
						print "LOGNDROP/DROP rule not found.  Creating it.\n";
						$ipt_obj->add_ip_rule('0.0.0.0/0', '0.0.0.0/0', 1, 'filter', 'LOGNDROP', 'DROP', {});
						push(@created_rules, '0.0.0.0/0, 0.0.0.0/0, 1, filter, LOGNDROP, DROP');
					}
					($rv, $num_rules) = $ipt_obj->find_ip_rule('0.0.0.0/0', '0.0.0.0/0', 'filter', 'LOGNDROP', 'LOG', {});
					if ($rv) {
						print "LOGNDROP/LOG rule exists in position $rv.\n";
						push(@existing_rules, '0.0.0.0/0, 0.0.0.0/0, filter, LOGNDROP, LOG');
					} else {
						print "LOGNDROP/LOG rule not found.  Creating it.\n";
						$ipt_obj->run_ipt_cmd('/sbin/iptables -I LOGNDROP 1 -m limit --limit 5/min -j LOG --log-prefix "specific-deny: "');
						push(@created_rules, '-I LOGNDROP 1 -m limit --limit 5/min -j LOG --log-prefix "specific-deny: "');
					}
				} elsif($chain eq 'fail2ban-ssh') {
					($rv, $out_arr, $errs_arr) = $ipt_obj->run_ipt_cmd("/sbin/iptables -nvL $chain");
					#print Dumper($out_arr);
					my $found = 0;	# false
					foreach my $l (@{$out_arr}) {
						chomp($l);
						given ($l) {
							when (/Chain fail2ban-ssh \(\d+ references\)/) { next; }
							when (/pkts bytes target     prot opt in     out     source               destination/) { next; }
							when (/\s*\d+[kKmM]?\s*\d+[kKmM]? RETURN     all  --  \*      \*       0.0.0.0\/0            0.0.0.0\/0/) { next; }
							default {
							}
						}
					}
				}
			} else {	# create it
				print "$chain not found.  Creating it.\n";
				$ipt_obj->create_chain('filter', $chain);
				push(@created_chains, "$chain");
				$ipt_obj->run_ipt_cmd('/sbin/iptables -I LOGNDROP 1 -m limit --limit 5/min -j LOG --log-prefix "specific-deny: "');
				push(@created_rules, '-I LOGNDROP 1 -m limit --limit 5/min -j LOG --log-prefix "specific-deny: "');
				$ipt_obj->append_ip_rule('0.0.0.0/0', '0.0.0.0/0', 'filter', 'LOGNDROP', 'DROP', {});
				push(@created_rules, '0.0.0.0/0, 0.0.0.0/0, 1, filter, LOGNDROP, DROP');
			}
		}
		when (/monitorix_IN_/) {
			for (my $i=0; $i <= 8; $i++ ) {
				($rv, $out_arr, $errs_arr) = $ipt_obj->chain_exists('filter', "$chain$i");
				if ($rv) {
					print "$chain$i chain exists.\n";
					push(@existing_chains, "$chain");
				} else {
					print "$chain$i not found.  Creating it.\n";
					$ipt_obj->create_chain('filter', "$chain$i");
					push(@created_chains, "$chain");
				}
			}
		}
		default {
			print "Error: $chain\n";
		}
	}
}
