#!/usr/bin/perl

use Modern::Perl;
use Test::More;
use Test::MockModule;

use RMS::Worklogs;
use RMS::WorkRules;


my $sickLeave = $RMS::WorkRules::specialIssues->{sickLeaveIssueId};
my $vacation  = $RMS::WorkRules::specialIssues->{vacationIssueId};
my $paidLeave = $RMS::WorkRules::specialIssues->{paidLeaveIssueId};
my $learning  = 'Learning';

subtest "overworkAccumulation", \&overworkAccumulation;
sub overworkAccumulation {
    eval {
    my $module = Test::MockModule->new('RMS::Worklogs');
    $module->mock('getWorklogs', sub {
        my @wls = (
            #Wednesday is a long day. Get some overwork accumulation for the next month's report
            {spent_on => '2017-03-29', created_on => '2017-03-29 17:45:00', hours => 10.75},
            #Thursday is a long day. Get some overwork accumulation for the next month's report
            {spent_on => '2017-03-30', created_on => '2017-03-30 17:45:00', hours => 10.75},
            #Friday is a long day. 5h of overwork paid today, subtracted from the accumulated overwork total
            {spent_on => '2017-03-31', created_on => '2017-03-31 17:45:00', hours => 10.75, comments => '{{PAID 05:00 @bossman}}. Bossman paid me overwork for 5 hours.'},
            ####  Month changes to April  ####
            #Saturday
            #
            #Sunday
            #
            #A regular monday, got sick midway
            {spent_on => '2017-04-03', created_on => '2017-04-03 10:30:00', hours => 2.5},
            {spent_on => '2017-04-03', created_on => '2017-04-03 11:30:00', hours => 0.75, activity => $learning},
            {spent_on => '2017-04-03', created_on => '2017-04-03 15:30:00', hours => 4.1,  issue_id => $sickLeave},
            #Tuesday, still sick
            {spent_on => '2017-04-04', created_on => '2015-04-04 09:00:00', hours => 7.35, issue_id => $sickLeave},
            #Wednesday, getting better, working from home a bit
            {spent_on => '2017-04-05', created_on => '2017-04-05 09:15:00', hours => 2.35, comments => '{{REMOTE}}. This and that.'},
            {spent_on => '2017-04-05', created_on => '2017-04-05 09:30:00', hours => 5.00, issue_id => $sickLeave},
            #Thursday, normal day at office
            {spent_on => '2017-04-06', created_on => '2017-04-06 11:30:00', hours => 3},
            {spent_on => '2017-04-06', created_on => '2017-04-06 15:45:00', hours => 4},
            {spent_on => '2017-04-06', created_on => '2017-04-06 17:45:00', hours => 2},
            #Friday yippee!
            {spent_on => '2017-04-07', created_on => '2017-04-07 17:45:00', hours => 7.35},
            #Need to work on saturday :( but I get benefits :)
            {spent_on => '2017-04-08', created_on => '2017-04-08 16:45:00', hours => 7.35, comments => '{{BENEFITS}}. Doing some super important stuff.'},
            #Answering some email on sunday. Shouldn't get benefits since no overwork order.
            {spent_on => '2017-04-09', created_on => '2017-04-09 10:00:00', hours => 1},
            #Not working on monday for some reason. No worklog entries. This empty gap should be filled with a blank day when exporting reports.
            #
            #Tuesday is normal.
            {spent_on => '2017-04-11', created_on => '2017-04-11 16:30:00', hours => 7.5,  activity => $learning},
            #Wednesday is normal.
            {spent_on => '2017-04-12', created_on => '2017-04-12 16:45:00', hours => 7.5},
            #Thursday is remote working day
            {spent_on => '2017-04-13', created_on => '2017-04-13 19:00:00', hours => 8,    comments => '{{REMOTE}}. This and that again.'},
            #Friday is a vacation!
            {spent_on => '2017-04-14', created_on => '2017-03-01 12:00:00', hours => 7.35, issue_id => $vacation},
            #Saturday
            #
            #Sunday
            #
            #Monday is a vacation!
            {spent_on => '2017-04-17', created_on => '2017-03-01 12:00:00', hours => 7.35, issue_id => $vacation},
            #Tuesday is a vacation!
            {spent_on => '2017-04-18', created_on => '2017-03-01 12:00:00', hours => 7.35, issue_id => $vacation},
            #Wednesday is a paid leave! Hooray for religion!
            {spent_on => '2017-04-19', created_on => '2017-03-20 12:00:00', hours => 7.35, issue_id => $paidLeave},
            #Thursday is a vacation!
            {spent_on => '2017-04-20', created_on => '2017-03-01 12:00:00', hours => 7.35, issue_id => $vacation},
            #Friday is a vacation!
            {spent_on => '2017-04-21', created_on => '2017-03-01 12:00:00', hours => 7.35, issue_id => $vacation},
            #Saturday
            #
            #Sunday
            #
            #Monday. Special emergency today, had to work late.
            {spent_on => '2017-04-24', created_on => '2017-04-24 13:45:00', hours => 6.75},
            {spent_on => '2017-04-24', created_on => '2017-04-24 17:55:00', hours => 4.00, comments => '{{BENEFITS}}. Something broke and had to fix it.'},
            #Tuesday is normal.
            {spent_on => '2017-04-25', created_on => '2017-04-25 16:30:00', hours => 7.5},
            #Wednesday is normal.
            {spent_on => '2017-04-26', created_on => '2017-04-26 16:45:00', hours => 7.5},
            #Thursday is normal.
            {spent_on => '2017-04-27', created_on => '2017-04-27 16:30:00', hours => 7.5},
            #Friday is a remote day.
            {spent_on => '2017-04-28', created_on => '2017-04-28 16:00:00', hours => 7.25, comments => '{{REMOTE}}'},
            #Need to work on saturday :( but I get benefits :)
            {spent_on => '2017-04-29', created_on => '2017-04-29 15:00:00', hours => 7.00, comments => '{{BENEFITS}}'},
            {spent_on => '2017-04-29', created_on => '2017-04-29 19:05:00', hours => 4.00},
            {spent_on => '2017-04-29', created_on => '2017-04-29 21:10:00', hours => 2.00},
            #Sunday
            #
            #### Change of month to May ####
            #Monday is normal.
            {spent_on => '2017-05-01', created_on => '2017-05-01 16:30:00', hours => 7.5},
            #Tuesday is normal.
            {spent_on => '2017-05-02', created_on => '2017-05-02 16:45:00', hours => 7.5},
            #Wednesday is normal.
            {spent_on => '2017-05-03', created_on => '2017-05-03 16:30:00', hours => 7.5},
        );
        _worklogDefault(\@wls, {issue_id => 9999, activity => '', user_id => 1});
        return \@wls;
    });

    my $workedDays = RMS::Worklogs->new({user => 1})->asDays();
    my @k = sort keys %$workedDays;
    is(scalar(@k), 28, "28 days worked");
    my $days = RMS::Worklogs::Exporter->fillMissingDays($workedDays);
    @k = sort keys %$days;
    is(scalar(@k), 36, "36 days in total, including non-worked days");

    is(RMS::Dates::formatDurationHMS( $days->{'2017-03-29'}->overworkAccumulation() ), '03:24:00', '03-29 overwork accumulated');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-03-30'}->overworkAccumulation() ), '06:48:00', '03-30 overwork accumulated');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-03-31'}->overworkAccumulation() ), '05:12:00', '03-31 overwork partially reimbursed');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-04-01'}->overworkAccumulation() ), '05:12:00', '04-01 empty day, overwork unchanged');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-04-02'}->overworkAccumulation() ), '05:12:00', '04-02 empty day, overwork unchanged');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-04-03'}->overworkAccumulation() ), '05:12:00', '04-03 overwork remains the same');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-04-04'}->overworkAccumulation() ), '05:12:00', '04-04 overwork remains the same');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-04-05'}->overworkAccumulation() ), '05:12:00', '04-05 overwork remains the same');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-04-06'}->overworkAccumulation() ), '06:51:00', '04-06 overwork accumulated');

    is(RMS::Dates::formatDurationHMS( $days->{'2017-04-03'}->duration() ),             '07:21:00', '04-03 learning a bit, but workday duration is as expected');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-04-03'}->learning() ),             '00:45:00', '04-03 learning a bit');

    is(RMS::Dates::formatDurationHMS( $days->{'2017-04-03'}->duration() ),             '07:21:00', '04-03 sick leave partially, but workday duration is as expected');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-04-03'}->sickLeave() ),            '04:06:00', '04-03 sick leave partially');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-04-04'}->duration() ),             '07:21:00', '04-04 sick leave completely and workday duration is as expected');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-04-04'}->sickLeave() ),            '07:21:00', '04-04 sick leave completely');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-04-05'}->duration() ),             '07:21:00', '04-05 sick leave partially, but workday duration is as expected');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-04-05'}->sickLeave() ),            '05:00:00', '04-05 sick leave partially');

    $days = RMS::Worklogs->new({user => 1})->asOds('/tmp/workTime.ods');
    ok($days, '.ods generated');
#    `rm /tmp/workTime.ods`;
    };
    ok(0, $@) if $@;
}


done_testing();


=head2 _worklogDefault

Inject default keys to a bunch of time_entry-rows

=cut

sub _worklogDefault {
    my ($wls, $defaults) = @_;
    foreach my $wl (@$wls) { #Append defaults for each time_entry
        foreach my $key (keys %$defaults) {
            $wl->{$key} = $defaults->{$key} unless $wl->{$key};
        }
    }
}