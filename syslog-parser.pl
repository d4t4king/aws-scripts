#!/usr/bin/perl -w

use strict;
use warnings;
no if $] >= 5.018, warnings => "experimental::smartmatch";
use feature qw( switch );
use Parse::Syslog;
use Data::Dumper;

my (%to_mails, %relays, %sorter );
my $parser = Parse::Syslog->new( '/var/log/syslog' );
while (my $sl = $parser->next) {
	#print "TS: $sl->{'timestamp'}, PROG: $sl->{'program'}, MSG: $sl->{'text'}\n";
	given ($sl->{'program'}) {
		when (/postfix\/(?:cleanup|local|qmgr|scache|pickup|master|postalias|bounce)/) { }
		when (/postfix\/smtp/) {
			if ($sl->{'text'} =~ /(?:Connection timed out|Network is unreachable)/) {
				#do nothing;
			} else {
				if ($sl->{'text'} =~ /to=<(.*)>, orig_to=<?(.*?)>?, relay=(.*?),\s*/) {
					$to_mails{$1}{$2}++; $relays{$3}++;
				} elsif ($sl->{'text'} =~ /to=<(.*)>, relay=(.*?),\s*/) {
					$to_mails{$1}{'none'}++; $relays{$2}++;
				} else {
					print "$sl->{'program'}: $sl->{'text'}\n";
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
		when (/ntpdate/) { }
		when (/CRON/) { }
		when (/acpid/) { }
		when (/rsyslogd/) { }
		when (/psad/) { }
		when (/pads/) { }
		when (/\/usr\/sbin\/irqbalance/) { }
		when (/pollinate/) { }
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
			print "$sl->{'program'}: $sl->{'text'}\n";
		}
	}
}

foreach my $k ( sort keys %to_mails ) {
	foreach my $o ( sort keys %{$to_mails{$k}} ) {
		print "$k <== $o ($to_mails{$k}{$o})\n";
	}
}

foreach my $k ( sort { $relays{$b} <=> $relays{$a} } keys %relays ) {
	print "$k\t( $relays{$k} ) \n";
}
