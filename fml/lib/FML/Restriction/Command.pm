#-*- perl -*-
#
#  Copyright (C) 2002,2003,2004,2005,2006 Ken'ichi Fukamachi
#   All rights reserved. This program is free software; you can
#   redistribute it and/or modify it under the same terms as Perl itself.
#
# $FML: Command.pm,v 1.24 2006/04/10 13:09:14 fukachan Exp $
#

package FML::Restriction::Command;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $AUTOLOAD);
use Carp;

use FML::Restriction::Post;
push(@ISA, qw(FML::Restriction::Post));


=head1 NAME

FML::Restriction::Command - command mail restrictions.

=head1 SYNOPSIS

collection of utility functions used in command routines.

=head1 DESCRIPTION

=head1 METHODS

=cut


# Descriptions: constructor.
#    Arguments: OBJ($self) OBJ($curproc)
# Side Effects: none
# Return Value: OBJ
sub new
{
    my ($self, $curproc) = @_;
    my ($type) = ref($self) || $self;
    my $me     = { _curproc => $curproc };
    return bless $me, $type;
}


# Descriptions: permit if $sender is an ML member.
#    Arguments: OBJ($self) STR($rule) STR($sender) OBJ($context)
# Side Effects: none
# Return Value: ARRAY(STR, STR)
sub permit_user_command
{
    my ($self, $rule, $sender, $context) = @_;
    my $curproc  = $self->{ _curproc };
    my $config   = $curproc->config();
    my $comname  = $context->get_cooked_command() || '';

    # ASSERT
    unless ($comname) {
	return(0, undef);
    }

    # 1) sender check
    my ($match, $reason) = $self->SUPER::permit_member_maps($rule, $sender);

    # 2) command match anonymous one ?
    # XXX-TODO: deny reason is first match ? last match ?
    if ($match) {
	if ($reason eq 'reject') {
	    my $_rule = "permit_member_maps";
	    $curproc->restriction_state_set_deny_reason($_rule);
	    return(0, undef);
	}
	else {
	    if ($config->has_attribute('user_command_mail_allowed_commands',
				       $comname)) {
		$curproc->logdebug("match: rule=$rule comname=$comname");
		return("matched", "permit");
	    }
	    else {
		$curproc->restriction_state_set_deny_reason($rule);
		return(0, undef);
	    }
	}
    }
    else {
	my $_rule = "permit_member_maps";
	$curproc->restriction_state_set_deny_reason($_rule);
	return(0, undef);
    }
}


# Descriptions: permit specific anonymous command
#               even if $sender is a stranger.
#    Arguments: OBJ($self) STR($rule) STR($sender) OBJ($context)
# Side Effects: none
# Return Value: ARRAY(STR, STR)
sub permit_anonymous_command
{
    my ($self, $rule, $sender, $context) = @_;
    my $curproc  = $self->{ _curproc };
    my $config   = $curproc->config();
    my $comname  = $context->get_cooked_command() || '';

    # ASSERT
    unless ($comname) {
	return(0, undef);
    }

    # 1) sender: no check.
    # 2) command match anonymous one ?
    if ($config->has_attribute('anonymous_command_mail_allowed_commands',
			       $comname)) {
	$curproc->logdebug("match: rule=$rule comname=$comname");
	return("matched", "permit");
    }
    # XXX-TODO: not need deny reason logging ?

    return(0, undef);
}


=head1 ADMIN COMMAND SPECIFIC RULES

=head2 permit_admin_member_maps($rule, $sender)

permit if admin_member_maps includes the sender in it.

=cut


# Descriptions: permit if admin_member_maps includes the sender in it.
#    Arguments: OBJ($self) STR($rule) STR($sender) OBJ($context)
# Side Effects: none
# Return Value: ARRAY(STR, STR)
sub permit_admin_member_maps
{
    my ($self, $rule, $sender, $context) = @_;
    my $curproc = $self->{ _curproc };

    # ASSERT
    my $comname = $context->get_cooked_command() || '';
    unless ($comname) {
	$curproc->logdebug("assert: no comname") if 0;
	return(0, undef);
    }

    my $cred  = $curproc->credential();
    my $match = $cred->is_privileged_member($sender);
    if ($match) {
	$curproc->logdebug("found in admin_member_maps");
	return("matched", "permit");
    }
    # XXX-TODO: not need deny reason logging ?

    return(0, undef);
}


