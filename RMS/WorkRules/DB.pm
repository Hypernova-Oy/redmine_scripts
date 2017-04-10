package RMS::WorkRules::DB;

use Modern::Perl;
use Carp;
use DateTime;
use DateTime::Duration;

=head1 SYNOPSIS

This module stores all the work rules in one compact location

=cut


=head2 userid to clear name mapping

Easily keep track of who a specific user_id actually is

=cut

our %userIdToName = (
    1 => 'kivilahtio',
    666 => 'testDude',
);
our %nameToUserId = (
    kivilahtio => 1,
    testDude => 666,
);

=head2 specialIssues

Marks some issue identifiers to have special purpose, like vacation, paid-leave, sick-leave, ...
Check that these map properly from your Redmine installation.

=cut

our %specialIssues = (
  vacationIssueId     => 9,
  paidLeaveIssueId    => 1618,
  nonPaidLeaveIssueId => 1514,
  careLeaveIssueId    => 1989,
  sickLeaveIssueId    => 622,
);
our %issuesSpecial = (
  9 => 'vacation',
  1618 => 'paidLeave',
  1514 => 'nonPaidLeave',
  1989 => 'careLeave',
  622 => 'sickLeave',
);
our %activitySpecial = (
  'Learning' => 'learning',
);



=head2 overwork thresholds

There are several different overwork thresholds:

-work done after 18:00 is considered evening work
-if daily workday duration exceeds the normal by two hours, any extra has a higher bonus

=cut

our $eveningWorkThreshold = DateTime::Duration->new(hours => 18);
our $dailyOverworkThreshold1 = DateTime::Duration->new(hours => 2);



=head2 vacation rules

-Some of us have extra vacations from previous contracts
-We accumulate vacations on a different pace depending on work experience
-Vacations are unavailable for use during the beginning of the month, and are "activated" later during the month

=cut

our $vacationAccumulationDayOfMonth = 15;
our %vacationsFromPriorContracts = (
    $nameToUserId{'kivilahtio'} => 24,
    $nameToUserId{'testDude'} => 12,
);
our $vacationAccumulationDuration = DateTime::Duration->new(days => 2);

1;
