#-*- perl -*-
#
#  Copyright (C) 2001 Ken'ichi Fukamachi
#   All rights reserved. This program is free software; you can
#   redistribute it and/or modify it under the same terms as Perl itself. 
#
# $Id$
# $FML$
#

package FML::MIME;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK);
use Carp;


require Exporter;
@ISA       = qw(Exporter);
@EXPORT_OK = qw(decode_mime_string encode_mime_string);


sub decode_mime_string
{
    my ($str, $options) = @_;
    my $charset = $options->{ 'charset' } || 'euc-japan';

    if ($charset eq 'euc-japan') {
	use Jcode;
	use MIME::Base64;

	if ($str =~ /=\?ISO\-2022\-JP\?B\?(\S+\=*)\?=/i) { 
	    $str =~ s/=\?ISO\-2022\-JP\?B\?(\S+\=*)\?=/decode_base64($1)/gie;
	}

	if ($str =~ /=\?ISO\-2022\-JP\?B\?(\S+\=*)\?=/i) { 
	    $str =~ s/=\?ISO\-2022\-JP\?B\?(\S+\=*)\?=/decode_base64($1)/gie;
	}
    }

    &Jcode::convert(\$str, 'euc');
    $str;
}


sub encode_mime_string
{
    my ($str, $options) = @_;
    my $charset = $options->{ 'charset' } || 'iso-2022-jp';

    &Jcode::convert(\$str, 'jis');
    $str = encode_base64($str);
    $str  =~ s/\n$//;

    return '=?'. $charset . '?B?' . $str . '?=';
}


# original idea comes from
# import fml-support: 02651 (hirono@torii.nuie.nagoya-u.ac.jp)
# import fml-support: 03440, Masaaki Hirono <hirono@highway.or.jp>
my $MimeBEncPat = 
	'=\?[Ii][Ss][Oo]-2022-[Jj][Pp]\?[Bb]\?([A-Za-z0-9\+\/]+)=*\?=';

my $MimeQEncPat = 
	'=\?[Ii][Ss][Oo]-2022-[Jj][Pp]\?[Qq]\?([\011\040-\176]+)=*\?=';

#  s/$MimeBEncPat/&kconv(&base64decode($1))/geo;
#  s/$MimeQEncPat/&kconv(&MimeQDecode($1))/geo;
# sub MimeQDecode
# {
#    local($_) = @_;
#    s/=*$//;
#    s/=(..)/pack("H2", $1)/ge;
#    $_;
#}



=head1 NAME

FML::MIME.pm - what is this


=head1 SYNOPSIS

=head1 DESCRIPTION

=head2 new

=item Function()


=head1 AUTHOR

=head1 COPYRIGHT

Copyright (C) 2001 Ken'ichi Fukamachi

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself. 

=head1 HISTORY

FML::MIME appeared in fml5.

=cut


1;
