#!/usr/bin/perl

use strict;
use warnings;

use POSIX qw( strftime );
use IO::Interface::Simple;
use Data::Dumper;
use Getopt::Long;
my ($do, $show);
GetOptions(
	'--do'		=>	\$do,
	'--show'	=>	\$show,
);

my $iptables = qx/which iptables/;
chomp($iptables);
my $iptables_save = qx/which iptables-save/;
chomp($iptables_save);

my @commands;

# get local subnet
sub get_localnet {
	my $localnet = '';
	my @ifaces = IO::Interface::Simple->interfaces;
	foreach my $iface ( @ifaces ) {
		# localhost is not localnet
		next if ((defined($iface->address)) and ($iface->address =~ /127\.0\.0/));
		# skip interface without an assigned IP
		next if (!defined($iface->address));
		print "Interface: ".$iface->name."\n";
		print "Addr: ".$iface->address."\n";
		print "Netmask: ".$iface->netmask."\n";
		my @octs = split(/\./, $iface->address);
		my $net = "$octs[0].$octs[1].$octs[2].0";
		$localnet = $net . "/" . $iface->netmask;
	}
	return $localnet;
}

sub get_listening {
	my @list;
	my $out = qx/netstat -anp4 2>&1 | grep LISTEN/;
	chomp($out);
	my @lines = split(/\n/, $out);
	#print Dumper(\@lines);
	foreach my $l ( @lines ) {
		if ($l =~ /^(tcp|udp)\s+\d+\s+\d+\s+([0-9.]+)\:(\d+)\s+/) {
			my $proto = $1; my $ip = $2; my $port = $3;
			# 1) Anything listening on localhost isn't really listening on the network,
			#	therefore, it doesn't need a port opened.
			# 2) Anything listening on localhost should get ACCEPT'ed by the lo rule.
			next if ($ip eq '127.0.0.1');
			push @list, "$proto:$port";
		} else {
			warn "netstat line didn't match regex!";
		}
	}
	return @list;
}

print "TimeStamp: ".strftime("%Y%m%d%H%M%S", localtime())."\n";
my $stamp = strftime("%Y%m%d%H%M%S", localtime());


my @listening = &get_listening();
print Dumper(\@listening);

if ($show) {
	# backup any existing iptables rules
	push @commands, "$iptables_save > basicfw_backup_$stamp";
	# Flush and zeroize the foundation tables/chains
	push @commands, "-Z";
	push @commands, "-F";
	# create the new tables/chains we'll need
	push @commands, "-N TCP";
	push @commands, "-N UDP";
	push @commands, "-N LOGGING";
	# set the default policy for FORWARD
	push @commands, "-P FORWARD DROP";
	# allow traffic from local interface
	push @commands, "-A INPUT -i lo -j ACCEPT";
	# add the established/related rule
	push @commands, "-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT";
	# drop invalid traffic
	push @commands, "-A INPUT -m conntrack --ctstate INVALID -j DROP";
	#print Dumper(\@ifaces);
	my $localnet = &get_localnet();
	# allow ICMP pings from local subnet
	if ((defined($localnet)) and ($localnet ne '')) {
		push @commands, "-A INPUT -s $localnet -p icmp --icmp-type 8 -m conntrack --ctstate NEW -j ACCEPT";
	} else {
		push @commands, "-A INPUT -p icmp --icmp-type 8 -m conntrack --ctstate NEW -j ACCEPT";
	}
	# send NEW UDP traffic to the UDP chain
	push @commands, "-A INPUT -p udp -m conntrack --ctstate NEW -j UDP";
	foreach my $l ( @listening ) {
		next unless ($l =~ /^udp/);
		my ($proto,$port) = split(/\:/, $l);
		push @commands, "-A UDP -p $proto --dport $port -m conntrack --ctstate NEW -j ACCEPT";
	}
	# return to INPUT
	push @commands, "-A UDP -j RETURN";
	# send NEW TCP traffic to the TCP chain
	push @commands, "-A INPUT -p tcp --syn -m conntrack --ctstate NEW -j TCP";
	foreach my $l ( @listening ) {
		next unless ($l =~ /^tcp/);
		my ($proto,$port) = split(/\:/, $l);
		push @commands, "-A TCP -p $proto --dport $port -m conntrack --ctstate NEW -j ACCEPT";
	}
	# return to INPUT
	push @commands, "-A TCP -j RETURN";
	# send all remaining traffic to the LOGGING chain
	push @commands, "-A INPUT -j LOGGING";
	# log them
	#system("$iptables -A LOGGING -m limit --limit 10/min -j LOG --log-prefix \"IPTables-Dropped: \" --log-level 4");
	push @commands, "-A LOGGING -m limit --limit 10/min -j LOG --log-prefix \"IPTables-Dropped: \" --log-level info";
	# drop it like it's hot...
	push @commands, "-A LOGGING -j DROP";
	
	print Dumper(\@commands);
}

if ($do) {
	#iptables-save > basic-fw-backup_YYYYMMDDHHmmss
	system("$iptables_save > basic-fw-backup_$stamp");
	system("$iptables -Z");
	system("$iptables -F");
	system("$iptables -N TCP");
	system("$iptables -N UDP");
	system("$iptables -N LOGGING");
	system("$iptables -P FORWARD DROP");
	system("$iptables -A INPUT -i lo -j ACCEPT");
	system("$iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT");
	system("$iptables -A INPUT -m conntrack --ctstate INVALID -j DROP");
	my $localnet = &get_localnet();
	if ((defined($localnet)) and ($localnet ne '')) {
		system("$iptables -A INPUT -s $localnet -p icmp --icmp-type 8 -m conntrack --ctstate NEW -j ACCEPT");
	} else {
		system("$iptables -A INPUT -p icmp --icmp-type 8 -m conntrack --ctstate NEW -j ACCEPT");
	}
	system("$iptables -A INPUT -p udp -m conntrack --ctstate NEW -j UDP");
	foreach my $l ( @listening ) {
		next unless ($l =~ /^udp/);
		my ($proto,$port) = split(/\:/, $l);
		system("$iptables -A UDP -p $proto --dport $port -m conntrack --ctstate NEW -j ACCEPT");
	}
	system("$iptables -A UDP -j RETURN");
	system("$iptables -A INPUT -p tcp --syn -m conntrack --ctstate NEW -j TCP");
	foreach my $l ( @listening ) {
		next unless ($l =~ /^tcp/);
		my ($proto,$port) = split(/\:/, $l);
		system("$iptables -A TCP -p $proto --dport $port -m conntrack --ctstate NEW -j ACCEPT");
	}
	system("$iptables -A TCP -j RETURN");
	system("$iptables -A INPUT -j LOGGING");
	system("$iptables -A LOGGING -m limit --limit 10/min -j LOG --log-prefix \"IPTables-Dropped: \" --log-level info");
	system("$iptables -A LOGGING -j DROP");
}
