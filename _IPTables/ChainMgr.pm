#
##############################################################################
#
# File: IPTables::ChainMgr.pm
#
# Purpose: Perl interface to add and delete rules to an iptables chain.  The
#          most common application of this module is to create a custom chain
#          and then add blocking rules to it.  Rule additions are (mostly)
#          guaranteed to be unique.
#
# Author: Michael Rash (mbr@cipherdyne.org)
#
# Version: 1.2
#
##############################################################################
#

package IPTables::ChainMgr;

use 5.006;
use POSIX ':sys_wait_h';
use Carp;
use IPTables::Parse;
use NetAddr::IP;
use strict;
use warnings;
use vars qw($VERSION);

$VERSION = '1.2';

sub new() {
    my $class = shift;
    my %args  = @_;

    my $self = {
        _iptables  => $args{'iptables'}  || $args{'ip6tables'} || '/sbin/iptables',
        _iptout    => $args{'iptout'}    || '/tmp/ipt.out',
        _ipterr    => $args{'ipterr'}    || '/tmp/ipt.err',
        _ipt_alarm => $args{'ipt_alarm'} || 30,
        _debug     => $args{'debug'}     || 0,
        _verbose   => $args{'verbose'}   || 0,
        _ipt_exec_style => $args{'ipt_exec_style'} || 'waitpid',
        _ipt_exec_sleep => $args{'ipt_exec_sleep'} || 0,
        _sigchld_handler => $args{'sigchld_handler'} || \&REAPER,
    };
    $self->{'_ipt_bin_name'} = 'iptables';
    $self->{'_ipt_bin_name'} = $1 if $self->{'_iptables'} =~ m|.*/(\S+)|;

    croak "[*] $self->{'_iptables'} incorrect $self->{'_ipt_bin_name'} path.\n"
        unless -e $self->{'_iptables'};
    croak "[*] $self->{'_iptables'} not executable.\n"
        unless -x $self->{'_iptables'};

    bless $self, $class;
}

sub chain_exists() {
    my $self = shift;
    my $table = shift || croak '[*] Must specify a table, e.g. "filter".';
    my $chain = shift || croak '[*] Must specify a chain to check.';
    my $iptables = $self->{'_iptables'};

    ### see if the chain exists
    return $self->run_ipt_cmd("$iptables -t $table -v -n -L $chain");
}

sub create_chain() {
    my $self = shift;
    my $table = shift || croak '[*] Must specify a table, e.g. "filter".';
    my $chain = shift || croak '[*] Must specify a chain to create.';
    my $iptables = $self->{'_iptables'};

    ### see if the chain exists first
    my ($rv, $out_aref, $err_aref) = $self->chain_exists($table, $chain);

    ### the chain already exists
    return 1, $out_aref, $err_aref if $rv;

    ### create the chain
    return $self->run_ipt_cmd("$iptables -t $table -N $chain");
}

sub flush_chain() {
    my $self = shift;
    my $table = shift || croak '[*] Must specify a table, e.g. "filter".';
    my $chain = shift || croak '[*] Must specify a chain.';
    my $iptables = $self->{'_iptables'};

    ### flush the chain
    return $self->run_ipt_cmd("$iptables -t $table -F $chain");
}

sub delete_chain() {
    my $self = shift;
    my $table = shift || croak '[*] Must specify a table, e.g. "filter".';
    my $jump_from_chain = shift ||
        croak '[*] Must specify a chain from which ',
            'packets were jumped to this chain';
    my $del_chain = shift || croak '[*] Must specify a chain to delete.';
    my $iptables = $self->{'_iptables'};

    ### see if the chain exists first
    my ($rv, $out_aref, $err_aref) = $self->chain_exists($table, $del_chain);

    ### return true if the chain doesn't exist (it is not an error condition)
    return 1, $out_aref, $err_aref unless $rv;

    ### flush the chain
    ($rv, $out_aref, $err_aref)
        = $self->flush_chain($table, $del_chain, $iptables);

    ### could not flush the chain
    return 0, $out_aref, $err_aref unless $rv;

    my $ip_any_net = '0.0.0.0/0';
    $ip_any_net = '::/0' if $self->{'_ipt_bin_name'} eq 'ip6tables';

    ### find and delete jump rules to this chain (we can't delete
    ### the chain until there are no references to it)
    my ($rulenum, $num_chain_rules)
        = $self->find_ip_rule($ip_any_net, $ip_any_net,
            $table, $jump_from_chain, $del_chain, {});

    if ($rulenum) {
        $self->run_ipt_cmd(
            "$iptables -t $table -D $jump_from_chain $rulenum");
    }

    ### note that we try to delete the chain now regardless
    ### of whether their were jump rules above (should probably
    ### parse for the "0 references" under the -nL <chain> output).
    return $self->run_ipt_cmd("$iptables -t $table -X $del_chain");
}

sub set_chain_policy() {
    my $self = shift;
    my $table = shift || croak '[*] Must specify a table, e.g. "filter".';
    my $chain = shift || croak '[*] Must specify a chain.';
    my $target  = shift || croak qq|[-] Must specify an | .
        qq|$self->{'_ipt_bin_name'} target, e.g. "DROP"|;
    my $iptables = $self->{'_iptables'};

    ### set the chain policy: note that $chain must be a built-in chain
    return $self->run_ipt_cmd("$iptables -t $table -P $chain $target");
}

