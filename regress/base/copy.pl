#!/usr/local/bin/perl
#-*- perl -*-
#
#  Copyright (C) 2001 Ken'ichi Fukamachi
#   All rights reserved. This program is free software; you can
#   redistribute it and/or modify it under the same terms as Perl itself. 
#
# $FML: copy.pl,v 1.3 2001/04/03 09:51:12 fukachan Exp $
#

unless (@ARGV) {
    use FML::Utils qw(copy);
    copy("main.cf", "/tmp/main.cf");
}
else {
    my ($src, $dst) = @ARGV;

    use IO::File::Atomic;
    print "IO::File::Atomic->copy($src, $dst);\n";
    print "sleep 3;\n";
    sleep 3;
    my $status = IO::File::Atomic->copy($src, $dst) || die("fail to copy");
}

exit 0;