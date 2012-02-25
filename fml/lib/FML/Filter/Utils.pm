#-*- perl -*-
#
#  Copyright (C) 2001 Ken'ichi Fukamachi
#   All rights reserved. This program is free software; you can
#   redistribute it and/or modify it under the same terms as Perl itself. 
#
# $FML: @template.pm,v 1.1 2001/08/07 12:23:48 fukachan Exp $
#

package FML::Filter::Utils;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $AUTOLOAD);
use Carp;

=head1 NAME

FML::Filter::Utils - useful subroutines for filtering

=head1 SYNOPSIS

collection of utility functions

=head1 DESCRIPTION

=head1 METHODS

=cut

# Descriptions: 
#    Arguments: $self $args
# Side Effects: 
#      History: fml 4.0's SecureP()
# Return Value: none
sub is_secure_command_string
{
   my ($s) = @_;

   # 0. clean up
   $s =~ s/^\s*\#\s*//; # remove ^#

   # 1. trivial case
   # 1.1. empty
   if ($s =~ /^\s*$/) {
       return 1;
   }

   # 2. allow 
   #           command = \w+
   #      mail address = [-_\w]+@[\w\-\.]+
   #   command options = last:30
   if ($s =~/^[\s\w\_\-\.\,\@\:]+$/) {
       return 1;
   }

   return 0;
}


=head2 C<is_valid_mail_address($string)>

1. check C<$strings> contains no Japanese string.

=cut


sub is_valid_mail_address
{
    my ($s) = @_;

    ($s !~ /\s|\033\$[\@B]|\033\([BJ]/ && 
     $s =~ /^[\0-\177]+\@[\0-\177]+$/) ? 1 : 0;
}


=head1 AUTHOR

Ken'ichi Fukamachi

=head1 COPYRIGHT

Copyright (C) 2001 Ken'ichi Fukamachi

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself. 

=head1 HISTORY

FML::Filter::Utils appeared in fml5 mailing list driver package.
See C<http://www.fml.org/> for more details.

=cut


1;