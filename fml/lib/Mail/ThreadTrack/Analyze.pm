#-*- perl -*-
#
#  Copyright (C) 2001 Ken'ichi Fukamachi
#   All rights reserved. This program is free software; you can
#   redistribute it and/or modify it under the same terms as Perl itself. 
#
# $FML: Analyze.pm,v 1.4 2001/11/03 01:22:14 fukachan Exp $
#

package Mail::ThreadTrack::Analyze;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $AUTOLOAD);
use Carp;

=head1 NAME

Mail::ThreadTrack::Analyze - analyze mail thread relation

=head1 SYNOPSIS

See C<Mail::ThreadTrack> perl module for more detail.

=head1 DESCRIPTION

=head1 METHODS

=head2 C<analyze($mesg)>

C<$mesg> is Mail::Message object.

This is top level entrance for

1) assign a new thread or extract the existing thread-id from the subject.

2) update thread status if needed.

3) update database.

=cut


# Descriptions: top level entrance
#    Arguments: $self $msg
#               $msg = "Mail::Messge object"
# Side Effects: none
# Return Value: none
sub analyze
{
    my ($self, $msg) = @_;

    $self->assign($msg);
    $self->update_thread_status($msg);
    $self->update_db($msg);
}


=head2 assign($msg)

analyze message given by $msg and assign thread id if needed.

=cut


# Descriptions: given string looks like subject or not
#    Arguments: $string
# Side Effects: none
# Return Value: 1/0
sub _is_reply
{
    my ($subject) = @_;

    use Mail::Message::Language::Japanese::Subject;
    return Mail::Message::Language::Japanese::Subject::is_reply($subject);
}


# Descriptions: assign a new thread id or 
#               extract the existing thread-id from the subject
#    Arguments: $self $msg
# Side Effects: a new thread_id may be assigned
#               article header is rewritten
# Return Value: none
sub assign
{
    my ($self, $msg) = @_;
    my $header   = $msg->rfc822_message_header();
    my $subject  = $header->get('subject');
    my $is_reply = _is_reply($subject);

    # 1. try to extract $thread_id from header
    my $thread_id = $self->_extract_thread_id_in_subject($header);
    unless ($thread_id) {
	# we fail to pick up thread id from subject 
	# but we try to speculate id from other fields in header.
	$thread_id = $self->_speculate_thread_id_from_header($header);
	if ($thread_id) {
	    $is_reply = 1; # message already have thread_id, so replied one?
	    $self->set_thread_id($thread_id);
	    $self->log("speculated id=$thread_id");
	}
	else {
	    $self->log("(debug) fail to spelucate thread_id");
	}
    }

    # 2. check "X-Thread-Pragma:" field, 
    #    we ignore this mail if the pragma is specified as "ignore".
    if (defined $header->get('x-thread-pragma')) {
	my $pragma = $header->get('x-thread-pragma') || '';
	if ($pragma =~ /ignore/i) {
	    $self->{ _pragma } = 'ignore';
	    $self->_append_thread_status_info("ignored");
	    return undef;
	}
    }
    
    # 3. if the header has some thread_id, 
    #    we do not rewrite the subject but save the extracted $thread_id.
    if ($is_reply && $thread_id) {
	$self->log("reply message with thread_id=$thread_id");
	$self->set_thread_id($thread_id);
	$self->{ _status    } = 'analyzed';
	$self->_append_thread_status_info('analyzed');
    }
    elsif ($thread_id) {
	$self->log("message with thread_id=$thread_id but not reply");
	$self->set_thread_id($thread_id);
	$self->_append_thread_status_info("found");
    }
    else {
	$self->log("message without thread_id");

	# assign a new thread number for a new message
	my $id = $self->increment_id();
	$self->log("assign thread_id=$id");

	# side effect: 
	# define $self->{ _thread_subject_tag } and $self->{ _thread_id }
	$self->_make_thread_id_strings($header, $id);
	$self->_append_thread_status_info("newly assigned");

	$self->_rewrite_header($header, $id);
    }
}