sub append_ip_rule() {
    my $self = shift;
    my $src = shift || croak '[-] Must specify a src address/network.';
    my $dst = shift || croak '[-] Must specify a dst address/network.';
    my $table   = shift || croak '[-] Must specify a table, e.g. "filter".';
    my $chain   = shift || croak '[-] Must specify a chain.';
    my $target  = shift || croak qq|[-] Must specify an | .
        qq|$self->{'_ipt_bin_name'} target, e.g. "DROP"|;

    ### optionally add port numbers and protocols, etc.
    my $extended_href = shift || {};
    my $iptables = $self->{'_iptables'};

    ### normalize src/dst if necessary; this is because iptables
    ### always reports the network address for subnets
    my $normalized_src = $self->normalize_net($src);
    my $normalized_dst = $self->normalize_net($dst);

    ### first check to see if this rule already exists
    my ($rule_position, $num_chain_rules)
            = $self->find_ip_rule($normalized_src, $normalized_dst, $table,
                $chain, $target, $extended_href);

    if ($rule_position) {
        my $msg = '';
        if (keys %$extended_href) {
            $msg = "Table: $table, chain: $chain, $normalized_src -> " .
                "$normalized_dst ";
            for my $key (qw(protocol s_port d_port mac_source)) {
                $msg .= "$key $extended_href->{$key} "
                    if defined $extended_href->{$key};
            }
            $msg .= 'rule already exists.';
        } else {
            $msg = "Table: $table, chain: $chain, $normalized_src -> " .
                "$normalized_dst rule already exists.";
        }
        return 1, [$msg], [];
    }

    ### we need to add the rule
    my $ipt_cmd = '';
    my $msg     = '';
    my $idx_err = '';

    if (keys %$extended_href) {
        $ipt_cmd = "$iptables -t $table -A $chain ";
        $ipt_cmd .= "-p $extended_href->{'protocol'} "
            if defined $extended_href->{'protocol'};
        $ipt_cmd .= "-s $normalized_src ";
        $ipt_cmd .= "--sport $extended_href->{'s_port'} "
            if defined $extended_href->{'s_port'};
        $ipt_cmd .= "-d $normalized_dst ";
        $ipt_cmd .= "--dport $extended_href->{'d_port'} "
            if defined $extended_href->{'d_port'};
        $ipt_cmd .= "-m mac --mac-source $extended_href->{'mac_source'} "
            if defined $extended_href->{'mac_source'};
        $ipt_cmd .= "-j $target";

        $msg = "Table: $table, chain: $chain, added $normalized_src " .
            "-> $normalized_dst ";
        for my $key (qw(protocol s_port d_port mac_source)) {
            $msg .= "$key $extended_href->{$key} "
                if defined $extended_href->{$key};
        }

        ### for NAT
        if (defined $extended_href->{'to_ip'} and
                defined $extended_href->{'to_port'}) {
            $ipt_cmd .= " --to $extended_href->{'to_ip'}:" .
                "$extended_href->{'to_port'}";
            $msg .= "$extended_href->{'to_ip'}:$extended_href->{'to_port'}";
        }

        $msg =~ s/\s*$//;
    } else {
        $ipt_cmd = "$iptables -t $table -A $chain " .
            "-s $normalized_src -d $normalized_dst -j $target";
        $msg = "Table: $table, chain: $chain, added $normalized_src " .
            "-> $normalized_dst";
    }
    my ($rv, $out_aref, $err_aref) = $self->run_ipt_cmd($ipt_cmd);
    if ($rv) {
        push @$out_aref, $msg if $msg;
    }
    push @$err_aref, $idx_err if $idx_err;
    return $rv, $out_aref, $err_aref;
}

