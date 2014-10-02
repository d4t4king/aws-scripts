#!/usr/bin/perl -w

use strict;
use warnings;
no if $] >= 5.018, warnings => "experimental::smartmatch";
use feature qw(switch);
use Data::Dumper;

my $sqlite = '/usr/bin/sqlite3';
my $db = '/www/db/useragents';
my ($ua);
my (%uas, %dbdata);

#open IN, "</var/log/nginx/access.log" or die "Couldn't access /var/log/nginx/access.log: $! \n";
open IN, "</tmp/access_log" or die "Couldn't access /var/log/nginx/access.log: $! \n";
while (my $line = <IN>) {
	chomp($line);
	if ($line =~ /((?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))\s*\-\s*.*?\s*\[(.*?)\]\s*\"(.*?)\"\s*(\d+)\s*\d+\s*\".*?\"\s*\"(.*?)\"/) {
		$ua = $5;
		# FIX ME!!!
		# Temporary fix for bash UA bug checking
		#$ua =~ s/&//g;
		#$ua =~ s#\/##g;
		#$ua = quotemeta($ua);
		if ($ua =~ /[&\\]/) { print STDERR "$ua\n"; next; }
		$uas{$ua}++;
	}
}
close IN;

my @data = `$sqlite $db "select uas,hitcount from useragents"`;
#print Dumper(@data);
foreach my $line ( @data ) {
	chomp($line);
	my ($dbua, $hc) = split(/\|/, $line);
	#print "$dbua\t$hc\n";
	if ((!defined($hc)) || ($hc eq "")) { $hc = 0; }
	$dbdata{$dbua} = $hc;
}

# update the user-agents we already know about
foreach my $dbua (keys %dbdata) {
	if (exists($uas{$dbua})) {
		my $cnt = $uas{$dbua} + $dbdata{$dbua};
		system("$sqlite $db \"update useragents set hitcount='$cnt' where uas='$dbua'\"");
		delete($uas{$dbua});
	}
}