# Descriptions: 
#    Arguments: $self $args
# Side Effects: 
# Return Value: none
sub _append_thread_status_info
{
    my ($self, $s) = @_;
    $self->{ _status_info } .= $self->{ _status_info } ? " -> ".$s : $s;
}


=head2 update_thread_status($msg)

=cut


# Descriptions: 
#    Arguments: $self $args
# Side Effects: 
# Return Value: none
sub update_thread_status
{
    my ($self, $msg) = @_;

    return if $self->{ _pragma } eq 'ignore';

    # entries to check
    my $header  = $msg->rfc822_message_header();
    my $subject = $header->get('subject');
    my $pragma  = $header->get('x-thread-pragma') || '';

    my $content = '';
    my $message = $msg->get_first_plaintext_message();
    if (ref($message) eq 'Mail::Message') {
	$content = $message->data_in_body_part();
    }
    else {
	croak("invalid object");
    }

    if ($content =~ /^\s*close/ || 
	$subject =~ /^\s*close/ || 
	$pragma  =~ /close/      ) {
	$self->{ _status } = "closed";
	$self->_append_thread_status_info("closed");
	$self->log("thread is closed");
    }
    else {
	$self->log("thread status not changed");
    }
}


=head2 get_thread_id()

=head2 set_thread_id()

=cut


sub get_thread_id
{
    my ($self) = @_;
    return(defined $self->{ _thread_id } ? $self->{ _thread_id } : undef);
}


sub set_thread_id
{
    my ($self, $thread_id) = @_;
    $self->{ _thread_id } = $thread_id;
    return $thread_id;
}


# Descriptions: create regexp for a subject tag, for example
#               "[%s %05d]" => "\[\S+ \d+\]"
#    Arguments: a subject tag string
#               XXX non OO type function
# Side Effects: none
# Return Value: a regexp for the given tag
sub _regexp_compile
{
    my ($s) = @_;

    $s = quotemeta( $s );
    $s =~ s@\\\%@\%@g;
    $s =~ s@\%s@\\S+@g;
    $s =~ s@\%d@\\d+@g;
    $s =~ s@\%0\d+d@\\d+@g;
    $s =~ s@\%\d+d@\\d+@g;
    $s =~ s@\%\-\d+d@\\d+@g;

    # quote for regexp substitute: [ something ] -> \[ something \]
    # $s =~ s/^(.)/quotemeta($1)/e;
    # $s =~ s/(.)$/quotemeta($1)/e;

    return $s;
}


# Descriptions: 
#    Arguments: $self $args
# Side Effects: 
# Return Value: none
sub _extract_message_id_references
{
    my ($header) = @_;
    my (@addrs, @r, %uniq) = ();

    use Mail::Address;

    if (defined $header->get('in-reply-to')) {
	my $buf = $header->get('in-reply-to');
	push(@addrs, Mail::Address->parse($buf));
    }

    if (defined $header->get('references')) {
	my $buf = $header->get('references');
	push(@addrs, Mail::Address->parse($buf));
    }

    for my $addr (@addrs) { 
        my $a = $addr->address;
        unless ($uniq{ $a }) {
            push(@r, $addr->address);
            $uniq{ $a } = 1;
        }
    }

    \@r;
}