sub add_ip_rule() {
    my $self = shift;
    my $src = shift || croak '[-] Must specify a src address/network.';
    my $dst = shift || croak '[-] Must specify a dst address/network.';
    my $rulenum = shift || croak '[-] Must specify an insert rule number.';
    my $table   = shift || croak '[-] Must specify a table, e.g. "filter".';
    my $chain   = shift || croak '[-] Must specify a chain.';
    my $target  = shift ||
        croak qq|[-] Must specify an $self->{'_ipt_bin_name'} | .
            qq|target, e.g. "DROP"|;
    ### optionally add port numbers and protocols, etc.
    my $extended_href = shift || {};
    my $iptables = $self->{'_iptables'};

    ### normalize src/dst if necessary; this is because iptables
    ### always reports the network address for subnets
    my $normalized_src = $self->normalize_net($src);
    my $normalized_dst = $self->normalize_net($dst);

    ### first check to see if this rule already exists
    my ($rule_position, $num_chain_rules)
            = $self->find_ip_rule($normalized_src, $normalized_dst, $table,
                $chain, $target, $extended_href);

    if ($rule_position) {
        my $msg = '';
        if (keys %$extended_href) {
            $msg = "Table: $table, chain: $chain, $normalized_src -> " .
                "$normalized_dst ";
            for my $key (qw(protocol s_port d_port mac_source)) {
                $msg .= "$key $extended_href->{$key} "
                    if defined $extended_href->{$key};
            }
            $msg .= 'rule already exists.';
        } else {
            $msg = "Table: $table, chain: $chain, $normalized_src -> " .
                "$normalized_dst rule already exists.";
        }
        return 1, [$msg], [];
    }

    ### we need to add the rule
    my $ipt_cmd = '';
    my $msg     = '';
    my $idx_err = '';

    ### check to see if the insertion index ($rulenum) is too big
    $rulenum = 1 if $rulenum <= 0;
    if ($rulenum > $num_chain_rules+1) {
        $idx_err = "Rule position $rulenum is past end of $chain " .
            "chain ($num_chain_rules rules), compensating."
            if $num_chain_rules > 0;
        $rulenum = $num_chain_rules + 1;
    }
    $rulenum = 1 if $rulenum == 0;

    if (keys %$extended_href) {
        $ipt_cmd = "$iptables -t $table -I $chain $rulenum ";
        $ipt_cmd .= "-p $extended_href->{'protocol'} "
            if defined $extended_href->{'protocol'};
        $ipt_cmd .= "-s $normalized_src ";
        $ipt_cmd .= "--sport $extended_href->{'s_port'} "
            if defined $extended_href->{'s_port'};
        $ipt_cmd .= "-d $normalized_dst ";
        $ipt_cmd .= "--dport $extended_href->{'d_port'} "
            if defined $extended_href->{'d_port'};
        $ipt_cmd .= "-m mac --mac-source $extended_href->{'mac_source'} "
            if defined $extended_href->{'mac_source'};
        $ipt_cmd .= "-m state --state $extended_href->{'state'} "
            if defined $extended_href->{'state'};
        $ipt_cmd .= "-m conntrack --ctstate $extended_href->{'ctstate'} "
            if defined $extended_href->{'ctstate'};
        $ipt_cmd .= "-j $target";

        $msg = "Table: $table, chain: $chain, added $normalized_src " .
            "-> $normalized_dst ";
        for my $key (qw(protocol s_port d_port mac_source)) {
            $msg .= "$key $extended_href->{$key} "
                if defined $extended_href->{$key};
        }

        ### for NAT
        if (defined $extended_href->{'to_ip'} and
                defined $extended_href->{'to_port'}) {
            $ipt_cmd .= " --to $extended_href->{'to_ip'}:" .
                "$extended_href->{'to_port'}";
            $msg .= "$extended_href->{'to_ip'}:$extended_href->{'to_port'}";
        }

        $msg =~ s/\s*$//;
    } else {
        $ipt_cmd = "$iptables -t $table -I $chain $rulenum " .
            "-s $normalized_src -d $normalized_dst -j $target";
        $msg = "Table: $table, chain: $chain, added $normalized_src " .
            "-> $normalized_dst";
    }
    my ($rv, $out_aref, $err_aref) = $self->run_ipt_cmd($ipt_cmd);
    if ($rv) {
        push @$out_aref, $msg if $msg;
    }
    push @$err_aref, $idx_err if $idx_err;
    return $rv, $out_aref, $err_aref;
}

sub delete_ip_rule() {
    my $self = shift;
    my $src = shift || croak '[-] Must specify a src address/network.';
    my $dst = shift || croak '[-] Must specify a dst address/network.';
    my $table  = shift || croak '[-] Must specify a table, e.g. "filter".';
    my $chain  = shift || croak '[-] Must specify a chain.';
    my $target = shift || croak qq|[-] Must specify an | .
        qq|$self->{'_ipt_bin_name'} target, e.g. "DROP"|;
    ### optionally add port numbers and protocols, etc.
    my $extended_href = shift || {};
    my $iptables = $self->{'_iptables'};

    ### normalize src/dst if necessary; this is because iptables
    ### always reports network address for subnets
    my $normalized_src = $self->normalize_net($src);
    my $normalized_dst = $self->normalize_net($dst);

    ### first check to see if this rule already exists
    my ($rulenum, $num_chain_rules)
        = $self->find_ip_rule($normalized_src,
            $normalized_dst, $table, $chain, $target, $extended_href);

    if ($rulenum) {
        ### we need to delete the rule
        return $self->run_ipt_cmd("$iptables -t $table -D $chain $rulenum");
    }

    my $extended_msg = '';
    if (keys %$extended_href) {
        for my $key (qw(protocol s_port d_port mac_source)) {
            $extended_msg .= "$key: $extended_href->{$key} "
                if defined $extended_href->{$key};
        }
        ### for NAT
        if (defined $extended_href->{'to_ip'} and
                defined $extended_href->{'to_port'}) {
            $extended_msg .= "$extended_href->{'to_ip'}:" .
                "$extended_href->{'to_port'}";
        }
    }
    $extended_msg =~ s/\s*$//;
    return 0, [], ["Table: $table, chain: $chain, rule $normalized_src " .
        "-> $normalized_dst $extended_msg does not exist."];
}

