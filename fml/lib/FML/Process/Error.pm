#-*- perl -*-
#
# Copyright (C) 2002 Ken'ichi Fukamachi
#          All rights reserved.
#
# $FML: Error.pm,v 1.4 2002/05/19 11:53:43 fukachan Exp $
#

package FML::Process::Error;

use vars qw($debug @ISA @EXPORT @EXPORT_OK);
use strict;
use Carp;
use FML::Log qw(Log LogWarn LogError);
use FML::Config;
use FML::Process::Kernel;
@ISA = qw(FML::Process::Kernel);


=head1 NAME

FML::Process::Error -- command dispacher.

=head1 SYNOPSIS

   use FML::Process::Error;
   ...

See L<FML::Process::Flow> for details of fml process flow.

=head1 DESCRIPTION

C<FML::Process::Error> is a command wrapper and top level
dispatcher for commands. 

=head1 METHODS

=head2 C<new($args)>

make fml process object, which inherits C<FML::Process::Kernel>.

=cut


# Descriptions: standard constructor.
#    Arguments: OBJ($self) HASH_REF($args)
# Side Effects: inherit FML::Process::Kernel
# Return Value: OBJ
sub new
{
    my ($self, $args) = @_;
    my $type    = ref($self) || $self;
    my $curproc = new FML::Process::Kernel $args;
    return bless $curproc, $type;
}


=head2 C<prepare($args)>

forward the request to SUPER CLASS.

=cut

# Descriptions: dummy
#    Arguments: OBJ($self) HASH_REF($args)
# Side Effects: none
# Return Value: none
sub prepare
{
    my ($self, $args) = @_;
    my $config = $self->{ config };

    my $eval = $config->get_hook( 'error_prepare_start_hook' );
    if ($eval) { eval qq{ $eval; }; LogWarn($@) if $@; }

    if ($config->yes('use_error_analyzer')) {
	$self->SUPER::prepare($args);
	$config->{ log_format_type } = 'new_style';
    }
    else {
	exit(0);
    }	

    $eval = $config->get_hook( 'error_prepare_end_hook' );
    if ($eval) { eval qq{ $eval; }; LogWarn($@) if $@; }
}


=head2 C<verify_request($args)>

verify the sender is a valid member or not.

=cut


# Descriptions: verify the sender of this process is an ML member.
#    Arguments: OBJ($curproc) HASH_REF($args)
# Side Effects: none
# Return Value: 1 or 0
sub verify_request
{
    my ($curproc, $args) = @_;
    my $config = $curproc->{ config };

    my $eval = $config->get_hook( 'error_verify_request_start_hook' );
    if ($eval) { eval qq{ $eval; }; LogWarn($@) if $@; }

    $eval = $config->get_hook( 'error_verify_request_end_hook' );
    if ($eval) { eval qq{ $eval; }; LogWarn($@) if $@; }
}


=head2 C<run($args)>

dispatcher to run correspondig C<FML::Error::command> for
C<command>. Standard style follows:

    lock
    execute FML::Error::command
    unlock

XXX Each command determines need of lock or not.

=cut


# Descriptions: call _evaluate_command_lines()
#    Arguments: OBJ($curproc) HASH_REF($args)
# Side Effects: none
# Return Value: none
sub run
{
    my ($curproc, $args) = @_;
    my $config = $curproc->{ config };
    my $found  = 0;
    my $pcb    = $curproc->{ pcb };
    my $msg    = $curproc->{ incoming_message }->{ message };

    my $eval = $config->get_hook( 'error_run_start_hook' );
    if ($eval) { eval qq{ $eval; }; LogWarn($@) if $@; }

    eval q{
	use Mail::Bounce;
	my $bouncer = new Mail::Bounce;
	$bouncer->analyze( $msg );

	for my $address ( $bouncer->address_list ) {
	    $found++;
	    my $status = $bouncer->status( $address );
	    my $reason = $bouncer->reason( $address );
	    Log("bounced: address=<$address>");
	    Log("bounced: status=$status");
	    Log("bounced: reason=\"$reason\"");
	}

	my $obj = $curproc->__open_cache();
	if (defined $obj) {
	    # show results
	    for my $address ( $bouncer->address_list ) {
		my $status = $bouncer->status( $address );
		my $reason = $bouncer->reason( $address );
		$obj->set($address, $status);
	    }
	}
    };
    LogError($@) if $@;

    $pcb->set("error", "found", 1) if $found;

    $eval = $config->get_hook( 'error_run_end_hook' );
    if ($eval) { eval qq{ $eval; }; LogWarn($@) if $@; }
}


=head2 help()

show help.

=cut


# Descriptions: show help
#    Arguments: none
# Side Effects: none
# Return Value: none
sub help
{
print <<"_EOF_";

Usage: $0 \$ml_home_prefix/\$ml_name [options]

   For example, process command of elena ML
   $0 /var/spool/ml/elena

_EOF_
}


=head2 C<finish($args)>

    $curproc->inform_reply_messages();

=cut


# Descriptions: finalize command process.
#               reply messages, command results et. al.
#    Arguments: OBJ($curproc) HASH_REF($args)
# Side Effects: queue manipulation
# Return Value: none
sub finish
{
    my ($curproc, $args) = @_;
    my $config = $curproc->{ config };
    my $pcb    = $curproc->{ pcb };

    my $eval = $config->get_hook( 'error_finish_start_hook' );
    if ($eval) { eval qq{ $eval; }; LogWarn($@) if $@; }

    if ($pcb->get("error", "found")) {
	Log("error message found");
	# $curproc->inform_reply_messages();
	# $curproc->queue_flush();
    }
    else {
	Log("error message not found");
    }

    $eval = $config->get_hook( 'error_finish_end_hook' );
    if ($eval) { eval qq{ $eval; }; LogWarn($@) if $@; }
}


sub __open_cache
{
    my ($curproc) = @_;
    my $config = $curproc->{ config };
    my $dir    = $config->{ error_cache_dir };
    my $mode   = 'temporal';
    my $days   = 14;

    if ($dir) {
        use File::CacheDir;
        my $obj = new File::CacheDir {
            directory  => $dir,
            cache_type => $mode,
            expires_in => $days,
        };

        return $obj;
    }

    return undef;
}


=head1 AUTHOR

Ken'ichi Fukamachi

=head1 COPYRIGHT

Copyright (C) 2002 Ken'ichi Fukamachi

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=head1 HISTORY

FML::Process::Error appeared in fml5 mailing list driver package.
See C<http://www.fml.org/> for more details.

=cut


1;