# Descriptions: check if admin member passwrod is valid.
#    Arguments: OBJ($self) STR($rule) STR($sender) OBJ($context)
# Side Effects: none
# Return Value: ARRAY(STR, STR)
sub check_admin_member_password
{
    my ($self, $rule, $sender, $context) = @_;
    my $curproc = $self->{ _curproc };

    # ASSERT
    my $comname = $context->get_cooked_command() || '';
    unless ($comname) {
	return(0, undef);
    }

    use FML::Command::Auth;
    my $auth     = new FML::Command::Auth;
    my $opt_args = $context->get_admin_options() || {};
    my $status   = $auth->check_admin_member_password($curproc, $opt_args);
    if ($status) {
	$curproc->log("admin password: auth ok");
	return("matched", "permit");
    }
    else {
	# XXX-TODO: not need deny reason logging ?
	$curproc->logerror("admin password: auth fail");
	return(0, undef);
    }
}


=head1 EXTENSION: IGNORE CASE

=head2 ignore

ignore irrespective of other conditions.

=head2 ignore_invalid_request

ignore request if the content is invalid.

=cut


# Descriptions: ignore irrespective of other conditions.
#    Arguments: OBJ($self) STR($rule) STR($sender)
# Side Effects: none
# Return Value: ARRAY(STR, STR)
sub ignore
{
    my ($self, $rule, $sender) = @_;
    my $curproc = $self->{ _curproc };

    # XXX the deny reason is first match.
    unless ($curproc->restriction_state_get_ignore_reason()) {
	$curproc->restriction_state_set_ignore_reason($rule);
    }
    return("matched", "ignore");
}


# Descriptions: ignore request if the content is invalid.
#    Arguments: OBJ($self) STR($rule) STR($sender)
# Side Effects: none
# Return Value: ARRAY(STR, STR)
sub ignore_invalid_request
{
    my ($self, $rule, $sender) = @_;
    my $curproc = $self->{ _curproc };

    # XXX the deny reason is first match.
    unless ($curproc->restriction_state_get_ignore_reason()) {
	$curproc->restriction_state_set_ignore_reason($rule);
    }
    return("matched", "ignore");
}


=head1 EXTENSION: PGP/GPG AUTH

=head2 check_pgp_signature($rule, $sender, $context)

check PGP signature in message.

=cut


# Descriptions: check PGP signature in message.
#    Arguments: OBJ($self) STR($rule) STR($sender) OBJ($context)
# Side Effects: none
# Return Value: NUM
sub check_pgp_signature
{
    my ($self, $rule, $sender, $context) = @_;
    my $curproc  = $self->{ _curproc };
    my $match    = 0;
    my $pgp      = undef;

    # ASSERT
    my $comname = $context->get_cooked_command() || '';
    unless ($comname) {
	return(0, undef);
    }

    my $in_admin = $curproc->command_context_get_try_admin_auth_request();
    my $mode     = $in_admin ? "admin" : "user";
    if ($mode eq 'admin') {
	$self->_setup_pgp_environment("admin_command_mail_auth");
    }
    else {
	$self->_setup_pgp_environment("command_mail_auth");
    }

    eval q{
	use Crypt::OpenPGP;
	$pgp = new Crypt::OpenPGP;
    };
    if ($@) {
	$curproc->logerror("check_pgp_signature need Crypt::OpenPGP.");
	$curproc->logerror($@);
	$self->_reset_pgp_environment();
	return(0, undef);
    }

    my $file = $curproc->incoming_message_get_cache_file_path();
    my $ret  = $pgp->verify(SigFile => $file);
    unless ($pgp->errstr) {
	if ($ret) {
	    $curproc->log("pgp signature found: $ret");
	    $match = 1;
	}
    }
    $self->_reset_pgp_environment();

    $curproc->logdebug("$mode command_mail checks by pgp");
    if ($match) {
	$curproc->log("check_pgp_signature matched.");
	return("matched", "permit");
    }
    else {
	$curproc->logdebug("check_pgp_signature unmatched.");
	return(0, undef);
    }
}