sub find_ip_rule() {
    my $self = shift;
    my $debug   = $self->{'_debug'};
    my $verbose = $self->{'_verbose'};
    my $src   = shift || croak '[*] Must specify source address.';
    my $dst   = shift || croak '[*] Must specify destination address.';
    my $table = shift || croak qq|[*] Must specify $self->{'_ipt_bin_name'} table.|;
    my $chain = shift || croak qq|[*] Must specify $self->{'_ipt_bin_name'} chain.|;
    my $target = shift || croak qq|[*] Must specify | .
        qq|$self->{'_ipt_bin_name'} target (this may be a chain).|;

    ### optionally add port numbers and protocols, etc.
    my $extended_href = shift || {};
    my $iptables = $self->{'_iptables'};

    my $ipt_parse = new IPTables::Parse(
        'iptables'  => $self->{'_iptables'},
        'iptout'    => $self->{'_iptout'},
        'ipterr'    => $self->{'_ipterr'},
        'debug'     => $self->{'_debug'},
        'verbose'   => $self->{'_verbose'},
        'ipt_alarm' => $self->{'_ipt_alarm'},
        'ipt_exec_style' => $self->{'_ipt_exec_style'},
        'ipt_exec_sleep' => $self->{'_ipt_exec_sleep'},
        'sigchld_handler' => $self->{'_sigchld_handler'},
    ) or croak "[*] Could not acquire IPTables::Parse object";

    my $fh = *STDERR;
    $fh = *STDOUT if $verbose;

    if ($debug or $verbose) {
        print $fh localtime() . " [+] IPTables::Parse::VERSION ",
            "$IPTables::Parse::VERSION\n"
    }

    my $chain_aref = $ipt_parse->chain_rules($table, $chain);

    $src = $self->normalize_net($src) if defined $extended_href->{'normalize'}
        and $extended_href->{'normalize'};
    $dst = $self->normalize_net($dst) if defined $extended_href->{'normalize'}
        and $extended_href->{'normalize'};

    my $rulenum = 1;
    for my $rule_href (@$chain_aref) {
        if ($rule_href->{'target'} eq $target
                and $rule_href->{'src'} eq $src
                and $rule_href->{'dst'} eq $dst) {
            if (keys %$extended_href) {
                my $found = 1;
                for my $key (qw(
                    protocol
                    s_port
                    d_port
                    to_ip
                    to_port
                    state
                    ctstate
                )) {
                    if (defined $extended_href->{$key}) {
                        if (defined $rule_href->{$key}) {
                            if ($key eq 'state' or $key eq 'ctstate') {
                                ### make sure that state ordering as reported
                                ### by iptables is accounted for vs. what was
                                ### supplied to the module
                                unless (&state_compare($extended_href->{$key},
                                        $rule_href->{$key})) {
                                    $found = 0;
                                    last;
                                }
                            } else {
                                unless ($extended_href->{$key}
                                        eq $rule_href->{$key}) {
                                    $found = 0;
                                    last;
                                }
                            }
                        } else {
                            $found = 0;
                            last;
                        }
                    }
                }
                return $rulenum, $#$chain_aref+1 if $found;
            } else {
                if ($rule_href->{'protocol'} eq 'all') {
                    if ($target eq 'LOG' or $target eq 'ULOG') {
                        ### built-in LOG and ULOG target rules always
                        ### have extended information
                        return $rulenum, $#$chain_aref+1;
                    } elsif (not $rule_href->{'extended'}) {
                        ### don't want any additional criteria (such as
                        ### port numbers) in the rule. Note that we are
                        ### also not checking interfaces
                        return $rulenum, $#$chain_aref+1;
                    }
                }
            }
        }
        $rulenum++;
    }
    return 0, $#$chain_aref+1;
}

sub state_compare() {
    my ($state_str1, $state_str2) = @_;

    my @states1 = split /,/, $state_str1;
    my @states2 = split /,/, $state_str2;

    for my $state1 (@states1) {
        my $found = 0;
        for my $state2 (@states2) {
            if ($state1 eq $state2) {
                $found = 1;
                last;
            }
        }
        return 0 unless $found;
    }

    for my $state2 (@states2) {
        my $found = 0;
        for my $state1 (@states1) {
            if ($state2 eq $state1) {
                $found = 1;
                last;
            }
        }
        return 0 unless $found;
    }

    return 1;
}

sub normalize_net() {
    my $self = shift;
    my $net  = shift || croak '[*] Must specify net.';

    my $normalized_net = $net;  ### establish default

    ### regex to match an IPv4 address
    my $ipv4_re = qr/(?:\d{1,3}\.){3}\d{1,3}/;

    if ($net =~ m|/| and $net =~ $ipv4_re or $net =~ m|:|) {
        if ($net =~ m|:|) {  ### an IPv6 address
            my $n = new6 NetAddr::IP $net
                or croak "[*] Could not acquire NetAddr::IP object for $net";
            $normalized_net = lc($n->network()->short()) . '/' . $n->masklen();
        } else {
            my $n = new NetAddr::IP $net
                or croak "[*] Could not acquire NetAddr::IP object for $net";
            $normalized_net = $n->network()->cidr();
        }
    }
    return $normalized_net;
}

sub add_jump_rule() {
    my $self  = shift;
    my $table = shift || croak '[-] Must specify a table, e.g. "filter".';
    my $from_chain = shift || croak '[-] Must specify chain to jump from.';
    my $rulenum    = shift || croak '[-] Must specify jump rule chain position';
    my $to_chain   = shift || croak '[-] Must specify chain to jump to.';
    my $iptables = $self->{'_iptables'};
    my $idx_err = '';

    if ($from_chain eq $to_chain) {
        return 0, ["Identical from_chain and to_chain ($from_chain) " .
            "not allowed."], [];
    }

    my $ip_any_net = '0.0.0.0/0';
    $ip_any_net = '::/0' if $self->{'_ipt_bin_name'} eq 'ip6tables';

    ### first check to see if the jump rule already exists
    my ($rule_position, $num_chain_rules)
        = $self->find_ip_rule($ip_any_net, $ip_any_net, $table,
            $from_chain, $to_chain, {});

    ### check to see if the insertion index ($rulenum) is too big
    $rulenum = 1 if $rulenum <= 0;
    if ($rulenum > $num_chain_rules+1) {
        $idx_err = "Rule position $rulenum is past end of $from_chain " .
            "chain ($num_chain_rules rules), compensating."
            if $num_chain_rules > 0;
        $rulenum = $num_chain_rules + 1;
    }
    $rulenum = 1 if $rulenum == 0;

    if ($rule_position) {
        ### the rule already exists
        return 1,
            ["Table: $table, chain: $to_chain, jump rule already exists."], [];
    }

    ### we need to add the rule
    my ($rv, $out_aref, $err_aref) = $self->run_ipt_cmd(
        "$iptables -t $table -I $from_chain $rulenum -j $to_chain");
    push @$err_aref, $idx_err if $idx_err;
    return $rv, $out_aref, $err_aref;
}