# Descriptions: 
#    Arguments: $self $args
# Side Effects: 
# Return Value: none
sub _extract_thread_id_in_subject
{
    my ($self, $header) = @_;
    my $config  = $self->{ _config };
    my $tag     = $config->{ thread_subject_tag };
    my $subject = $header->get('subject');
    my $regexp  = _regexp_compile($tag);

    # Subject: ... [thread_id]
    if (($config->{ thread_subject_tag_location } eq 'appended') &&
	($subject =~ /($regexp)\s*$/)) {
	my $id = $1;
	$id =~ s/^(\[|\(|\{)//;
	$id =~ s/(\]|\)|\})$//;
	return $id;
    }
    # XXX incomplete, we check subject after cutting off "Re:" et. al.
    # Subject: [thread_id] ...
    # Subject: Re: [thread_id] ...
    elsif (($config->{ thread_subject_tag_location } eq 'appended') &&
	   ($subject =~ /^\s*($regexp)/)) {
	my $id = $1;
	$id =~ s/^(\[|\(|\{)//;
	$id =~ s/(\]|\)|\})$//;
	return $id;
    }
    else {
	$self->log("no thread id /$regexp/ in subject");
	return 0;
    }
}


# For example, consider a posting to both elena ML and rudo (DM) from kenken.
#
#     From: kenken 
#     To: elena-ml
#     Cc: rudo
#
# The reply to this DM (direct message) from rudo is
#
#     From: rudo
#     To: elena-ml
#
# This reply message has no thread_id since the message from kenken to
# rudo comes directly from kenken not through fml driver.
# In this case, we try to speculdate the reply relation and the thread_id
# of this thread by using _speculate_thread_id_from_header().
#
sub _speculate_thread_id_from_header
{
    my ($self, $header) = @_;
    my $midlist = _extract_message_id_references( $header );
    my $result  = '';

    for (@$midlist) { $self->log("(debug) mid=$_");}

    if (defined $midlist) {
	$self->db_open();

	# prepare hash table tied to db_dir/*db's
	my $rh = $self->{ _hash_table };

	for my $mid (@$midlist) { 
	    $result = $rh->{ _message_id }->{ $mid };
	    last if $result;
	}

	$self->db_close();
    }

    $self->log("(debug) not speculated") unless $result;
    $result;
}


# Descriptions: 
#    Arguments: $self $args
# Side Effects: 
# Return Value: none
sub _make_thread_id_strings
{
    my ($self, $header, $id) = @_;
    my $config      = $self->{ _config };
    my $subject_tag = $config->{ thread_subject_tag };
    my $id_syntax   = $config->{ thread_id_syntax };

    # thread_id in subject
    my $thread_id = sprintf($subject_tag, $id);
    $self->{ _thread_subject_tag } = $thread_id;

    $thread_id = sprintf($id_syntax, $id);
    $self->set_thread_id($thread_id);

    return $thread_id;
}


# Descriptions: 
#    Arguments: $self $args
# Side Effects: 
# Return Value: none
sub _rewrite_header
{
    my ($self, $header, $id) = @_;

    # append the thread tag to the subject
    my $subject = $header->get('subject') || '';
    $header->replace('Subject', 
		     $subject." " . $self->{ _thread_subject_tag });
}


# Descriptions: clean up given C<address>.
#               It parse it by C<Mail::Address::parse()> and nuke < and >.
#    Arguments: $self $args
# Side Effects: 
# Return Value: none
sub _address_clean_up
{
    my ($self, $addr) = @_;

    use Mail::Address;
    my @addrlist = Mail::Address->parse($addr);

    # only the first element in the @addrlist array is effective.
    $addr = $addrlist[0]->address;
    $addr =~ s/^\s*<//;
    $addr =~ s/>\s*$//;

    # return the result.
    return $addr;
}


=head2 update_db($msg)

=cut


# Descriptions: 
#    Arguments: $self $args
# Side Effects: 
# Return Value: none
sub update_db
{
    my ($self, $msg) = @_;
    my $config  = $self->{ _config };
    my $ml_name = $config->{ ml_name };

    return if $self->{ _pragma } eq 'ignore';

    $self->db_open();

    # save $ticke_id et.al. in db_dir/$ml_name
    $self->_update_db($msg);

    # save cross reference pointers among $ml_name
    $self->_update_index_db();

    $self->db_close();
}


