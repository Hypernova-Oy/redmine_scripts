package RMS::WorkRules;

use Modern::Perl;
use Carp;
use DateTime;
use DateTime::Duration;

=head1 SYNOPSIS

This module deals with calculating the proper working rules for the given day

=cut

sub new {
  my ($class, $params) = @_;

  my $self = {params => $params};
  bless($self, $class);
  return $self;
}

=head2 getDayLength

  my $float = $wr->getDayLength($dateTime);

How many hours we need to work every day.
@RETURNS Float, Eg. 7.35 #base 100 instead of 60

=cut

my $dayLength20170201 = DateTime->new(year => 2017, month => 2, day => 1);
my $dayLength0715 = DateTime::Duration->new(hours => 7, minutes => 15);
my $dayLength0721 = DateTime::Duration->new(hours => 7, minutes => 21);
sub getDayLength {
  my ($self, $dt) = @_;

  if (DateTime->compare($dt, $dayLength20170201) < 1) { #Pre 2017-02-01
    return 7.25;
  }
  else {
    return 7.35;
  }
}

=head2 getDayLengthDt

@RETURNS DateTime::Duration

=cut

sub getDayLengthDt {
  my ($self, $dt) = @_;

  if (DateTime->compare($dt, $dayLength20170201) < 1) { #Pre 2017-02-01
    return $dayLength0715;
  }
  else {
    return $dayLength0721;
  }
}

1;
