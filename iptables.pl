#!/usr/bin/perl -w

use strict;
use warnings;
no if $] >= 5.018, warnings => "experimental::smartmatch";
use feature qw(switch);

use Data::Dumper;
use IPTables::ChainMgr;
use Term::ANSIColor;

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

my %allowed_ports = (
	'tcp|25'	=>	1,
	'tcp|22'	=>	1,
	'tcp|80'	=>	1,
	'tcp|443'	=>	1,
	'tcp|4444'	=>	1,
	'tcp|8080'	=>	1,
	'tcp|4505'	=>	1,
	'tcp|4506'	=>	1,
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

print "Checking for allowed port rules...\n";
foreach my $port ( sort keys %allowed_ports ) {
	my ($proto, $prt) = split(/\|/, $port);
	($rv, $num_rules) = $ipt_obj->find_ip_rule('0.0.0.0/0', '0.0.0.0/0', 'filter', 'INPUT', 'ACCEPT', { 'normalize' => 1, "protocol" => $proto, 'd_port' => $prt });
	if ($rv) {
		&printgreen("Found allowed port rule: $port\n");
		push(@existing_rules, "-A INPUT -p $proto -m $proto --dport $prt -j ACCEPT");
	} else {
		&printred("Allowed port rule not found: $port\n");
		&printcyan("\tCreating rule.\n");
		my $pos = $num_rules - 5;
		($rv, $out_arr, $errs_arr) = $ipt_obj->add_ip_rule('0.0.0.0/0', '0.0.0.0/0', $pos, 'filter', 'INPUT', 'ACCEPT', { 'normalize' => 1, 'protocol' => "$proto", 'd_port' => "$prt" });
		#&printred("rv = $rv, pos = $pos, proto = $proto, prt = $prt\n");
		push(@created_rules, "-I INPUT $pos -p $proto --dport $prt -j ACCEPT");
	}
}

print "Checking for lo rules...\n";
($rv, $num_rules) = $ipt_obj->find_ip_rule('0.0.0.0/0', '0.0.0.0/0', 'filter', 'INPUT', 'ACCEPT', { 'input' => 'lo' });
if ($rv) {
	&printgreen("INPUT lo rule found.\n");
	push(@existing_rules, '-A INPUT -i lo -j ACCEPT');
} else {
	&printred("INPUT lo rule NOT found.\n");
	#&printcyan("\tCreating rule...\n");
	#($rv, $out_arr, $errs_arr) = $ipt_obj->run_ipt_cmd('/sbin/iptables -I INPUT '.($num_rules - 5).' -i lo -j ACCEPT');
	push(@created_rules, '-A INPUT -i lo -j ACCEPT');
}
($rv, $num_rules) = $ipt_obj->find_ip_rule('0.0.0.0/0', '0.0.0.0/0', 'filter', 'OUTPUT', 'ACCEPT', { 'out' => 'lo' });
if ($rv) {
	&printgreen("OUTPUT lo rule found.\n");
	push(@existing_rules, '-A OUTPUT -o lo -j ACCEPT');
} else {
	&printred("OUTPUT lo rule NOT found.\n");
	&printcyan("Creating rule...\n");
	my $pos = $num_rules - 5;
	($rv, $out_arr, $errs_arr) = $ipt_obj->add_ip_rule('0.0.0.0/0', '0.0.0.0/0', 1, 'filter', 'OUTPUT', 'ACCEPT', { 'out' => 'lo' });
	if ($rv) { &printgreen("success.\n"); }
	push(@created_rules, '-A OUTPUT -o lo -j ACCEPT');
}

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
						push(@existing_rules, '-A LOGNDROP -j DROP');
					} else {
						print "LOGNDROP/DROP rule not found.  Creating it.\n";
						$ipt_obj->add_ip_rule('0.0.0.0/0', '0.0.0.0/0', 1, 'filter', 'LOGNDROP', 'DROP', {});
						push(@created_rules, '-A LOGNDROP -j DROP');
					}
					($rv, $num_rules) = $ipt_obj->find_ip_rule('0.0.0.0/0', '0.0.0.0/0', 'filter', 'LOGNDROP', 'LOG', {});
					if ($rv) {
						print "LOGNDROP/LOG rule exists in position $rv.\n";
						push(@existing_rules, '-A LOGNDROP -m limit --limit 5/min -j LOG --log-prefix "specific-deny: "');
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
							when (/\s*\d+[kKmM]?\s*\d+[kKmM]? RETURN     all  --  \*      \*       0.0.0.0\/0            0.0.0.0\/0/) { push(@existing_rules, '-A fail2ban-ssh -j RETURN'); next; }
							default {
								if (/REJECT/) { $found=1; }
							}
						}
					}
					if ($found) {
						print "Found at least one fail2ban-ssh REJECT rule.  Ignoring for now.\n";
					}
					($rv, $out_arr, $errs_arr) = $ipt_obj->run_ipt_cmd("/sbin/iptables -nvL INPUT --line-numbers");
					#print Dumper($out_arr);
					$found = 0;	# false
					my $pos = 0;
					foreach my $l (@{$out_arr}) {
						chomp($l);
						if ($l =~ /(\d+)\s*\d+\s*\d+[kKmM]? fail2ban-ssh  tcp  --  \*      \*       0\.0\.0\.0\/0            0\.0\.0\.0\/0            multiport dports 22/) {
							$found=1; $pos=$1;
						}
					}
					if ($found) {
						&printgreen("fail2ban-ssh jump rule exists in INPUT in position $pos.\n");
					} else {
						&printred("fail2ban-ssh jump rule not found in INPUT.\n");
					}
				}
			} else {	# create it
				print "$chain not found.  Creating it.\n";
				$ipt_obj->create_chain('filter', $chain);
				push(@created_chains, "$chain");
				$ipt_obj->run_ipt_cmd('/sbin/iptables -I LOGNDROP 1 -m limit --limit 5/min -j LOG --log-prefix "specific-deny: "');
				push(@created_rules, '-I LOGNDROP 1 -m limit --limit 5/min -j LOG --log-prefix "specific-deny: "');
				$ipt_obj->append_ip_rule('0.0.0.0/0', '0.0.0.0/0', 'filter', 'LOGNDROP', 'DROP', {});
				push(@created_rules, '-A LOGNDROP -j DROP');
			}
		}
		when (/monitorix_IN_/) {
			for (my $i=0; $i <= 8; $i++ ) {
				($rv, $out_arr, $errs_arr) = $ipt_obj->chain_exists('filter', "$chain$i");
				if ($rv) {
					print "$chain$i chain exists.\n";
					push(@existing_chains, "$chain$i");
					my ($mrule, $prule, $oprule, $pt, $proto);
					given ($i) {
						when (0) {
							$mrule = "'0.0.0.0/0', '0.0.0.0/0', 'filter', 'INPUT', $chain$i, { 'normalize'=>1, 'protocol'=>'tcp', 's_port'=>'1024:65535', 'd_port'=>'25', 'ctstate'=>'NEW,RELATED,ESTABLISHED' }";
							$prule = "-A INPUT -p tcp -m tcp --sport 1024:65535 --dport=25 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j $chain$i";
							$oprule = "-A OUTPUT -p tcp -m tcp --sport 25 --dport 1024:65535 -m conntrack --ctstate RELATED,ESTABLISHED -j $chain$i";
							$pt = 25;
							$proto = "tcp";
						}
						when (1) {
							$mrule = "'0.0.0.0/0', '0.0.0.0/0', 'filter', 'INPUT', $chain$i, { 'protocol'=>'tcp', 's_port'=>'1024:65535', 'd_port'=>'21', 'ctstate'=>'NEW,RELATED,ESTABLISHED' }";
							$prule = "-A INPUT -p tcp -m tcp --sport 1024:65535 --dport 21 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j $chain$i";
							$oprule = "-A OUTPUT -p tcp -m tcp --sport 21 --dport 1024:65535 -m conntrack --ctstate RELATED,ESTABLISHED -j $chain$i";
							$pt = 21;
							$proto = "tcp";
						}
						when (2) {
							$mrule = "0.0.0.0/0', '0.0.0.0/0', 'filter', 'INPUT', $chain$i, { 'protocol'=>'tcp', 's_port'=>'1024:65535', 'd_port'=>'80', 'ctstate'=>'NEW,RELATED,ESTABLISHED' }";
							$prule = "-A INPUT -p tcp -m tcp --sport 1024:65535 --dport 80 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j $chain$i";
							$oprule = "-A OUTPUT -p tcp -m tcp --sport 80 --dport 1024:65535 -m conntrack --ctstate RELATED,ESTABLISHED -j $chain$i";
							$pt = 80;
							$proto = "tcp";
						}
						when (3) {
							$mrule = "'0.0.0.0/0', '0.0.0.0/0', 'filter', 'INPUT', $chain$i, { 'protocol'=>'tcp', 's_port'=>'1024:65535', 'd_port'=>'22', 'ctstate'=>'NEW,RELATED,ESTABLISHED' }";
							$prule = "-A INPUT -p tcp -m tcp --sport 1024:65535 --dport 22 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j $chain$i";
							$oprule = "-A OUTPUT -p tcp -m tcp --sport 22 --dport 1024:65535 -m conntrack --ctstate RELATED,ESTABLISHED -j $chain$i";
							$pt = 22;
							$proto = "tcp";
						}
						when (4) {
							$mrule = "'0.0.0.0/0', '0.0.0.0/0', 'filter', 'INPUT', $chain$i, { 'protocol'=>'tcp', 's_port'=>'1024:65535', 'd_port'=>'110', 'ctstate'=>'NEW,RELATED,ESTABLISHED' }";
							$prule = "-A INPUT -p tcp -m tcp --sport 1024:65535 --dport 110 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j $chain$i";
							$oprule = "-A OUTPUT -p tcp -m tcp --sport 110 --dport 1024:65535 -m conntrack --ctstate RELATED,ESTABLISHED -j $chain$i";
							$pt = 110;
							$proto = "tcp";
						}
						when (5) {
							$mrule = "'0.0.0.0/0', '0.0.0.0/0', 'filter', 'INPUT', $chain$i, { 'protocol'=>'tcp', 's_port'=>'1024:65535', 'd_port'=>'139', 'ctstate'=>'NEW,RELATED,ESTABLISHED' }";
							$prule = "-A INPUT -p tcp -m tcp --sport 1024:65535 --dport 139 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j $chain$i";
							$oprule = "-A OUTPUT -p tcp -m tcp --sport 139 --dport 1024:65535 -m conntrack --ctstate RELATED,ESTABLISHED -j $chain$i";
							$pt = 139;
							$proto = "tcp";
						}
						when (6) {
							$mrule = "'0.0.0.0/0', '0.0.0.0/0', 'filter', 'INPUT', $chain$i, { 'protocol'=>'tcp', 's_port'=>'1024:65535', 'd_port'=>'3306', 'ctstate'=>'NEW,RELATED,ESTABLISHED' }";
							$prule = "-A INPUT -p tcp -m tcp --sport 1024:65535 --dport 3306 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j $chain$i";
							$oprule = "-A OUTPUT -p tcp -m tcp --sport 3306 --dport 1024:65535 -m conntrack --ctstate RELATED,ESTABLISHED -j $chain$i";
							$pt = 3306;
							$proto = "tcp";
						}
						when (7) {
							$mrule = "'0.0.0.0/0', '0.0.0.0/0', 'filter', 'INPUT', $chain$i, { 'protocol'=>'udp', 's_port'=>'1024:65535', 'd_port'=>'53', 'ctstate'=>'NEW,RELATED,ESTABLISHED' }";
							$prule = "-A INPUT -p udp -m udp --sport 1024:65535 --dport 53 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j $chain$i";
							$oprule = "-A OUTPUT -p udp -m udp --sport 53 --dport 1024:65535 -m conntrack --ctstate RELATED,ESTABLISHED -j $chain$i";
							$pt = 53;
							$proto = "udp";
						}
						when (8) {
							$mrule = "'0.0.0.0/0', '0.0.0.0/0', 'filter', 'INPUT', $chain$i, { 'protocol'=>'tcp', 's_port'=>'1024:65535', 'd_port'=>'143', 'ctstate'=>'NEW,RELATED,ESTABLISHED' }";
							$prule = "-A INPUT -p tcp -m tcp --sport 1024:65535 --dport 143 -m conntrack --ctstate NEW,RELATED,ESTABLISHED -j $chain$i";
							$oprule = "-A OUTPUT -p tcp -m tcp --sport 143 --dport 1024:65535 -m conntrack --ctstate RELATED,ESTABLISHED -j $chain$i";
							$pt = 143;
							$proto = "tcp";
						}
						default { &printred("Error: unexpected monitorix rule ($i)\n"); }
					}
					#&printyellow("$mrule\n");
					($rv, $num_rules) = $ipt_obj->find_ip_rule('0.0.0.0/0', '0.0.0.0/0', 'filter', 'INPUT', "$chain$i", { 'normalize'=>1, 'protocol'=>"$proto", 's_port'=>'1024:65535', 'd_port'=>"$pt", 'ctstate'=>'NEW,RELATED,ESTABLISHED'});
					if ($rv) {
						&printgreen("monitorix INPUT rule $i found.\n");
						push(@existing_rules, $prule);
					} else {
						&printred("monitorix INPUT rule $i NOT found.\n");
					}
					($rv, $num_rules) = $ipt_obj->find_ip_rule('0.0.0.0/0', '0.0.0.0/0', 'filter', 'OUTPUT', "$chain$i", { 'normalize'=>1, 'protocol'=>"$proto", 'd_port'=>'1024:65535', 's_port'=>"$pt", 'ctstate'=>'RELATED,ESTABLISHED'});
					if ($rv) {
						&printgreen("monitorix OUTPUT rule $i found.\n");
						push(@existing_rules, $oprule);
					} else {
						&printred("monitorix OUTPUT rule $i NOT found.\n");
					}
				} else {
					print "$chain$i not found.  Creating it.\n";
					$ipt_obj->create_chain('filter', "$chain$i");
					push(@created_chains, "$chain$i");
				}
			}
		}
		default {
			print "Error: $chain\n";
		}
	}
}

&printgreen("Existing chains:\n");
foreach my $c ( @existing_chains ) { print "$c\n"; }
&printcyan("Created chains:\n");
foreach my $c ( @created_chains ) { print "$c\n"; }
&printgreen("Existing rules:\n");
foreach my $r ( @existing_rules ) { print "$r\n"; }
&printcyan("Created rules:\n");
foreach my $r ( @created_rules ) { print "$r\n"; }

#######################################################################
sub printgreen($) {
	my $line = shift(@_);
	print color 'green';
	print "$line";
	print color 'reset';
}
sub printcyan($) {
	my $line = shift(@_);
	print color 'cyan';
	print "$line";
	print color 'reset';
}
sub printred($) {
	my $line = shift(@_);
	print color 'bold red';
	print "$line";
	print color 'reset';
}
sub printyellow($) {
	my $line = shift(@_);
	print color 'yellow';
	print "$line";
	print color 'reset';
}