# Descriptions: 
#    Arguments: $self $args
# Side Effects: 
# Return Value: none
sub _update_db
{
    my ($self, $msg) = @_;
    my $config     = $self->{ _config };
    my $article_id = $config->{ article_id };
    my $thread_id  = $self->get_thread_id();
    
    # 0. logging
    $self->log("article_id=$article_id thread_id=$thread_id");

    # prepare hash table tied to db_dir/*db's
    my $rh = $self->{ _hash_table };

    # 1. 
    $rh->{ _thread_id }->{ $article_id }  = $thread_id;
    $rh->{ _date      }->{ $article_id }  = time;
    $rh->{ _articles  }->{ $thread_id  } .= $article_id . " ";

    # 2. record the sender information
    my $header = $msg->rfc822_message_header;
    $rh->{ _sender }->{ $article_id } = $header->get('from');

    # 3. update status information
    if (defined $self->{ _status }) {
	$self->_set_status($thread_id, $self->{ _status });
    }
    else {
	# set the default status value for the first time.
	unless (defined $rh->{ _status }->{ $thread_id }) {
	    $self->_set_status($thread_id, 'open');
	}
    }

    # 4. save optional/additional information
    #    message_id hash is { message_id => thread_id };
    my $mid = $header->get('message-id');
    $mid    = $self->_address_clean_up($mid);
    $rh->{ _message_id }->{ $mid } = $thread_id;

    # 5. history
    my $buf    = '';
    my (@aid)  = split(/\s+/, $rh->{ _articles  }->{ $thread_id });
    my $sender = $rh->{ _sender }->{ $aid[0] };
    my $when   = $rh->{ _date }->{ $aid[0] };

    # clean up
    $sender =~ s/[\s\n]*$//;
    $when   =~ s/[\s\n]*$//;

    use Mail::Message::Date;
    $when = Mail::Message::Date->new($when)->mail_header_style();
    
    $buf .= "\t\n";
    $buf .= "\tthis thread is opended at article $aid[0]\n";
    $buf .= "\tby $sender\n";
    $buf .= "\ton $when\n";
    $buf .= "\tarticle references: @aid\n";
    $self->{ _status_history } = $buf;
}


# Descriptions: register myself to index_db for further reference
#               among mailing lists
#    Arguments: $self $args
# Side Effects: 
# Return Value: none
sub _update_index_db
{
    my ($self) = @_;
    my $config    = $self->{ _config };
    my $thread_id = $self->get_thread_id();
    my $rh        = $self->{ _hash_table };
    my $ml_name   = $config->{ ml_name };

    my $ref = $rh->{ _index }->{ $thread_id } || '';
    if ($ref !~ /^$ml_name|\s$ml_name\s|$ml_name$/) {
	$rh->{ _index }->{ $thread_id } .= $ml_name." ";
    }
}


=head2 C<set_status($args)>

set $status for $thread_id. It rewrites DB (file).
C<$args>, HASH reference, must have two keys.

    $args = {
	thread_id => $thread_id,
	status    => $status,
    }

C<set_status()> calls db_open() an db_close() automatically within it.

=cut


# Descriptions: 
#    Arguments: $self $curproc $args
# Side Effects: 
# Return Value: none
sub set_status
{
    my ($self, $args) = @_;
    my $thread_id = $args->{ thread_id };
    my $status    = $args->{ status };

    $self->db_open();
    $self->_set_status($thread_id, $status);
    $self->db_close();
}


# Descriptions: 
#    Arguments: $self $args
# Side Effects: 
# Return Value: none
sub _set_status
{
    my ($self, $thread_id, $value) = @_;
    $self->{ _hash_table }->{ _status }->{ $thread_id } = $value;
}


=head1 AUTHOR

Ken'ichi Fukamachi

=head1 COPYRIGHT

Copyright (C) 2001 Ken'ichi Fukamachi

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself. 

=head1 HISTORY

Mail::ThreadTrack::Analyze appeared in fml5 mailing list driver package.
See C<http://www.fml.org/> for more details.

=cut


1;