# Descriptions: modify PGP related environment variables.
#    Arguments: OBJ($self) STR($mode)
# Side Effects: PGP related environment variables modified.
# Return Value: none
sub _setup_pgp_environment
{
    my ($self, $mode) = @_;
    my $curproc = $self->{ _curproc };
    my $config  = $curproc->config();

    # PGP2/PGP5/PGP6
    my $pgp_config_dir = $config->{ "${mode}_pgp_config_dir" };
    $ENV{'PGPPATH'}    = $pgp_config_dir;

    # GPG
    my $gpg_config_dir = $config->{ "${mode}_gpg_config_dir" };
    $ENV{'GNUPGHOME'}  = $gpg_config_dir;

    unless (-d $pgp_config_dir) {
        $curproc->mkdir($pgp_config_dir, "mode=private");
    }

    unless (-d $gpg_config_dir) {
        $curproc->mkdir($gpg_config_dir, "mode=private");
    }
}


# Descriptions: reset PGP related environment variables.
#    Arguments: OBJ($self)
# Side Effects: PGP related environment variables modified.
# Return Value: none
sub _reset_pgp_environment
{
    my ($self) = @_;
    delete $ENV{'PGPPATH'};
    delete $ENV{'GNUPGHOME'};
}


=head1 EXTENSION: MODERATOR

=head2 permit_forward_to_moderator($rule, $sender)

forward the incoming message to moderators.

=cut


# Descriptions: forward the incoming message to moderators.
#    Arguments: OBJ($self) STR($rule) STR($sender) OBJ($context)
# Side Effects: none
# Return Value: NUM
sub permit_forward_to_moderator
{
    my ($self, $rule, $sender, $context) = @_;
    my $curproc = $self->{ _curproc };
    my $comname = $context->get_cooked_command() || '';

    # ASSERT
    unless ($comname) {
	return(0, undef);
    }

    eval q{
	use FML::Moderate;
	my $moderation = new FML::Moderate $curproc;
	$moderation->forward_to_moderator();
    };
    if ($@) { $curproc->logerror($@);}

    # always OK.
    return("matched", "ignore");
}


=head1 UTILITIES

=cut

# Descriptions: check if the input string looks secure as a command ?
#    Arguments: OBJ($self) STR($s)
# Side Effects: none
#      History: fml 4.0's SecureP()
# Return Value: NUM(1 or 0)
sub _is_secure_command_string
{
   my ($self, $s) = @_;

   # 0. clean up
   $s =~ s/^\s*\#\s*//o; # remove ^#

   # 1. trivial case
   # 1.1. empty
   if ($s =~ /^\s*$/o) {
       return 1;
   }

   # 2. allow
   #           command = [-\d\w]+
   #      mail address = [-_\w]+@[\w\-\.]+
   #   command options = last:30
   #
   # XXX sync w/ mailaddress regexp in FML::Restriction::Base ?
   # XXX hmm, it is difficult.
   #
   if ($s =~/^[-\d\w]+\s*$/o) {
       return 1;
   }
   elsif ($s =~/^[-\d\w]+\s+[\s\w\_\-\.\,\@\:]+$/o) {
       return 1;
   }

   return 0;
}


# Descriptions: incremental regexp match for the given data.
#    Arguments: OBJ($self) VAR_ARGS($data)
# Side Effects: none
# Return Value: NUM(>0 or 0)
sub command_regexp_match
{
    my ($self, $data) = @_;
    my $r = 0;

    use FML::Restriction::Base;
    my $safe = new FML::Restriction::Base;

    if (ref($data)) {
	if (ref($data) eq 'ARRAY') {
	  DATA:
	    for my $x (@$data) {
		next DATA unless $x;

		unless ($safe->regexp_match('command_mail_substr', $x)) {
		    $r = 0;
		    last DATA;
		}
		else {
		    $r++;
		}
	    }
	}
	else {
	    my $curproc = $self->{ _curproc };
	    $curproc->logerror("FML::Restriction::Command: wrong data");
	    $r = 0;
	}
    }
    else {
	$r = $safe->regexp_match('command', $data);
    }

    return $r;
}


=head1 CODING STYLE

See C<http://www.fml.org/software/FNF/> on fml coding style guide.

=head1 AUTHOR

Ken'ichi Fukamachi

=head1 COPYRIGHT

Copyright (C) 2002,2003,2004,2005,2006 Ken'ichi Fukamachi

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=head1 HISTORY

FML::Restriction::Command first appeared in fml8 mailing list driver package.
See C<http://www.fml.org/> for more details.

=cut


1;
