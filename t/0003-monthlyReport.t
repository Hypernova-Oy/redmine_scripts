#!/usr/bin/perl

use Modern::Perl;
use Test::More;
use Test::MockModule;

use ODF::lpOD;

use RMS::Worklogs;
use RMS::WorkRules;

use t::lib::Helps;
use t::lib::Mocks;


my $moduleRMSUsers = Test::MockModule->new('RMS::Users');
$moduleRMSUsers->mock('getUser', \&t::lib::Mocks::RMS_Users_getUser);


my $sickLeave = $RMS::WorkRules::DB::specialIssues{sickLeaveIssueId};
my $vacation  = $RMS::WorkRules::DB::specialIssues{vacationIssueId};
my $paidLeave = $RMS::WorkRules::DB::specialIssues{paidLeaveIssueId};
my $learning  = 'Learning';
my $testDude  = $RMS::WorkRules::DB::nameToUserId{'testDude'};
my $tmpExportFile = '/tmp/workTime';

subtest "overworkAccumulation", \&overworkAccumulation;
sub overworkAccumulation {
    eval {
    my $module = Test::MockModule->new('RMS::Worklogs');
    $module->mock('getWorklogs', sub {
        my @wls = (
            #We are only interested in 2017, so drop any time_entries outside 2017. However overwork and vacations are accumulated from the previous year!
            {spent_on => '2016-12-30', created_on => '2016-12-30 13:45:00', hours => 6.5},

            #Tuesday. Print something for January to test that the month begins correctly in the _data_-layer
            {spent_on => '2017-01-03', created_on => '2017-01-03 17:45:00', hours => 8},
            #Sunday 2017-01-15 should get new vacations to spend! These are added to the vacations quota.
            #
            #January encumbers a lot of negative overwork due to missing days

            ####  Month changes to February  ####
            #February encumbers a lot of negative overwork due to missing days
            #Wednesday 2017-02-15 should get new vacations to spend! These are added to the vacations quota.
            #
            #Sunday is a long day. Get a lot of overwork accumulation since all work is overwork
            {spent_on => '2017-02-26', created_on => '2017-02-26 17:45:00', hours => 3.5},
            #Monday is a long day. Get some overwork accumulation for the next month's report
            {spent_on => '2017-02-27', created_on => '2017-02-27 17:45:00', hours => 10.75},
            #Tuesday is a long day. MAde a deal with the boss and negative overwork is forgiven :)
            {spent_on => '2017-02-28', created_on => '2017-02-28 17:45:00', hours => 10.75, comments => '{{PAID -274:09 @bossman}}. Bossman forgave my underwork.'},

            ####  Month changes to March  ####
            #Saturday
            #
            #Sunday
            #
            #A regular wednesday, got sick midway
            {spent_on => '2017-03-01', created_on => '2017-03-01 10:30:00', hours => 2.5},
            {spent_on => '2017-03-01', created_on => '2017-03-01 11:30:00', hours => 0.75, activity => $learning},
            {spent_on => '2017-03-01', created_on => '2017-03-01 15:30:00', hours => 4.1,  issue_id => $sickLeave},
            #Thursday, still sick
            {spent_on => '2017-03-02', created_on => '2015-03-02 09:00:00', hours => 7.35, issue_id => $sickLeave},
            #Friday, getting better, working from home a bit
            {spent_on => '2017-03-03', created_on => '2017-03-03 09:15:00', hours => 2.35, comments => '{{REMOTE}}. This and that.'},
            {spent_on => '2017-03-03', created_on => '2017-03-03 09:30:00', hours => 5.00, issue_id => $sickLeave},
            #Need to work on saturday :( but I get benefits :)
            {spent_on => '2017-03-04', created_on => '2017-03-04 16:45:00', hours => 7.35, comments => '{{BENEFITS}}. Doing some super important stuff.'},
            #Answering some email on sunday. Shouldn't get benefits since no overwork order.
            {spent_on => '2017-03-05', created_on => '2017-03-05 10:00:00', hours => 1},
            #Not working on monday for some reason. No worklog entries. This empty gap should be filled with a blank day when exporting reports. A lot of negative overwork.
            #
            #Tuesday is normal.
            {spent_on => '2017-03-07', created_on => '2017-03-07 16:30:00', hours => 7.5,  activity => $learning},
            #Wednesday is normal.
            {spent_on => '2017-03-08', created_on => '2017-03-08 16:45:00', hours => 7.5},
            #Thursday is remote working day
            {spent_on => '2017-03-09', created_on => '2017-03-09 19:00:00', hours => 8,    comments => '{{REMOTE}}. This and that again.'},
            #Friday is a vacation!
            {spent_on => '2017-03-10', created_on => '2017-02-10 12:00:00', hours => 7.35, issue_id => $vacation},
            #Saturday
            #
            #Sunday
            #
            #Monday is a vacation!
            {spent_on => '2017-03-13', created_on => '2017-02-01 12:00:00', hours => 7.35, issue_id => $vacation},
            #Tuesday is a vacation!
            {spent_on => '2017-03-14', created_on => '2017-02-01 12:00:00', hours => 7.35, issue_id => $vacation},
            #Wednesday is a paid leave! Hooray for religion! Monthly vacation allowance should accumulate today
            {spent_on => '2017-03-15', created_on => '2017-02-20 12:00:00', hours => 7.35, issue_id => $paidLeave},
            #Thursday is a vacation!
            {spent_on => '2017-03-16', created_on => '2017-02-01 12:00:00', hours => 7.35, issue_id => $vacation},
            #Friday is a vacation!
            {spent_on => '2017-03-17', created_on => '2017-02-01 12:00:00', hours => 7.35, issue_id => $vacation},
            #Saturday
            #
            #Sunday
            #
            #Monday. Special emergency today, had to work late.
            {spent_on => '2017-03-20', created_on => '2017-03-20 13:45:00', hours => 6.75},
            {spent_on => '2017-03-20', created_on => '2017-03-20 17:55:00', hours => 4.00, comments => '{{BENEFITS}}. Something broke and had to fix it.'},
            #Tuesday is normal.
            {spent_on => '2017-03-21', created_on => '2017-03-21 16:30:00', hours => 7.5},
            #Wednesday is normal.
            {spent_on => '2017-03-22', created_on => '2017-03-22 16:45:00', hours => 7.5},
            #Thursday is normal.
            {spent_on => '2017-03-23', created_on => '2017-03-23 16:30:00', hours => 7.5},
            #Friday is a remote day.
            {spent_on => '2017-03-24', created_on => '2017-03-24 16:00:00', hours => 7.25, comments => '{{REMOTE}}'},
            #Need to work on saturday :( but I get benefits :)
            {spent_on => '2017-03-25', created_on => '2017-03-25 15:00:00', hours => 7.00, comments => '{{BENEFITS}}'},
            {spent_on => '2017-03-25', created_on => '2017-03-25 19:05:00', hours => 4.00},
            {spent_on => '2017-03-25', created_on => '2017-03-25 21:10:00', hours => 2.00},
            #Sunday
            #
            #Monday
            #
            #Tuesday
            #
            #Wednesday
            #
            #Thursday
            #
            #Friday
            # #Didn't show up in 5 days !! yikes, this will get you fired.
            #### Change of month to May ####
            #Saturday
            #
            #Sunday
            #
            #Monday is normal.
            {spent_on => '2017-04-03', created_on => '2017-04-03 16:30:00', hours => 7.5},
            #Tuesday is normal.
            {spent_on => '2017-04-04', created_on => '2017-04-04 16:45:00', hours => 7.5},
            #Wednesday is normal.
            {spent_on => '2017-04-05', created_on => '2017-04-05 16:30:00', hours => 7.5},
        );
        t::lib::Helps::worklogDefault(\@wls, {issue_id => 9999, activity => '', user_id => $testDude});
        return \@wls;
    });

    my $worklogger = RMS::Worklogs->new({user => 'testDude', year => 2017});
    my $workedDailies = $worklogger->_flattenDays($worklogger->worklogs);
    my @k = sort keys %$workedDailies;
    is(scalar(@k), 28, "28 days worked");
    my $days = $worklogger->asDays();
    @k = sort keys %$days;
    is(scalar(@k), 97, "97 days in total, including non-worked days");

    is(RMS::Dates::formatDurationPHMS( $days->{'2016-12-30'}->overworkAccumulation() ), '-00:45:00',  '12-30 overwork accumulated from previous year');
    is(RMS::Dates::formatDurationPHMS( $days->{'2017-01-01'}->overworkAccumulation() ), '-00:45:00',  '01-01 overwork unchanged due to weekend');
    is(RMS::Dates::formatDurationPHMS( $days->{'2017-01-02'}->overworkAccumulation() ), '-08:00:00',  '01-02 overwork lost due to not working');
    is(RMS::Dates::formatDurationPHMS( $days->{'2017-01-03'}->overworkAccumulation() ), '-07:15:00',  '01-03 overwork accumulated');
    is(RMS::Dates::formatDurationPHMS( $days->{'2017-01-31'}->overworkAccumulation() ), '-152:15:00', '01-31 overwork quota sunk a lot due to not working the whole month :(');
    is(RMS::Dates::formatDurationPHMS( $days->{'2017-02-25'}->overworkAccumulation() ), '-284:27:00', '02-25 overwork quota sunk a lot due to not working the whole month :(');
    is(RMS::Dates::formatDurationPHMS( $days->{'2017-02-26'}->overworkAccumulation() ), '-280:57:00', '02-26 overwork accumulated');
    is(RMS::Dates::formatDurationPHMS( $days->{'2017-02-27'}->overworkAccumulation() ), '-277:33:00', '02-27 overwork accumulated');
    is(RMS::Dates::formatDurationPHMS( $days->{'2017-02-28'}->overworkAccumulation() ), '+00:00:00',  '02-28 overwork negatively reimbursed');
    is(RMS::Dates::formatDurationPHMS( $days->{'2017-03-01'}->overworkAccumulation() ), '+00:00:00',  '03-01 overwork unchanged');
    is(RMS::Dates::formatDurationPHMS( $days->{'2017-03-02'}->overworkAccumulation() ), '+00:00:00',  '03-02 overwork unchanged');
    is(RMS::Dates::formatDurationPHMS( $days->{'2017-03-03'}->overworkAccumulation() ), '+00:00:00',  '03-03 overwork unchanged');
    is(RMS::Dates::formatDurationPHMS( $days->{'2017-03-04'}->overworkAccumulation() ), '+07:21:00',  '03-04 overwork from a full saturday');
    is(RMS::Dates::formatDurationPHMS( $days->{'2017-03-05'}->overworkAccumulation() ), '+08:21:00',  '03-05 overwork from reading email on sunday');
    is(RMS::Dates::formatDurationPHMS( $days->{'2017-03-06'}->overworkAccumulation() ), '+01:00:00',  '03-06 overwork lost due to not working');
    is(RMS::Dates::formatDurationPHMS( $days->{'2017-03-07'}->overworkAccumulation() ), '+01:09:00',  '03-07 overwork accumulated');

    ##TODO:: user testDude has 12 vacations from a prior work contract
    is(RMS::Dates::formatDurationHMS( $days->{'2016-12-30'}->vacationAccumulation() ), '87:00:00',  '12-30 prior contract vacations retained');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-01-14'}->vacationAccumulation() ), '87:00:00',  '01-14 day before vacations accumulate');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-01-15'}->vacationAccumulation() ), '101:30:00', '01-15 vacations accumulate');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-01-16'}->vacationAccumulation() ), '101:30:00', '01-16 vacations accumulated');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-02-14'}->vacationAccumulation() ), '101:30:00', '02-14 day before vacations accumulate');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-02-15'}->vacationAccumulation() ), '116:12:00', '02-15 vacations accumulate');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-02-16'}->vacationAccumulation() ), '116:12:00', '02-16 vacations accumulated');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-03-10'}->vacationAccumulation() ), '108:51:00', '03-10 vacation used');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-03-13'}->vacationAccumulation() ), '101:30:00', '03-13 vacation used');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-03-14'}->vacationAccumulation() ), '94:09:00',  '03-14 vacation used');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-03-15'}->vacationAccumulation() ), '108:51:00', '03-15 vacations accumulate');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-03-16'}->vacationAccumulation() ), '101:30:00', '03-16 vacation used');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-03-17'}->vacationAccumulation() ), '94:09:00',  '03-17 vacation used');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-04-03'}->vacationAccumulation() ), '94:09:00',  '04-03 vacations remain unaltered');

    is(RMS::Dates::formatDurationHMS( $days->{'2017-03-01'}->duration() ),             '07:21:00', '03-01 learning a bit, but workday duration is as expected');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-03-01'}->learning() ),             '00:45:00', '03-01 learning a bit');

    is(RMS::Dates::formatDurationHMS( $days->{'2017-03-01'}->duration() ),             '07:21:00', '03-01 sick leave partially, but workday duration is as expected');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-03-01'}->sickLeave() ),            '04:06:00', '03-01 sick leave partially');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-03-02'}->duration() ),             '07:21:00', '03-02 sick leave completely and workday duration is as expected');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-03-02'}->sickLeave() ),            '07:21:00', '03-02 sick leave completely');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-03-03'}->duration() ),             '07:21:00', '03-03 sick leave partially, but workday duration is as expected');
    is(RMS::Dates::formatDurationHMS( $days->{'2017-03-03'}->sickLeave() ),            '05:00:00', '03-03 sick leave partially');

    $days = $worklogger->asOds($tmpExportFile);
    ok($days, '.ods generated');

    subtest ".ods contents", sub {
        my $doc = odf_document->get( $tmpExportFile.'.ods' );
        ok($doc, "Given the .ods document");
        my $t = $doc->get_body->get_table_by_name('_data_');
        ok($t, "Given the _data_-sheet");

        my $frontPage = $doc->get_body->get_table_by_name('Etusivu');
        ok($frontPage,                                                "Given the _data_-sheet");
        is($frontPage->get_cell(0,3)->get_text(), 2017,               "Front page year");
        is($frontPage->get_cell(2,2)->get_text(), 'Dude, TestDude',   "Front page user names");
        is($frontPage->get_cell(3,2)->get_text(), 'testDude',         "Front page login");
        is($frontPage->get_cell(4,2)->get_text(), 'test@example.com', "Front page email");

        my $headerRow = $t->get_row(0);
        ok($headerRow,                                          "Given 2017-01 header row");
        is($headerRow->get_cell(0)->get_text(),  'day',        '2017-01 header day');
        is($headerRow->get_cell(21)->get_text(), 'comments',   '2017-01 header comments');
        is($headerRow->get_cell(22),              undef,        '2017-01 headers length as expected');

        my $row20170101 = $t->get_row(1);
        ok($row20170101,                                                   "Given 2017-01-01 day row");
        is($row20170101->get_cell(0)->get_value(),  '2017-01-01T00:00:00', '2017-01-01 ymd');
        is($row20170101->get_cell(1)->get_value(),  'PT00H00M00S',         '2017-01-01 start');

        my $row20170103 = $t->get_row(3);
        ok($row20170103,                                                   "Given 2017-01-03 day row");
        is($row20170103->get_cell( 0)->get_value(),  '2017-01-03T00:00:00', '2017-01-03 ymd');
        is($row20170103->get_cell( 1)->get_value(),  'PT09H45M00S',         '2017-01-03 start');
        is($row20170103->get_cell( 2)->get_value(),  'PT17H45M00S',         '2017-01-03 end');
        is($row20170103->get_cell( 3)->get_value(),  'PT00H00M00S',         '2017-01-03 break');
        is($row20170103->get_cell( 4)->get_value(),  'PT00H45M00S',         '2017-01-03 overwork');
        is($row20170103->get_cell( 5)->get_value(),  'PT08H00M00S',         '2017-01-03 duration');

        my $row20170301 = $t->get_row(81);
        ok($row20170301,                                                   "Given 2017-03-01 day row");
        is($row20170301->get_cell( 0)->get_value(),  '2017-03-01T00:00:00', '2017-03-01 ymd');
        is($row20170301->get_cell( 1)->get_value(),  'PT08H00M00S',         '2017-03-01 start');
        is($row20170301->get_cell( 2)->get_value(),  'PT15H30M00S',         '2017-03-01 end');
        is($row20170301->get_cell( 3)->get_value(),  'PT00H09M00S',         '2017-03-01 break');
        is($row20170301->get_cell( 4)->get_value(),  'PT00H00M00S',         '2017-03-01 overwork');
        is($row20170301->get_cell( 5)->get_value(),  'PT07H21M00S',         '2017-03-01 duration');
    };
#    `rm /tmp/workTime.ods`;
    };
    ok(0, $@) if $@;
}


done_testing();