# insert whatever is left
# try to identify what type it is.
foreach my $ua ( keys %uas ) {
	given ($ua) {
		when (/(?:bot|Mediapartners-Google)/) { system("$sqlite $db \"update useragents set type='bot' where uas='$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } }
		when (/(?:\(\)\s*\{\s*\:\;\s*\}|shellshock-scan)/) { system("$sqlite $db \"update useragents set type='shellshock' where uas='$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } }
		when (/Windows-Media-Player\\?\/?[0-9.]+/) { system("$sqlite $db \"update useragents set type='media-player' where uas='$ua'\"");	if ($? ne 0) { print STDERR "UA=$ua\n"; } }
		when (/^(?:[wW]get|[Hh][Tt][Tt]rack)|LWP\:\:Simple\/[0-9.]* libwww-perl\/[0-9.]*/) { 
			system("$sqlite $db \"update useragents set type='automaton' where uas='$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } 
		}
		when (/^(?:TrackBack.*?|java|curl|libwww-perl\/[0-9.])/) { system("$sqlite $db \"update useragents set type='automaton' where uas='$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } }
		when (/(?:wispr|paros|brutus|\\?.nasl|jBrowser-WAP)/) { system("$sqlite $db \"update useragents set type='unknown' where uas='$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } }
		when (/^Nokia7650.*?/) { system("$sqlite $db \"update useragents set type='mobile' where uas='$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } }
		when (/(?:webinspect|w3af\.sourceforge\.net|Mozilla\/?[0-9.]* \(Nikto\/?[0-9.]*\))/) { 
			system("$sqlite $db \"update useragents set type='scanner' where uas='$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } 
		}
		when (/^$/) { system("$sqlite $db \"update useragents set type='unknown' where uas='$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } }
		when (/^Mozilla.*?Windows.*?Gecko.*?\sFirefox.*?/) { system("$sqlite $db \"update useragents set type='browser likely' where uas like '$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } }
		when (/^Mozilla.*?(?:iPad|iPhone).*?AppleWebKit.*?Gecko.*?\sMobile.*?\sSafari.*?/) { 
			system("$sqlite $db \"update useragents set type='mobile' where uas like '$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } 
		}
		when (/^Mozilla\/?[0-9.]* \(PLAYSTATION \d+\; [0-9.]+\)/) { system("$sqlite $db \"update useragents set type='mobile' where uas like '$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } }
		when (/^Mozilla.*?MSIE.*?Windows NT.*?/) { system("$sqlite $db \"update useragents set type='browser likely' where uas like '$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } }
		when (/^Lynx \(textmode\)/) { system("$sqlite $db \"update useragents set type='browser likely' where uas like '$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } }
		when (/^Mozilla.*?Linux.*?\s+Android.*?AppleWebKit.*?Mobile Safari.*?/) { 
			system("$sqlite $db \"update useragents set type='mobile' where uas like '$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } 
		}
		when (/^Mozilla.*?X11.*?Gecko.*? Firefox/) { system("$sqlite $db \"update useragents set type='browser likely' where uas like '$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } }
		when (/^\-$/) { system("$sqlite $db \"update useragents set type='unknown' where uas='$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } }
		when (/^Mozilla.*? Ask Jeeves.*/) { system("$sqlite $db \"update useragents set type='bot' where uas='$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } }
		when (/^Mozilla.*?Windows.*?AppleWebKit.*?Chrome.*?Safari.*?/) { 
			system("$sqlite $db \"update useragents set type='browser likely' where uas like '$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } 
		}
		when (/Opera\/?[0-9.]+ \(Windows NT [0-9.]+.*?\) Presto\/?[0-9.]+/) {
			system("$sqlite $db \"update useragents set type='browser likely' where uas like '$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } 
		}
		when (/^Mozilla\/?[0-9.]+( \(compatible;.*\))?$/) {
			system("$sqlite $db \"update useragents set type='unknown' where uas like '$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; }
		} 
		when (/http:\/\/validator.w3.org\/services/) {
			system("$sqlite $db \"update useragents set type='scanner' where uas='$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } 
		}
		when (/HTTP_Request2\/[0-9.]+ \(http:\/\/pear.php.net\/package\/http_request2\) PHP\/[0-9.]+/) {
			system("$sqlite $db \"update useragents set type='automaton' where uas='$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } 
		}
		when (/^Mozilla.*?Macintosh.*?Chrome.*?Safari/) {
			system("$sqlite $db \"update useragents set type='browser likely' where uas like '$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } 
		}
		default { system("$sqlite $db \"insert into useragents values('$ua','','$uas{$ua}')\""); }
	}
}

# finally, try to categorize anything that's already in the database with type="".
my @exist = `$sqlite $db "select * from useragents where type=''"`;
foreach my $str ( sort @exist ) {
	chomp($str);
	my ($ua, $type, $hc) = split(/\|/, $str);
	given ($ua) {
		when (/(?:[Bb]ot|Mediapartners-Google|apach0day)/) { system("$sqlite $db \"update useragents set type='bot' where uas='$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } }
		when (/(?:\(\)\s*\{\s*\:\;\s*\}|shellshock-scan)/) { system("$sqlite $db \"update useragents set type='shellshock' where uas='$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } }
		when (/Windows-Media-Player\\?\/?[0-9.]+/) { system("$sqlite $db \"update useragents set type='media-player' where uas='$ua'\"");	if ($? ne 0) { print STDERR "UA=$ua\n"; } }
		when (/^(?:[wW]get|[Hh][Tt][Tt]rack)|LWP\:\:Simple\/[0-9.]* libwww-perl\/[0-9.]*/) { 
			system("$sqlite $db \"update useragents set type='automaton' where uas='$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } 
		}
		when (/^(?:TrackBack.*?|java|curl|libwww-perl\/[0-9.])/) { system("$sqlite $db \"update useragents set type='automaton' where uas='$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } }
		when (/(?:wispr|paros|brutus|\\?.nasl|jBrowser-WAP)/) { system("$sqlite $db \"update useragents set type='unknown' where uas='$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } }
		when (/^Nokia7650.*?/) { system("$sqlite $db \"update useragents set type='mobile' where uas='$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } }
		when (/(?:webinspect|w3af\.sourceforge\.net|Mozilla\/?[0-9.]* \(Nikto\/?[0-9.]*\))/) { 
			system("$sqlite $db \"update useragents set type='scanner' where uas='$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } 
		}
		when (/^$/) { system("$sqlite $db \"update useragents set type='unknown' where uas='$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } }
		when (/^Mozilla.*?Windows.*?Gecko.*?\sFirefox.*?/) { system("$sqlite $db \"update useragents set type='browser likely' where uas like '$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } }
		when (/^Mozilla.*?(?:iPad|iPhone).*?AppleWebKit.*?Gecko.*?\sMobile.*?(?:\sSafari.*?)?/) { 
			system("$sqlite $db \"update useragents set type='mobile' where uas like '$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } 
		}
		when (/^Mozilla\/?[0-9.]* \(PLAYSTATION \d+\; [0-9.]+\)/) { system("$sqlite $db \"update useragents set type='mobile' where uas like '$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } }
		when (/^Mozilla.*?MSIE.*?Windows NT.*?/) { system("$sqlite $db \"update useragents set type='browser likely' where uas like '$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } }
		when (/^Lynx \(textmode\)/) { system("$sqlite $db \"update useragents set type='browser likely' where uas like '$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } }
		when (/^Mozilla.*?Linux.*?\s+Android.*?AppleWebKit.*?Mobile Safari.*?/) { 
			system("$sqlite $db \"update useragents set type='mobile' where uas like '$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } 
		}
		when (/^Mozilla.*?X11.*?Gecko.*? Firefox/) { system("$sqlite $db \"update useragents set type='browser likely' where uas like '$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } }
		when (/^\-$/) { system("$sqlite $db \"update useragents set type='unknown' where uas='$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } }
		when (/^Mozilla.*? Ask Jeeves.*/) { system("$sqlite $db \"update useragents set type='bot' where uas='$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } }
		when (/^Mozilla.*?Windows.*?AppleWebKit.*?Chrome.*?Safari.*?/) { 
			system("$sqlite $db \"update useragents set type='browser likely' where uas like '$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } 
		}
		when (/Opera\/?[0-9.]+ \(Windows NT [0-9.]+.*?\) Presto\/?[0-9.]+/) {
			system("$sqlite $db \"update useragents set type='browser likely' where uas like '$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } 
		}
		when (/^Mozilla\/?[0-9.]+( \(compatible;.*\))?$/) {
			system("$sqlite $db \"update useragents set type='unknown' where uas like '$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; }
		} 
		when (/(?:http:\/\/validator.w3.org\/services|W3C_I18n-Checker\/[0-9.]+|Validator.nu\/LV)/) {
			system("$sqlite $db \"update useragents set type='scanner' where uas='$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } 
		}
		when (/HTTP_Request2\/[0-9.]+ \(http:\/\/pear.php.net\/package\/http_request2\) PHP\/[0-9.]+/) {
			system("$sqlite $db \"update useragents set type='automaton' where uas='$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } 
		}
		when (/^Mozilla.*?Macintosh.*?Chrome.*?Safari/) {
			system("$sqlite $db \"update useragents set type='browser likely' where uas like '$ua'\""); if ($? ne 0) { print STDERR "UA=$ua\n"; } 
		}
		# We don't want the default here, because the type is already blank
		#default { system("$sqlite $db \"insert into useragents values('$ua','','$uas{$ua}')\""); }
	}
}
	
