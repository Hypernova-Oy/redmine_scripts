package RMS::WorkRules;

use Modern::Perl;
use Carp;
use DateTime;
use DateTime::Duration;

use Params::Validate qw(:all);

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

our $specialIssues = {
  vacationIssueId     => 9,
  paidLeaveIssueId    => 1618,
  nonPaidLeaveIssueId => 1514,
  careLeaveIssueId    => 622,
  sickLeaveIssueId    => 622,
};
our $issuesSpecial = {
  9 => 'vacation',
  1618 => 'paidLeave',
  1514 => 'nonPaidLeave',
  622 => 'careLeave',
  622 => 'sickLeave',
};
our $activitySpecial = {
  'Learning' => 'learning',
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

my $dailyOverworkThreshold1 = DateTime::Duration->new(hours => 2);
sub getDailyOverworkThreshold1 {
  return $dailyOverworkThreshold1;
}

my $eveningWorkThreshold = DateTime::Duration->new(hours => 18);
sub getEveningWorkThreshold {
  return $eveningWorkThreshold;
}

sub getVacationAccumulationDayOfMonth {
  return 15;
}

=head2 getVacationAccumulationDuration

How many days/hours of vacations are "earned" every month?

@PARAM1 Integer, redmine.time_entries.user_id
@PARAM2 DateTime, for the given day
@RETURNS DateTime::Duration, Duration to add to the vacationAccumulation quota.

=cut

my $vacationAccumulationDuration = DateTime::Duration->new(days => 2);
our @validGVAD = (
  {type => SCALAR}, #userId
  {isa => 'DateTime::Duration'}, #dayDt
);
sub getVacationAccumulationDuration {
  my ($userId, $dayDt) = validate(@_, @validGVAD);
  #TODO!
  return $vacationAccumulationDuration;
}

=head2 getSpecialWorkCategory

Checks the $issue/$activity -tables if the given $issueId matches a special issue, for ex. Vacations, Sick-Leave, etc.
Or if the given activity is something special, like learning, that needs to be categorized separately.

@PARAM1 Integer, redmine.time_entries.issue_id
@PARAM2 Integer, redmine.time_entries.activity
@RETURNS String, special category if applicable

=cut

sub getSpecialWorkCategory {
  my ($issueId, $activity) = @_;
  return $issuesSpecial->{$issueId} if $issuesSpecial->{$issueId};
  return $activitySpecial->{$activity} = $activitySpecial->{$activity};
}



1;
