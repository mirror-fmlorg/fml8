#!/usr/bin/env perl
#
# $FML: gen_rules.pl,v 1.4 2006/01/01 14:05:22 fukachan Exp $
#

use strict;
use Carp;

my $debug     = $ENV{'debug'} || 0;
my $var_rules = {};
my $var_count = 0;
my $recursive = 0;
my $if_state  = 0;
my $if_stack  = 0;
my (@if_stack) = ();
my $ignore_regexp = 'unavailable|not_yet_configurable';

# 1. read RULES.txt
_parse_rule_file(@ARGV);

# 2. show translation rules (perl script).
_preamble();
for my $var_name (sort {$a <=> $b} keys %$var_rules) {
    $recursive = 0;
    _print_translated_rules($var_name, $var_rules->{ $var_name });
}
_trailor();

exit 0;


=head1 INITIALIZATION

=cut


# Descriptions: 
#    Arguments: STR($rule_file)
# Side Effects: update $var_rules HASH_REF.
# Return Value: none
sub _parse_rule_file
{
    my ($rule_file) = @_;

    use FileHandle;
    my $rh = new FileHandle $rule_file;
    if (defined $rh) {
	my $var_name = '';
	my $buf;

      LINE:
	while ($buf = <$rh>) {
	    next LINE if $buf =~ /^\s*$/o;
	    next LINE if $buf =~ /^\#/o;

	    if ($buf =~ /^\.if\s+(\S+)/o) {
		$var_name = sprintf("%s_%s", $var_count++, $1);
		$var_rules->{ $var_name } .= $buf;
		next LINE;
	    }

	    if ($var_name) {
		if ($buf =~ /^\s*\.($ignore_regexp)/o) {
		    if ($debug) {
			print STDERR "var_name = $var_name\n";
			print STDERR "\tignored ($1)\n";
		    }
		    # $var_rules->{ $var_name } = '';
		}
		elsif ($buf =~ /\S+/o) {
		    if ($debug) {
			print STDERR "var_name = $var_name\n";
			print STDERR "\t", $buf, "\n";
		    }
		    $var_rules->{ $var_name } .= $buf;
		}
		else {
		    if ($debug) {
			print STDERR "var_name = $var_name\n";
			print STDERR "\t", $buf, "\n";
		    }
		    $var_rules->{ $var_name } .= $buf;
		}
	    }

	}
	$rh->close();
    }
    else {
	croak("cannot open $rule_file\n");
    }
}


=head1 TRANSLATION OF RULES

=cut