sub REAPER {
    my $stiff;
    while(($stiff = waitpid(-1,WNOHANG))>0){
        # do something with $stiff if you want
    }
    local $SIG{'CHLD'} = \&REAPER;
    return;
}

sub run_ipt_cmd() {
    my $self  = shift;
    my $cmd = shift || croak qq|[*] Must specify an | .
        qq|$self->{'_ipt_bin_name'} command to run.|;
    my $iptables  = $self->{'_iptables'};
    my $iptout    = $self->{'_iptout'};
    my $ipterr    = $self->{'_ipterr'};
    my $debug     = $self->{'_debug'};
    my $ipt_alarm = $self->{'_ipt_alarm'};
    my $verbose   = $self->{'_verbose'};
    my $ipt_exec_style = $self->{'_ipt_exec_style'};
    my $ipt_exec_sleep = $self->{'_ipt_exec_sleep'};
    my $sigchld_handler = $self->{'_sigchld_handler'};


    croak "[*] $cmd does not look like an $self->{'_ipt_bin_name'} command."
        unless $cmd =~ m|^\s*iptables| or $cmd =~ m|^\S+/iptables|
            or $cmd =~ m|^\s*ip6tables| or $cmd =~ m|^\S+/ip6tables|;

    my $rv = 1;
    my @stdout = ();
    my @stderr = ();

    my $fh = *STDERR;
    $fh = *STDOUT if $verbose;

    if ($debug or $verbose) {
        print $fh localtime() . " [+] IPTables::ChainMgr::",
            "run_ipt_cmd(${ipt_exec_style}()) $cmd\n";
        if ($ipt_exec_sleep > 0) {
            print $fh localtime() . " [+] IPTables::ChainMgr::",
                "run_ipt_cmd() sleep seconds: $ipt_exec_sleep\n";
        }
    }

    if ($ipt_exec_sleep > 0) {

        if ($debug or $verbose) {
            print $fh localtime() . " [+] IPTables::ChainMgr: ",
                "sleeping for $ipt_exec_sleep seconds before ",
                "executing $self->{'_ipt_bin_name'} command.\n";
        }
        sleep $ipt_exec_sleep;
    }

    if ($ipt_exec_style eq 'system') {
        system qq{$cmd > $iptout 2> $ipterr};
    } elsif ($ipt_exec_style eq 'popen') {
        open CMD, "$cmd 2> $ipterr |" or croak "[*] Could not execute $cmd: $!";
        @stdout = <CMD>;
        close CMD;
        open F, "> $iptout" or croak "[*] Could not open $iptout: $!";
        print F for @stdout;
        close F;
    } else {
        my $ipt_pid;

        if ($debug or $verbose) {
            print $fh localtime() . " [+] IPTables::ChainMgr: " .
                "Setting SIGCHLD handler to: " . $sigchld_handler . "\n";
        }

        local $SIG{'CHLD'} = $sigchld_handler;
        if ($ipt_pid = fork()) {
            eval {
                ### iptables should never take longer than 30 seconds to execute,
                ### unless there is some absolutely enormous policy or the kernel
                ### is exceedingly busy
                local $SIG{'ALRM'} = sub {die "[*] $self->{'_ipt_bin_name'} " .
                    "command timeout.\n"};
                alarm $ipt_alarm;
                waitpid($ipt_pid, 0);
                alarm 0;
            };
            if ($@) {
                kill 9, $ipt_pid unless kill 15, $ipt_pid;
            }
        } else {
            croak "[*] Could not fork $self->{'_ipt_bin_name'}: $!"
                unless defined $ipt_pid;

            ### exec the iptables command and preserve stdout and stderr
            exec qq{$cmd > $iptout 2> $ipterr};
        }
    }

    if (not @stdout and -e $iptout) {
        open F, "< $iptout" or croak "[*] Could not open $iptout";
        @stdout = <F>;
        close F;
    }
    if (-e $ipterr) {
        open F, "< $ipterr" or croak "[*] Could not open $ipterr";
        @stderr = <F>;
        close F;

        $rv = 0 if @stderr;
    }

    if ($debug or $verbose) {
        print $fh localtime() . "     $self->{'_ipt_bin_name'} " .
            "command stdout:\n";
        for my $line (@stdout) {
            if ($line =~ /\n$/) {
                print $fh $line;
            } else {
                print $fh $line, "\n";
            }
        }
        print $fh localtime() . "     $self->{'_ipt_bin_name'} " .
            "command stderr:\n";
        for my $line (@stderr) {
            if ($line =~ /\n$/) {
                print $fh $line;
            } else {
                print $fh $line, "\n";
            }
        }
    }

    return $rv, \@stdout, \@stderr;
}

1;

__END__

=head1 NAME

IPTables::ChainMgr - Perl extension for manipulating iptables and ip6tables policies

