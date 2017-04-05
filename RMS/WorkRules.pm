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

=head2 specialIssues

Marks some issue identifiers to have special purpose, like vacation, paid-leave, sick-leave, ...
Check these from your Redmine installation.

=cut

my $specialIssues = {
  vacationIssueId     => 9,
  paidLeaveIssueId    => 1618,
  nonPaidLeaveIssueId => 1514,
  sickLeaveIssueId    => 622,
};

=head2 getDayLengthDt

  my $duration = $wr->getDayLengthDt($dateTime);

How many hours we need to work every day.
@RETURNS DateTime::Duration

=cut

my $dayLength20170201 = DateTime->new(year => 2017, month => 2, day => 1);
my $dayLength0715 = DateTime::Duration->new(hours => 7, minutes => 15);
my $dayLength0721 = DateTime::Duration->new(hours => 7, minutes => 21);
sub getDayLengthDt {
  my ($self, $dt) = @_;

  if (DateTime->compare($dt, $dayLength20170201) < 1) { #Pre 2017-02-01
    return $dayLength0715;
  }
  else {
    return $dayLength0721;
  }
}

=head2 isVacation

  if ($wr->isVacation($issueId || 101)) {
    #do stuff
  }

=cut

sub isVacation {
  shift;
  return 1 if $specialIssues->{vacationIssueId} == shift;
}

1;
