#!/bin/sh
#
# $FML: test_htmlifier.sh,v 1.4 2002/03/31 05:25:47 fukachan Exp $
#

./perlcheck Mail/Message/ToHTML.pm ||exit 1

spool_dir=${spool_dir:-/bakfs/project/fml/fml/ml/fml-help/spool}

rm -fr /tmp/htdocs /tmp/elena
mkdir /tmp/htdocs 

perl -I ../../cpan/lib Mail/Message/ToHTML.pm $spool_dir

ls -lRa /tmp/htdocs 
# cat /tmp/htdocs/msg2.html 
# apply readdb.pl /tmp/htdocs/.ht_mhl_*db