=head1 SYNOPSIS

  use IPTables::ChainMgr;

  my $ipt_bin = '/sbin/iptables'; # can set this to /sbin/ip6tables

  my %opts = (
      'iptables' => $ipt_bin, # can specify 'ip6tables' hash key instead
      'iptout'   => '/tmp/iptables.out',
      'ipterr'   => '/tmp/iptables.err',
      'debug'    => 0,
      'verbose'  => 0,

      ### advanced options
      'ipt_alarm' => 5,  ### max seconds to wait for iptables execution.
      'ipt_exec_style' => 'waitpid',  ### can be 'waitpid',
                                      ### 'system', or 'popen'.
      'ipt_exec_sleep' => 1, ### add in time delay between execution of
                             ### iptables commands (default is 0).
  );

  my $ipt_obj = new IPTables::ChainMgr(%opts)
      or die "[*] Could not acquire IPTables::ChainMgr object";

  my $rv = 0;
  my $out_ar = [];
  my $errs_ar = [];

  # check to see if the 'CUSTOM' chain exists in the filter table
  ($rv, $out_ar, $errs_ar) = $ipt_obj->chain_exists('filter', 'CUSTOM');
  if ($rv) {
      print "CUSTOM chain exists.\n";

      ### flush all rules from the chain
      $ipt_obj->flush_chain('filter', 'CUSTOM');

      ### now delete the chain (along with any jump rule in the
      ### INPUT chain)
      $ipt_obj->delete_chain('filter', 'INPUT', 'CUSTOM');
  }

  # set the policy on the FORWARD table to DROP
  $ipt_obj->set_chain_policy('filter', 'FORWARD', 'DROP');

  # create new iptables chain in the 'filter' table
  $ipt_obj->create_chain('filter', 'CUSTOM');

  # translate a network into the same representation that iptables or
  # ip6tables uses (e.g. '10.1.2.3/24' is properly represented as '10.1.2.0/24',
  # and '0000:0000:00AA:0000:0000:AA00:0000:0001/64' = '0:0:aa::/64')
  $normalized_net = $ipt_obj->normalize_net('10.1.2.3/24');

  # add rule to jump packets from the INPUT chain into CUSTOM at the
  # 4th rule position
  $ipt_obj->add_jump_rule('filter', 'INPUT', 4, 'CUSTOM');

  # find rule that allows all traffic from 10.1.2.0/24 to 192.168.1.2
  ($rv, $rule_num) = $ipt_obj->find_ip_rule('10.1.2.0/24', '192.168.1.2',
      'filter', 'INPUT', 'ACCEPT', {'normalize' => 1});

  # find rule that allows all TCP port 80 traffic from 10.1.2.0/24 to
  # 192.168.1.1
  ($rv, $rule_num) = $ipt_obj->find_ip_rule('10.1.2.0/24', '192.168.1.2',
      'filter', 'INPUT', 'ACCEPT', {'normalize' => 1, 'protocol' => 'tcp',
      's_port' => 0, 'd_port' => 80});

  # add rule at the 5th rule position to allow all traffic from
  # 10.1.2.0/24 to 192.168.1.2 via the INPUT chain in the filter table
  ($rv, $out_ar, $errs_ar) = $ipt_obj->add_ip_rule('10.1.2.0/24',
      '192.168.1.2', 5, 'filter', 'INPUT', 'ACCEPT', {});

  # add rule at the 4th rule position to allow all traffic from
  # 10.1.2.0/24 to 192.168.1.2 over TCP port 80 via the CUSTOM chain
  # in the filter table
  ($rv, $out_ar, $errs_ar) = $ipt_obj->add_ip_rule('10.1.2.0/24',
      '192.168.1.2', 4, 'filter', 'CUSTOM', 'ACCEPT',
      {'protocol' => 'tcp', 's_port' => 0, 'd_port' => 80});

  # append rule at the end of the CUSTOM chain in the filter table to
  # allow all traffic from 10.1.2.0/24 to 192.168.1.2 via port 80
  ($rv, $out_ar, $errs_ar) = $ipt_obj->append_ip_rule('10.1.2.0/24',
      '192.168.1.2', 'filter', 'CUSTOM', 'ACCEPT',
      {'protocol' => 'tcp', 's_port' => 0, 'd_port' => 80});

  # for each of the examples above, here are ip6tables analogs
  # (requires instantiating the IPTables::ChainMgr object with
  # /sbin/ip6tables): find rule that allows all traffic from fe80::200:f8ff:fe21:67cf
  # to 0:0:aa::/64
  ($rv, $rule_num) = $ipt_obj->find_ip_rule('fe80::200:f8ff:fe21:67cf', '0:0:aa::/64',
      'filter', 'INPUT', 'ACCEPT', {'normalize' => 1});

  # find rule that allows all TCP port 80 traffic from fe80::200:f8ff:fe21:67c to 0:0:aa::/64
  ($rv, $rule_num) = $ipt_obj->find_ip_rule('fe80::200:f8ff:fe21:67cf', '0:0:aa::/64',
      'filter', 'INPUT', 'ACCEPT', {'normalize' => 1, 'protocol' => 'tcp',
      's_port' => 0, 'd_port' => 80});

  # add rule at the 5th rule position to allow all traffic from
  # fe80::200:f8ff:fe21:67c to 0:0:aa::/64 via the INPUT chain in the filter table
  ($rv, $out_ar, $errs_ar) = $ipt_obj->add_ip_rule('fe80::200:f8ff:fe21:67cf',
      '0:0:aa::/64', 5, 'filter', 'INPUT', 'ACCEPT', {});

  # add rule at the 4th rule position to allow all traffic from
  # fe80::200:f8ff:fe21:67c to 0:0:aa::/64 over TCP port 80 via the CUSTOM chain
  # in the filter table
  ($rv, $out_ar, $errs_ar) = $ipt_obj->add_ip_rule('fe80::200:f8ff:fe21:67cf',
      '0:0:aa::/64', 4, 'filter', 'CUSTOM', 'ACCEPT',
      {'protocol' => 'tcp', 's_port' => 0, 'd_port' => 80});

  # append rule at the end of the CUSTOM chain in the filter table to
  # allow all traffic from fe80::200:f8ff:fe21:67c to 0:0:aa::/64 via port 80
  ($rv, $out_ar, $errs_ar) = $ipt_obj->append_ip_rule('fe80::200:f8ff:fe21:67cf',
      '0:0:aa::/64', 'filter', 'CUSTOM', 'ACCEPT',
      {'protocol' => 'tcp', 's_port' => 0, 'd_port' => 80});

  # run an arbitrary iptables command and collect the output
  ($rv, $out_ar, $errs_ar) = $ipt_obj->run_ipt_cmd(
          '/sbin/iptables -v -n -L');

