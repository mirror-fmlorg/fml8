#-*- perl -*-
#
#  Copyright (C) 2001 Ken'ichi Fukamachi
#   All rights reserved. This program is free software; you can
#   redistribute it and/or modify it under the same terms as Perl itself. 
#
# $FML: Configure.pm,v 1.2 2001/04/03 09:45:41 fukachan Exp $
#

package FML::CGI::Configure;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $AUTOLOAD);
use Carp;

use CGI qw/:standard/; # load standard CGI routines

use FML::Process::CGI;
@ISA = qw(FML::Process::CGI);


=head1 NAME

FML::CGI::Configure - provides functions for makefml CGI interface

    XXX NOT YET IMPLEMENTED

=head1 SYNOPSIS

    $makefml = new FML::CGI::Configure;
    $makefml->new();
    $makefml->run();

See L<FML::Process::Flow> for flow details.

=head1 DESCRIPTION

C<NOT YET IMPLEMENTED>.

=head2 CLASS HIERARCHY

C<FML::CGI::Configure> is a subclass of C<FML::Process::CGI>.

             FML::Process::Kernel
                       |
                       A
             FML::Process::CGI
                       |
                       A
            -----------------------
           |                       |
           A                       A
 FML::CGI::Configure

=head1 METHODS

Almost methods common for CGI or HTML are forwarded to
C<FML::Process::CGI> base class.

This module has routines needed for CGI.

=head1 SEE ALSO

L<CGI>,
L<FML::Process::CGI>
and 
L<FML::Process::Flow>

=head1 AUTHOR

Ken'ichi Fukamachi

=head1 COPYRIGHT

Copyright (C) 2001 Ken'ichi Fukamachi

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself. 

=head1 HISTORY

FML::CGI::Configure appeared in fml5 mailing list driver package.
See C<http://www.fml.org/> for more details.

=cut


1;