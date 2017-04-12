package RMS::WorkRules;

use Modern::Perl;
use Carp;
use DateTime;
use DateTime::Duration;

use Params::Validate qw(:all);

use RMS::Dates;
use RMS::WorkRules::DB;

use RMS::Logger;
my $l = bless({}, 'RMS::Logger');

=head1 SYNOPSIS

This module deals with calculating the proper working rules for the given day

=cut


=head2 getDayLengthDd

How many hours we need to work every day.

Day length changed 2017-02-01 to 7h 21min

@PARAM1 DateTime, the day to check for day duration
@PARAM2 $ignoreWeekend, always return the work day duration, even if the DateTime happens to be on a weekend

@RETURNS DateTime::Duration

=cut

my $dayLength20170201 = DateTime->new(year => 2017, month => 2, day => 1);
my $dayLength0715 = DateTime::Duration->new(hours => 7, minutes => 15);
my $dayLength0721 = DateTime::Duration->new(hours => 7, minutes => 21);
sub getDayLengthDd {
  my ($dt, $ignoreWeekend) = @_;

  #Day length is 0 if this is a weekend
  my $dow = $dt->day_of_week;
  if (not($ignoreWeekend) && ($dow == 6 || $dow == 7)) {
    $l->trace("Day length for '".$dt->ymd."' is 00:00 because it is weekend :)") if $l->is_trace();
    return RMS::Dates::zeroDuration();
  }

  if (DateTime->compare($dt, $dayLength20170201) < 1) { #Pre 2017-02-01
    $l->trace("Day length for '".$dt->ymd."' is '".RMS::Dates::formatDurationHMS($dayLength0715)."'") if $l->is_trace();
    return $dayLength0715;
  }
  else {
    $l->trace("Day length for '".$dt->ymd."' is '".RMS::Dates::formatDurationHMS($dayLength0721)."'") if $l->is_trace();
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

=head2 getVacationsFromPriorContracts

@PARAM1 Integer, userId
@RETURNS Integer, how many vacations are moved to this contract from the previous.

=cut

our @validGVFPC = (
  {type => SCALAR}, #userId
);
sub getVacationsFromPriorContracts {
  my ($userId) = validate_pos(@_, @validGVFPC);
  return $RMS::WorkRules::DB::vacationsFromPriorContracts{$userId};
}

=head2 getVacationAccumulationDuration

How many days/hours of vacations are "earned" every month?

@PARAM1 Integer, redmine.time_entries.user_id
@PARAM2 DateTime, for the given day
@RETURNS DateTime::Duration, Duration to add to the vacationAccumulation quota.

=cut

our @validGVAD = (
  {type => SCALAR}, #userId
  {isa => 'DateTime'}, #dayDt
);
sub getVacationAccumulationDuration {
  my ($userId, $dayDt) = validate_pos(@_, @validGVAD);
  my $dayLengthDd = getDayLengthDd($dayDt, 'ignoreWeekend');
  my $days = $RMS::WorkRules::DB::vacationAccumulationWorkdays{$userId};
  $l->trace("Getting new vacations for '".$dayDt->ymd."'. Workday length '".RMS::Dates::formatDurationHMS($dayLengthDd)."', vacation days '$days'") if $l->is_trace();
  return $dayLengthDd->clone->multiply($days);
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