=head1 DESCRIPTION

The C<IPTables::ChainMgr> package provides an interface to manipulate iptables
and ip6tables policies on Linux systems through the direct execution of
iptables/ip6tables commands.  Although making a perl extension of libiptc
provided by the Netfilter project is possible (and has been done by the
IPTables::libiptc module available from CPAN), it is also easy enough to just
execute iptables/ip6tables commands directly in order to both parse and change
the configuration of the policy.  Further, this simplifies installation since
the only external requirement is (in the spirit of scripting) to be able to
point IPTables::ChainMgr at an installed iptables or ip6tables binary instead
of having to compile against a library.

=head1 FUNCTIONS

The IPTables::ChainMgr extension provides an object interface to the following
functions:

=over 4

=item chain_exists($table, $chain)

This function tests whether or not a chain (e.g. 'INPUT') exists within the
specified table (e.g. 'filter').  This is most useful to test whether
a custom chain has been added to the running iptables/ip6tables policy.  The
return values are (as with many IPTables::ChainMgr functions) an array of
three things: a numeric value, and both the stdout and stderr of the iptables
or ip6tables command in the form of array references.  So, an example
invocation of the chain_exists() function would be:

  ($rv, $out_ar, $errs_ar) = $ipt_obj->chain_exists('filter', 'CUSTOM');

If $rv is 1, then the CUSTOM chain exists in the filter table, and 0 otherwise.
The $out_ar array reference contains the output of the command "/sbin/iptables -t filter -v -n -L CUSTOM",
which will contain the rules in the CUSTOM chain (if it exists) or nothing (if not).
The $errs_ar array reference contains the stderr of the iptables command.  As
with all IPTables::ChainMgr functions, if the IPTables::ChainMgr object was
instantiated with the ip6tables binary path, then the above command would
become "/sbin/ip6tables -t filter -v -n -L CUSTOM".

=item create_chain($table, $chain)

This function creates a chain within the specified table.  Again, three return
values are given like so:

  ($rv, $out_ar, $errs_ar) = $ipt_obj->create_chain('filter', 'CUSTOM');

Behind the scenes, the create_chain() function in the example above runs the
iptables command "/sbin/iptables -t filter -N CUSTOM", or for ip6tables
"/sbin/ip6tables -t filter -N CUSTOM".

=item flush_chain($table, $chain)

This function flushes all rules from chain in the specified table, and three
values are returned:

  ($rv, $out_ar, $errs_ar) = $ipt_obj->flush_chain('filter', 'CUSTOM');

The flush_chain() function in the example above executes the command
"/sbin/iptables -t filter -F CUSTOM" or "/sbin/ip6tables -t filter -F CUSTOM".

=item set_chain_policy($table, $chain, $target)

This function sets the policy of a built-in chain (iptables/ip6tables does not allow
this for non built-in chains) to the specified target:

  ($rv, $out_ar, $errs_ar) = $ipt_obj->set_chain_policy('filter', 'FORWARD', 'DROP');

In this example, the following command is executed behind the scenes:
"/sbin/iptables -t filter -P FORWARD DROP" or "/sbin/ip6tables -t filter -P FORWARD DROP".

=item delete_chain($table, $jump_from_chain, $chain)

This function deletes a chain from the specified table along with any jump
rule to which packets are jumped into this chain:

  ($rv, $out_ar, $errs_ar) = $ipt_obj->delete_chain('filter', 'INPUT', 'CUSTOM');

Internally a check is performed to see whether the chain exists within
the table, and global jump rules are removed from the jump chain before
deletion (a chain cannot be deleted until there are no references to it).
In the example above, the CUSTOM chain is deleted after any jump rule
to this chain from the INPUT chain is also deleted.

=item find_ip_rule($src, $dst, $table, $chain, $target, %extended_info)

