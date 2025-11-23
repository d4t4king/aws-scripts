#!/usr/bin/perl -w

use strict;
use warnings;
no if $] >= 5.018, warnings => "experimental::smartmatch";
use feature qw( switch );

use Term::ANSIColor qw( colored );
use Parse::Syslog;
use Data::Dumper;
use IPTables::ChainMgr;
use Net::IPv4Addr qw( :all );

my %opts = (
	iptables    =>  '/sbin/iptables',
	iptout      =>  '/tmp/iptables.out',
	ipterr      =>  '/tmp/iptables.err',
	verbose     =>  0,
	debug       =>  0,
	### advanced options
	'ipt_alarm' => 5,					### max seconds to wait for iptables execution.
	'ipt_exec_style' => 'waitpid',		### can be 'waitpid',
										### 'system', or 'popen'.
	'ipt_exec_sleep' => 1,				### add in time delay between execution of
										### iptables commands (default is 0).
);

my (%to_mails, %relays, %sorter, %smtp_relay_attempts );
my $parser = Parse::Syslog->new( '/var/log/syslog' );
while (my $sl = $parser->next) {
	#print "TS: $sl->{'timestamp'}, PROG: $sl->{'program'}, MSG: $sl->{'text'}\n";
	given ($sl->{'program'}) {
		when (/postfix\/(?:cleanup|local|qmgr|scache|pickup|master|postalias|bounce|anvil)/) { }
		when (/postfix\/smtp/) {
			if ($sl->{'text'} =~ /(?:Connection timed out|Network is unreachable)/) {
				#do nothing;
			} else {
				given  ($sl->{'text'}) {
					when (/to=<(.*)>, orig_to=<?(.*?)>?, relay=(.*?),\s*/) { 	$to_mails{$1}{$2}++; $relays{$3}++; 		}
					when (/to=<(.*)>, relay=(.*?),\s*/) { 						$to_mails{$1}{'none'}++; $relays{$2}++; 	}
					when (/NOQUEUE: reject: RCPT from .*\[(.*?)\]/) { 			my $ip = $1; $smtp_relay_attempts{$ip}++; 	}
					when (/(?:dis)?connect from /) { 																		} 	# do nothing 
					when (/warning: hostname/) { 																			}	# do nothing
					when (/warning: host aws1.dataking.us\[/) { 															}	# do nothing
					when (/lost connection after (?:MAIL|CONNECT) from/) { 													} 	# do nothing 
					default { print colored("$sl->{'program'}: $sl->{'text'}\n", "yellow"); }
				}
			}
		}
		when (/kernel/) { 
			if ($sl->{'text'} =~ /iptables-denied:/) {
				open FILE, ">/var/log/parsed-iptables" or die "Couldn't open iptables file for writing: $! \n";
				print FILE localtime($sl->{'timestamp'})." $sl->{'host'} $sl->{'program'} $sl->{'text'}\n";
				close FILE;
			}
		}
		when (/ntpdate/) { 																								}
		when (/ntpd/) { 																								}
		when (/CRON/) { 																								}
		when (/acpid/) { 																								}
		when (/rsyslogd/) { 																							}
		when (/psad/) { 																								}
		when (/pads/) { 																								}
		when (/\/usr\/sbin\/irqbalance/) { 																				}
		when (/pollinate/) { 																							}
		when (/NetworkManager/) {																						}
		when (/cron(?:tab)?/) {
			if ($sl->{'text'} =~ /(?:LIST|STARTUP|INFO)/) { }
			else { print localtime($sl->{'timestamp'})." $sl->{'host'} $sl->{'program'} $sl->{'pid'} $sl->{'text'}\n"; }
		}
		when (/dhclient/) {
			if ($sl->{'text'} =~ /bound to (\d+\.\d+\.\d+\.\d+) -- /) {
				my $newip = $1;
				my $lastip = "";
				if ( -f 'lastip' && ! -z 'lastip' ) {
					open IN, "<lastip"; $lastip = <IN>; chomp($lastip); close IN;
				} else {
					open OUT, ">lastip"; print OUT "$newip\n"; close OUT;
				}
				if ($newip ne $lastip) {
					system("echo 'IP Changed.\nNew: $newip, Old: $lastip' | mail -s \"DHCP Address Changed: aws2.dataking.us\" charlie\@dataking.us");
				}
			}
		}
		default {
			print colored("$sl->{'program'}: $sl->{'text'}\n", "magenta");
		}
	}
}

printf "%s\n", colored("To Emails:", "bold cyan");
foreach my $k ( sort keys %to_mails ) {
	foreach my $o ( sort keys %{$to_mails{$k}} ) {
		printf "%s <== %s\t( %s )\n", colored("$k", "yellow"), colored("$o", "green"), $to_mails{$k}{$o};
	}
}

printf "%s\n", colored("Relays used:", "bold cyan");
foreach my $k ( sort { $relays{$b} <=> $relays{$a} } keys %relays ) {
	printf "%s\t( %s |\n", colored("$k", "yellow"), colored("$relays{$k}", "green");
}


my $ipt_obj = new IPTables::ChainMgr(%opts);
printf "%s\n", colored("Failed relay attempt from IPs:", "bold cyan");
foreach my $k ( sort { $smtp_relay_attempts{$b} <=> $smtp_relay_attempts{$a} } keys %smtp_relay_attempts ) {
	#print &printred($k)."\t( ".&printyellow($smtp_relay_attempts{$k})." ) \n";
	printf("%15s\t( %s )\n", colored("$k", "red"), colored("$smtp_relay_attempts{$k}", "yellow"));
	if ($smtp_relay_attempts{$k} > 5) {
		print "Checking for rule...\n";
		my ($rule_num, $rule_count) = $ipt_obj->find_ip_rule("$k", "0.0.0.0/0", "filter", "INPUT", "LOGNDROP", {});
		if ($rule_num != 0) {
			print colored("Found $rule_num of $rule_count\n", "bold blue");
		} else {
			print colored("Rule not found with source $k.\n", "yellow");
			if ($k eq "66.27.87.243"	||
				$k eq "54.201.84.16"	||
				$k eq "54.68.91.48"		||
				$k eq "50.112.189.69"	||
				$k eq "54.68.176.135"	||
				$k eq "54.191.148.250"	||
				$k eq "54.69.1.206"		||
				ipv4_in_network("161.209.0.0", $k)) {
					print colored("Belligerently refusing to block $k!\n", "yellow");
					next;
			}
			print "Creating rule to block $k\n";
			my ($rv, $out_ar, $errs_ar) = $ipt_obj->add_ip_rule("$k/32", "0.0.0.0/0", 1, "filter", "INPUT", "LOGNDROP", {});
			print colored("$rv, ".join("|", @{$out_ar}).", ".join("|", @{$errs_ar}), "green")."\n";
		}
	}
}


#######################################################################
