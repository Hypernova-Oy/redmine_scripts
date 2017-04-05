use Modern::Perl;
use utf8;
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

package RMS::Logger;

use Carp qw(longmess);
use autodie;
$Carp::Verbose = 'true'; #die with stack trace
use Scalar::Util qw(blessed);

# Copyright (C) 2017 Koha-Suomi
#
# This file is part of redmine_scripts.

use Data::Dumper;

use Log::Log4perl;
our @ISA = qw(Log::Log4perl);
Log::Log4perl->wrapper_register(__PACKAGE__);

sub AUTOLOAD {
  my $l = shift;
  my $method = our $AUTOLOAD;
  $method =~ s/.*://;
  return $l->$method(@_) if $method eq 'DESTROY';
  unless (blessed($l)) {
    longmess "RMS::Logger invoked with an unblessed reference??";
  }
  unless ($l->{_log}) {
    _init();
    $l->{_log} = Log::Log4perl->get_logger();
  }
  return $l->{_log}->$method(@_);
}

sub DESTROY {}

=head2 flatten

    my $string = $logger->flatten(@_);

Given a bunch of $@%, the subroutine flattens those objects to a single human-readable string.

@PARAMS Anything, concatenates parameters to one flat string

=cut

sub flatten {
  my $self = shift;
  die __PACKAGE__."->flatten() invoked improperly. Invoke it with \$logger->flatten(\@params)" unless ((blessed($self) && $self->isa(__PACKAGE__)) || ($self eq __PACKAGE__));
  $Data::Dumper::Indent = 0;
  $Data::Dumper::Terse = 1;
  $Data::Dumper::Quotekeys = 0;
  $Data::Dumper::Maxdepth = 2;
  $Data::Dumper::Sortkeys = 1;
  return Data::Dumper::Dumper(\@_);
}

sub _init {
  if(Log::Log4perl->initialized()) {
    # Yes, Log::Log4perl has already been initialized
  } else {
    my $confFile;
    if (-e 'config/log4perl.conf') {
      $confFile = 'config/log4perl.conf';
    } elsif (-e '../config/log4perl.conf') {
      $confFile = '../config/log4perl.conf'
    } else {
      die "Cannot find 'log4perl.conf' configuration file";
    }
    Log::Log4perl->init($confFile);
  }
}

1;