This function parses the specified chain to see if there is a rule that
matches the $src, $dst, $target, and (optionally) any %extended_info
criteria.  The return values are the rule number in the chain (or zero
if it doesn't exist), and the total number of rules in the chain.  Below
are four examples; the first is to find an ACCEPT rule for 10.1.2.0/24 to
communicate with 192.168.1.2 in the INPUT chain, and the second is the
same except that the rule is restricted to TCP port 80.  The third and
forth examples illustrate ip6tables analogs of the first two examples
with source IP fe80::200:f8ff:fe21:67cf/128 and destination network: 0:0:aa::/64

  ($rulenum, $chain_rules) = $ipt_obj->find_ip_rule('10.1.2.0/24',
      '192.168.1.2', 'filter', 'INPUT', 'ACCEPT', {'normalize' => 1});
  if ($rulenum) {
      print "matched rule $rulenum out of $chain_rules rules\n";
  }

  ($rulenum, $chain_rules) = $ipt_obj->find_ip_rule('10.1.2.0/24',
      '192.168.1.2', 'filter', 'INPUT', 'ACCEPT',
      {'normalize' => 1, 'protocol' => 'tcp', 's_port' => 0, 'd_port' => 80});
  if ($rulenum) {
      print "matched rule $rulenum out of $chain_rules rules\n";
  }

  ($rulenum, $chain_rules) = $ipt_obj->find_ip_rule('fe80::200:f8ff:fe21:67cf/128',
    '0:0:aa::/64', 'filter', 'INPUT', 'ACCEPT', {'normalize' => 1});
  if ($rulenum) {
      print "matched rule $rulenum out of $chain_rules rules\n";
  }

  ($rulenum, $chain_rules) = $ipt_obj->find_ip_rule('fe80::200:f8ff:fe21:67cf/128',
      '0:0:aa::/64', 'filter', 'INPUT', 'ACCEPT',
      {'normalize' => 1, 'protocol' => 'tcp', 's_port' => 0, 'd_port' => 80});
  if ($rulenum) {
      print "matched rule $rulenum out of $chain_rules rules\n";
  }

=item add_ip_rule($src, $dst, $rulenum, $table, $chain, $target, %extended_info)

This function inserts a rule into the running iptables chain and table at the
specified rule number.  Return values are success or failure along with the
iptables stdout and stderr.

=item append_ip_rule($src, $dst, $table, $chain, $target, %extended_info)

This function appends a rule at the end of the iptables chain in the specified
table.  Return values are success or failure along with the
iptables stdout and stderr.

=item delete_ip_rule($src, $dst, $table, $chain, $target, %extended_info)

This function searches for and then deletes a matching rule within the
specified chain.  Return values are success or failure along with the
iptables stdout and stderr.

=item add_jump_rule($table, $from_chain, $rulenum, $to_chain)

This function adds a jump rule (after making sure it doesn't already exist)
into the specified chain.  The $rulenum variable tells the function where
within the calling chain the new jump rule should be placed.  Here is an
example to force all packets regardless of source or destination to be
jumped to the CUSTOM chain from the INPUT chain at rule 4:

  ($rv, $out_ar, $errs_ar) = $ipt_obj->add_jump_rule('filter', 'INPUT', 4, 'CUSTOM');

=item normalize_net($net)

This function translates an IP/network into the same representation that iptables
or ip6tables uses upon listing a policy.  The first example shows an IPv4 network
and how iptables lists it, and the second is an IPv6 network:

  print $ipt_obj->normalize_net('10.1.2.3/24'), "\n" # prints '10.1.2.0/24'
  print $ipt_obj->normalize_net('0000:0000:00AA:0000:0000:AA00:0000:0001/64'), "\n" # prints '0:0:aa::/64'

=item run_ipt_cmd($cmd)

This function is a generic work horse function for executing iptables commands,
and is used internally by IPTables::ChainMgr functions.  It can also be used by
a script that imports the IPTables::ChainMgr extension to provide a consistent
mechanism for executing iptables.  Three return values are given: success (1)
or failure (0) of the iptables command (yes, this backwards from the normal
exit status of Linux/*NIX binaries), and array references to the iptables stdout
and stderr.  Here is an example to list all rules in the user-defined chain
"CUSTOM":

  ($rv, $out_ar, $errs_ar) = $ipt_obj->run_ipt_cmd('/sbin/iptables -t filter -v -n -L CUSTOM');
  if ($rv) {
      print "rules:\n";
      print for @$out_ar;
  }

=back


=head1 SEE ALSO

The IPTables::ChainMgr extension is closely associated with the IPTables::Parse
extension, and both are heavily used by the psad and fwsnort projects to
manipulate iptables policies based on various criteria (see the psad(8) and
fwsnort(8) man pages).  As always, the iptables(8) man page provides the best
information on command line execution and theory behind iptables.

Although there is no mailing that is devoted specifically to the IPTables::ChainMgr
extension, questions about the extension will be answered on the following
lists:

  The psad mailing list: http://lists.sourceforge.net/lists/listinfo/psad-discuss
  The fwsnort mailing list: http://lists.sourceforge.net/lists/listinfo/fwsnort-discuss

The latest version of the IPTables::ChainMgr extension can be found on CPAN and
also here:

  http://www.cipherdyne.org/modules/

Source control is provided by git:

  http://www.cipherdyne.org/git/IPTables-ChainMgr.git
  http://www.cipherdyne.org/cgi-bin/gitweb.cgi?p=IPTables-ChainMgr.git;a=summary

=head1 CREDITS

Thanks to the following people:

  Franck Joncourt <franck.mail@dthconnex.com>
  Grant Ferley
  Darien Kindlund

=head1 AUTHOR

The IPTables::ChainMgr extension was written by Michael Rash F<E<lt>mbr@cipherdyne.orgE<gt>>
to support the psad and fwsnort projects.  Please send email to this address if
there are any questions, comments, or bug reports.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005-2012 Michael Rash.  All rights reserved.

This module is free software.  You can redistribute it and/or
modify it under the terms of the Artistic License 2.0.  More information
can be found here: http://www.perl.com/perl/misc/Artistic.html

This program is distributed "as is" in the hope that it will be useful,
but without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut
