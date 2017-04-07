package RMS::WorkRules;

use Modern::Perl;
use Carp;
use DateTime;
use DateTime::Duration;

use Params::Validate qw(:all);

use RMS::WorkRules::DB;

=head1 SYNOPSIS

This module deals with calculating the proper working rules for the given day

=cut


=head2 getDayLengthDt

  my $duration = $wr->getDayLengthDt($dateTime);

How many hours we need to work every day.

Day length changed 2017-02-01 to 7h 21min

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

sub getDailyOverworkThreshold1 {
  return $RMS::WorkRules::DB::dailyOverworkThreshold1;
}

sub getEveningWorkThreshold {
  return $RMS::WorkRules::DB::eveningWorkThreshold;
}

sub getVacationAccumulationDayOfMonth {
  return $RMS::WorkRules::DB::vacationAccumulationDayOfMonth;
}

=head2 getVacationAccumulationDuration

How many days/hours of vacations are "earned" every month?

@PARAM1 Integer, redmine.time_entries.user_id
@PARAM2 DateTime, for the given day
@RETURNS DateTime::Duration, Duration to add to the vacationAccumulation quota.

=cut

our @validGVAD = (
  {type => SCALAR}, #userId
  {isa => 'DateTime::Duration'}, #dayDt
);
sub getVacationAccumulationDuration {
  my ($userId, $dayDt) = validate(@_, @validGVAD);
  #TODO!
  return $RMS::WorkRules::DB::vacationAccumulationDuration;
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
  return $RMS::WorkRules::DB::issuesSpecial{$issueId} if $RMS::WorkRules::DB::issuesSpecial{$issueId};
  return $RMS::WorkRules::DB::activitySpecial{$activity} = $RMS::WorkRules::DB::activitySpecial{$activity};
}



1;
