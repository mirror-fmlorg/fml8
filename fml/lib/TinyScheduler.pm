#-*- perl -*-
#
#  Copyright (C) 2001 Ken'ichi Fukamachi
#   All rights reserved. This program is free software; you can
#   redistribute it and/or modify it under the same terms as Perl itself. 
#
# $FML: TinyScheduler.pm,v 1.7 2001/06/28 09:06:43 fukachan Exp $
#

package TinyScheduler;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $AUTOLOAD);
use Carp;

=head1 NAME

TinyScheduler - what is this

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 C<new()>

=cut

# $args == parameters from CGI.pm  if fmlsci.cgi uses.
# $args == libexec/loaders's $args if fmlsch uses.
sub new
{
    my ($self, $args) = @_;
    my ($type)  = ref($self) || $self;
    my $me      = {};

    # fmlsch.cgi options
    my $user      = $args->{ user }      || $ENV{'USER'};

    # fmlsch options
    my $options   = $args->{ options };

    # directory
    use User::pwent;
    my $pw        = getpwnam($user);
    my $home_dir  = $pw->dir;
    my $dir       = $options->{'D'} || "$home_dir/.tsch";

    # ~/.schedule/ by default
    $me->{ _user }          = $user;
    $me->{ _schedule_dir }  = $dir;
    $me->{ _schedule_file } = $options->{'F'} || '';

    # attribute
    $me->{ _mode } = $options->{ 'm' } || 'text';

    return bless $me, $type;
}


sub tmpfile
{
    my ($self, $args) = @_;
    my $user = $self->{ _user };
    my $dir  = $self->{ _schedule_dir };
    my $tmpdir;

    if (-w $dir) {
	$tmpdir = $dir;
    }
    else {
	croak("Hmm, unsafe ? I cannot write $dir, stop\n");
    }

    use File::Spec;
    $self->{ _tmpfile } = File::Spec->catfile($tmpdir,"$$.html");
    return $self->{ _tmpfile };
}


=head2 C<parse($args)>

=cut

sub parse
{
    my ($self, $args) = @_;
    my ($sec,$min,$hour,$mday,$month,$year,$wday) = localtime(time);

    # get the date to show
    $year  = $args->{ year }  || (1900 + $year);
    $month = $args->{ month } || ($month + 1);

    # schedule file
    my $data_dir  = $self->{ _schedule_dir };
    my $data_file = $self->{ _schedule_file };

    # pattern to match
    my @pat = (
	       sprintf("^%04d%02d(\\d{1,2})\\s+(.*)",  $year, $month),
	       sprintf("^%04d/%02d/(\\d{1,2})\\s+(.*)", $year, $month),
	       sprintf("^%04d/%d/(\\d{1,2})\\s+(.*)", $year, $month),
	       sprintf("^%02d(\\d{1,2})\\s+(.*)",  $month),
	       sprintf("^%02d/(\\d{1,2})\\s+(.*)", $month),
	       );

    # 
    use HTML::CalendarMonthSimple;

    my $cal = new HTML::CalendarMonthSimple('year'=> $year, 'month'=> $month);

    if (defined $cal) {
	$self->{ _schedule } = $cal;
    }
    else {
	croak("cannot get object");
    }

    $cal->width('70%');
    $cal->border(10);
    $cal->header(sprintf("%04d/%02d %s",  $year, $month, "schedule"));
    $cal->bgcolor('pink');

    if ($data_file && -f $data_file) {
	$self->_analyze($data_file, \@pat);
    }
    elsif (-d $data_dir) {
	use DirHandle;
	my $dh = new DirHandle $data_dir;

	if (defined $dh) {
	    while (defined($_ = $dh->read)) {
		next if $_ =~ /~$/;
		$self->_analyze("$data_dir/$_", \@pat);
	    }
	}
    }
    else {
	croak("invalid data");
    }
}


sub _analyze
{
    my ($self, $file, $pattern) = @_;

    use FileHandle;
    my $fh = new FileHandle $file;

    if (defined $fh) {
	while (<$fh>) {
	    for my $pat (@$pattern) {
		if (/$pat(.*)/) {
		    $self->_parse($1, $2);
		}
	    }

	    # for example, "*/24 something"
	    if (/^\*\/(\d+)\s+(.*)/) {
		$self->_parse($1, $2);
	    }
	}
	close($fh);
    }
}


sub _parse
{
    my ($self, $day, $buf) = @_;
    my $cal = $self->{ _schedule };
    $day =~ s/^0//;
    $cal->addcontent($day, "<p>". $buf);
}


=head2 C<print($fd)>

print out the result as HTML.
You can specify the output channel by C<$fd>.

=cut


sub print
{
    my ($self, $fd) = @_;
    $fd = $fd || \*STDOUT;
    print $fd $self->{ _schedule }->as_HTML;
}


=head2 C<print_specific_month($fh, $n)>

print range specified by C<$n>.
C<$n> is one of C<this>, C<next> and C<last>.   

=cut

sub print_specific_month
{
    my ($self, $fh, $n) = @_;
    my ($sec,$min,$hour,$mday,$month,$year,$wday) = localtime(time);
    my $thismonth = $month + 1;
    $thismonth++ if $n eq 'next';
    $thismonth-- if $n eq 'last';

    print $fh "<A NAME=\"$n\">\n";
    $self->parse( { month => $thismonth } );
    $self->print($fh);
}


if ($0 eq __FILE__) {
    eval q{
	my %options;

	use Getopt::Long;
	GetOptions(\%options, "e! -D=s -m=s");

	require FileHandle; import FileHandle;
	require TinyScheduler; import TinyScheduler;
	my $schedule = new TinyScheduler;

	if ($options{'e'}) {
	    my $editor = $ENV{'EDITOR'} || 'mule';
	    system $editor, '-nw', $schedule->{ _schedule_file };
	}

	$schedule->parse;

	my $tmp = $schedule->tmpfile;
	my $fh  = new FileHandle $tmp, "w";
	$schedule->print($fh);
	$fh->close;
	
	system "w3m -dump $tmp";

	unlink $tmp;
    };
    croak($@) if $@;
}


=head1 AUTHOR

Ken'chi Fukamachi

=head1 COPYRIGHT

Copyright (C) 2001 Ken'chi Fukamachi

All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself. 

=head1 HISTORY

TinyScheduler appeared in fml5 mailing list driver package.
See C<http://www.fml.org/> for more details.

=cut


1;