# Descriptions: print out preamble of output of perl script.
#    Arguments: none
# Side Effects: none
# Return Value: none
sub _preamble
{
    use File::Basename;
    my $prog = basename($0);

    print qq{#
# -*- perl -*-
#     *** CAUTION *** 
#     DO NOT EDIT THIS FILE BY HAND!.
#     THIS FILE IS AUTOMATICALLY GENERATED BY $prog.
#
#  Copyright (C) 2005,2006 Ken'ichi Fukamachi
#   All rights reserved. This program is free software; you can
#   redistribute it and/or modify it under the same terms as Perl itself.
#
# \$FML\$
#
};

print q!
package FML::Merge::FML4::Rules;


# Descriptions: translate fml4 rule to the corresponding fml8 one.
#    Arguments: OBJ($self)
#               HASH_REF($dispatch) HASH_REF($config) HASH_REF($diff) 
#               STR($key) STR($value)
# Side Effects: none
# Return Value: STR
sub translate
{
    my ($self, $dispatch, $config, $diff, $key, $value) = @_;
    my $fp_rule_convert             = $dispatch->{ rule_convert };
    my $fp_rule_prefer_fml4_value   = $dispatch->{ rule_prefer_fml4_value };
    my $fp_rule_prefer_fml8_value   = $dispatch->{ rule_prefer_fml8_value };
    my $fp_rule_ignore              = $dispatch->{ rule_ignore };
    my $fp_rule_not_yet_implemented = $dispatch->{ rule_not_yet_implemented };
    my $s;

!;
}


# Descriptions: print out the trailor part of output of perl script.
#    Arguments: none
# Side Effects: none
# Return Value: none
sub _trailor
{
    print "\n   return '';\n";
    print "} # sub translate\n";
    print "\n1;\n";
}


# Descriptions: print out translated rules.
#    Arguments: STR($var_name) STR($var_rules)
# Side Effects: none
# Return Value: none
sub _print_translated_rules
{
    my ($var_name, $var_rules) = @_;
    my $found    = 0;
    my $i        = 0;

    print STDERR "ALLOC $var_name => $var_rules\n" if $debug;
    return unless $var_name;
    return unless $var_rules;

  RULE:
    for my $rule (split(/\n/, $var_rules)) {
	$i++;
	print STDERR "$var_name [$i] $rule\n" if $debug;

	# 1st level (/^.if .../ statement)
	if ($rule =~ /^\.if/o) {
	    _parse_if($rule, $recursive);
	    $if_state = 1;
	}
	elsif ($rule =~ /^\S+/) {
	    print STDERR "UNKNOWN RULE: <$rule>\n";
	}
	# 2nd level (/^\s+\S+/ statement)
	else {
	    $rule =~ s/^\s*//;
	    $rule =~ s/\s*$//;

	    if ($rule =~ /^\.if/o) {
		$recursive++;
		_parse_if($rule, $recursive);
		$if_state = 1;
		next RULE;
	    }

	    # .if statement(s) stacked.
	    if ($if_state) {
		_print_if();
	    }

	    if ($rule eq '.use_fml4_value') {
		$found = 1;
		_print("\$s .= \&\$fp_rule_prefer_fml4_value(\$self, \$config, \$diff, \$key, \$value);");
	    }
	    elsif ($rule eq '.use_fml8_value') {
		$found = 1;
		_print("\$s .= \&\$fp_rule_prefer_fml8_value(\$self, \$config, \$diff, \$key, \$value);");
	    }
	    elsif ($rule eq '.convert') {
		$found = 1;
		_print("\$s .= \&\$fp_rule_convert(\$self, \$config, \$diff, \$key, \$value);");
	    }
	    elsif ($rule =~ /^\s*\.(ignore|not_support)/o) {
		$found = 1;
		_print("\$s .= \&\$fp_rule_ignore(\$self, \$config, \$diff, \$key, \$value);");
	    }
	    elsif ($rule =~ /^\s*\.(not_yet_implemented)/o) {
		$found = 1;
		_print("\$s .= \&\$fp_rule_not_yet_implemented(\$self, \$config, \$diff, \$key, \$value);");
	    }
	    elsif ($rule =~ /^\s*\.($ignore_regexp)/o) {
		$found = 1;
		_print("\$s .= \"\# $rule\";");
	    }
	    else {
		$found = 1;
		_print("\$s .= \"$rule\";");
	    }

	    while ($recursive > 0) {
		_print("}");
		$recursive--;
	    }

	    while ($if_stack > 0) {
		_print("}");
		$if_stack--;
	    }

	} # if 
    } # for my $rule (...)

    if ($found) {
	_print("return \$s if defined \$s;");
	print "}\n";
    }
}


# Descriptions: parse 1st and 2nd level .if statement.
#    Arguments: STR($rule) NUM($recursive)
# Side Effects: none
# Return Value: none
sub _parse_if
{
    my ($rule, $recursive) = @_;

    push(@if_stack, $rule);
}


sub _print_if
{
    my $i = 0;

    # 1. check if differences are found.
    print "if (";
    for my $rule (@if_stack) {
	if ($i) {
	    print " || ";
	}
	if ($rule =~ /^\.if\s+(\S+)/) {
	    print "\$diff->{ $1 }";
	    $i++;
	}
    }
    print ") {\n";

    # 2. translate rules based on config.ph values.
    __print_if(@if_stack);

    # 3. declare "close 1.";
    $if_stack++;

    # 4. reset
    @if_stack = ();
}


sub __print_if
{
    my (@rules)  = @_;

    for my $rule (@rules) {
	if ($rule =~ /^\.if\s+(\S+)\s+(==|>|>=|<|<=)\s+(\S+)/) {
	    my ($key, $op, $value) = ($1, $2, $3);
	    if ($value =~ /^\d+$/o) {
		_print("if (\$config->{ $key } $op $value) {");
		_print("\$s = undef;");
	    }
	    else {
		_print("if (\$config->{ $key } eq '$value') {");
		_print("\$s = undef;");
	    }
	}
	elsif ($rule =~ /^\.if\s+(\S+)\s+\!=\s+(\S+)/) {
	    my ($key, $value) = ($1, $2);
	    if ($value =~ /^\d+$/o) {
		_print("if (\$config->{ $key } \!= $value) {");
		_print("\$s = undef;");
	    }
	    else {
		_print("if (\$config->{ $key } ne '$value') {");
		_print("\$s = undef;");
	    }
	}
	elsif ($rule =~ /^\.if\s+(\S+)\s*$/) {
	    my ($key) = $1;
	    _print("if (\$config->{ $key }) {");
	    _print("\$s = undef;");
	}
    }
}


=head1 UTILITIES

=cut

# Descriptions: printf wrapper to prepend spaces in a line.
#    Arguments: STR($s)
# Side Effects: none
# Return Value: none
sub _puts
{
    my ($s) = @_;
    my $rule_out = "    " x ($recursive + 1);
    return sprintf("%s%s\n", $rule_out, $s);
}

sub _print
{
    my ($s) = @_;
    print _puts($s);
}
