#-*- perl -*-
#
#  Copyright (C) 2001,2002,2003 Ken'ichi Fukamachi
#   All rights reserved. This program is free software; you can
#   redistribute it and/or modify it under the same terms as Perl itself.
#
# $FML: byeadmin.pm,v 1.9 2003/01/25 12:48:37 fukachan Exp $
#

package FML::Command::Admin::byeadmin;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $AUTOLOAD);
use Carp;


=head1 NAME

FML::Command::Admin::byeadmin - remove the specified administrator

=head1 SYNOPSIS

See C<FML::Command> for more details.

=head1 DESCRIPTION

remove the specified administrator.

=head1 METHODS

=head2 C<process($curproc, $command_args)>

=cut


# Descriptions: standard constructor
#    Arguments: OBJ($self)
# Side Effects: none
# Return Value: OBJ
sub new
{
    my ($self) = @_;
    my ($type) = ref($self) || $self;
    my $me     = {};
    return bless $me, $type;
}


# Descriptions: need lock or not
#    Arguments: none
# Side Effects: none
# Return Value: NUM( 1 or 0)
sub need_lock { 1;}


# Descriptions: remove the specified administrator
#    Arguments: OBJ($self) OBJ($curproc) HASH_REF($command_args)
# Side Effects: update $member_map $recipient_map
# Return Value: none
sub process
{
    my ($self, $curproc, $command_args) = @_;
    my $config = $curproc->config();

    # target maps
    my $member_maps    = $config->get_as_array_ref('admin_member_maps');
    my $recipient_maps = $config->get_as_array_ref('admin_recipient_maps');
    my $options        = $command_args->{ options };
    my $address        = $command_args->{ command_data } || $options->[ 0 ];

    # fundamental check
    croak("address not undefined")        unless defined $address;
    croak("address not specified")        unless $address;
    croak("member_maps not undefined")    unless defined $member_maps;
    croak("member_maps not specified")    unless $member_maps;
    croak("recipient_maps not undefined") unless defined $recipient_maps;
    croak("recipient_maps not specified") unless $recipient_maps;

    # maplist
    my $maplist = [];
    push(@$maplist, @$member_maps)    if @$member_maps;
    push(@$maplist, @$recipient_maps) if @$recipient_maps;

    # FML::Command::UserControl specific parameters
    my $uc_args = {
	address => $address,
	maplist => $maplist,
    };
    my $r = '';

    eval q{
	use FML::Command::UserControl;
	my $obj = new FML::Command::UserControl;
	$obj->userdel($curproc, $command_args, $uc_args);
    };
    if ($r = $@) {
	croak($r);
    }
}


# Descriptions: show cgi menu to remove the administrator
#    Arguments: OBJ($self)
#               OBJ($curproc) HASH_REF($args) HASH_REF($command_args)
# Side Effects: update $member_map $recipient_map
# Return Value: none
sub cgi_menu
{
    my ($self, $curproc, $args, $command_args) = @_;
    my $r = '';

    eval q{
	use FML::CGI::Admin::User;
	my $obj = new FML::CGI::Admin::User;
	$obj->cgi_menu($curproc, $args, $command_args);
    };
    if ($r = $@) {
	croak($r);
    }
}


=head1 CODING STYLE

See C<http://www.fml.org/software/FNF/> on fml coding style guide.

=head1 AUTHOR

Ken'ichi Fukamachi

=head1 COPYRIGHT

Copyright (C) 2001,2002,2003 Ken'ichi Fukamachi

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=head1 HISTORY

FML::Command::Admin::byeadmin first appeared in fml8 mailing list driver package.
See C<http://www.fml.org/> for more details.

=cut


1;
