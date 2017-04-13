#!/usr/bin/perl

use Modern::Perl;
use utf8;
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
binmode(STDIN, ":utf8");

use Test::More;
use Test::MockModule;

use Text::CSV;
use DateTime;
use DateTime::Duration;
use DateTime::Format::MySQL;
use DateTime::Format::Duration;

use RMS::Dates;
use RMS::Worklogs;

use t::lib::Helps;
use t::lib::Mocks;


my $moduleRMSUsers = Test::MockModule->new('RMS::Users');
$moduleRMSUsers->mock('getUser', \&t::lib::Mocks::RMS_Users_getUser);


my $tmpWorklogFile = '/tmp/workTime';

subtest "fillMissingYMDs", \&fillMissingYMDs;
sub fillMissingYMDs {
    my $ymds = [
        '2016-05-01',
        '2016-05-02',
        '2016-05-04',
        '2016-05-08',
        '2016-05-09',
        '2016-05-11',
    ];
    $ymds = RMS::Worklogs::Exporter->fillMissingYMDs($ymds);
    is(scalar(@$ymds), 11, '11 days');

    my $i=0;
    foreach my $ymd (qw(2016-05-01 2016-05-02 2016-05-03 2016-05-04 2016-05-05 2016-05-06 2016-05-07 2016-05-08 2016-05-09 2016-05-10 2016-05-11)) {
        is($ymds->[$i++], $ymd, $ymd);
    }
}

subtest "fillMissingTimeEntries", \&fillMissingTimeEntries;
sub fillMissingTimeEntries {
    my $worklogs = [
        {spent_on => '2015-12-31', created_on => '2015-12-31 08:00:00', hours => 7.25, comments => '', issue_id => 101, user_id => 1, activity => 'Learning'},
        {spent_on => '2016-01-02', created_on => '2016-01-02 08:00:00', hours => 7.25, comments => '', issue_id => 101, user_id => 1, activity => 'Learning'},
        {spent_on => '2016-01-03', created_on => '2016-01-03 08:00:00', hours => 7.25, comments => '', issue_id => 101, user_id => 1, activity => 'Learning'},
        {spent_on => '2016-02-04', created_on => '2016-02-04 08:00:00', hours => 7.25, comments => '', issue_id => 101, user_id => 1, activity => 'Learning'},
        {spent_on => '2016-02-06', created_on => '2016-02-06 08:30:00', hours => 0.5,  comments => '', issue_id => 101, user_id => 1, activity => 'Learning'},
        {spent_on => '2016-02-06', created_on => '2016-02-06 12:00:00', hours => 3.5,  comments => '', issue_id => 101, user_id => 1, activity => 'Learning'},
        {spent_on => '2016-02-06', created_on => '2016-02-06 16:00:00', hours => 3.5,  comments => '', issue_id => 101, user_id => 1, activity => 'Learning'},
    ];
    $worklogs = RMS::Worklogs::fillMissingTimeEntries($worklogs);

    testTimeEntry('2015-12-31', $worklogs->[0],  '2015-12-31', '2015-12-31 08:00:00', 7.25, '', 101, 1, 'Learning');
    testTimeEntry('2016-01-01', $worklogs->[1],  '2016-01-01', '2016-01-01 00:00:00', 0,    '', 0,   1, '');
    testTimeEntry('2016-01-02', $worklogs->[2],  '2016-01-02', '2016-01-02 08:00:00', 7.25, '', 101, 1, 'Learning');
    testTimeEntry('2016-01-03', $worklogs->[3],  '2016-01-03', '2016-01-03 08:00:00', 7.25, '', 101, 1, 'Learning');
    testTimeEntry('2016-01-04', $worklogs->[4],  '2016-01-04', '2016-01-04 00:00:00', 0,    '', 0  , 1, '');
    testTimeEntry('2016-01-05', $worklogs->[5],  '2016-01-05', '2016-01-05 00:00:00', 0,    '', 0  , 1, '');
    #...
    testTimeEntry('2016-02-03', $worklogs->[34], '2016-02-03', '2016-02-03 00:00:00', 0,    '', 0  , 1, '');
    testTimeEntry('2016-02-04', $worklogs->[35], '2016-02-04', '2016-02-04 08:00:00', 7.25, '', 101, 1, 'Learning');
    testTimeEntry('2016-02-05', $worklogs->[36], '2016-02-05', '2016-02-05 00:00:00', 0,    '', 0,   1, '');
    testTimeEntry('2016-02-06', $worklogs->[37], '2016-02-06', '2016-02-06 08:30:00', 0.5,  '', 101, 1, 'Learning');
    testTimeEntry('2016-02-06', $worklogs->[38], '2016-02-06', '2016-02-06 12:00:00', 3.5,  '', 101, 1, 'Learning');
    testTimeEntry('2016-02-06', $worklogs->[39], '2016-02-06', '2016-02-06 16:00:00', 3.5,  '', 101, 1, 'Learning');
    testTimeEntry('2016-02-07', $worklogs->[40], undef,        undef,                 undef,undef,undef,undef,undef);
}

subtest "hoursToDuration", \&hoursToDuration;
sub hoursToDuration {
    my $testSub = sub {
        my ($dd, $phms, $testName) = @_;
        is(RMS::Dates::formatDurationPHMS(RMS::Dates::hoursToDuration($dd)), $phms, $phms || $testName);
    };
    &$testSub('1',         '+01:00:00');
    &$testSub('22',        '+22:00:00');
    &$testSub('1.5',       '+01:30:00');
    &$testSub('1.25',      '+01:15:00');
    &$testSub('1.375',     '+01:22:30');
    &$testSub('0.0025',    '+00:00:09');
    &$testSub('1.00033',   '+01:00:02');
    &$testSub('0.0000001', '+00:00:01', '1e-07');
    &$testSub('0.0025',    '+00:00:09');
    &$testSub('1.00033',   '+01:00:02');
}

subtest "guessStartTime", \&guessStartTime;
sub guessStartTime {
    my $testSub = sub {
        my ($ymd, $worklogs, $expectedStartIso, $testName) = @_;
        my $st = RMS::Worklogs::Day->guessStartTime($ymd, $worklogs);
        $st = $st->iso8601() if $st;
        is($st, $expectedStartIso, $testName || $expectedStartIso);
    };

    my @wls = (
        {created_on => '2015-06-11 10:34:29', hours => 0.5},
        {created_on => '2015-06-11 11:26:06', hours => 0.75},
        {created_on => '2015-06-11 11:28:11', hours => 0.25},
        {created_on => '2015-06-11 18:10:37', hours => 3},
        {created_on => '2015-06-11 18:14:16', hours => 1},
    );
    &$testSub('2015-06-11', \@wls, '2015-06-11T10:04:29', 'No start time collaction');

    @wls = (
        {created_on => '2015-06-11 10:34:29', hours => 0.5},
        {created_on => '2015-06-11 10:36:06', hours => 0.75},
        {created_on => '2015-06-11 10:40:11', hours => 0.25},
        {created_on => '2015-06-11 10:50:12', hours => 3}, #This time_entry is barely (1 second) outside the first work-event collation threshold of 10 minutes
        {created_on => '2015-06-11 18:11:59', hours => 2},
    );
    &$testSub('2015-06-11', \@wls, '2015-06-11T09:04:29', 'Start time collaction');

    @wls = (
        {created_on => '2015-06-10 08:00:00', hours => 0.5},
        {created_on => '2015-06-11 10:36:06', hours => 0.75},
        {created_on => '2015-06-11 10:40:11', hours => 0.25},
        {created_on => '2015-06-11 10:50:12', hours => 3}, #This time_entry is barely (1 second) outside the first work-event collation threshold of 10 minutes
        {created_on => '2015-06-11 18:11:59', hours => 2},
    );
    &$testSub('2015-06-11', \@wls, '2015-06-11T09:36:06', 'First created_on-timestamp is for a wrong day? This time_entry is removed from the work-event collation');

    @wls = (
        {created_on => '2015-06-10 08:00:00', hours => 7.25},
        {created_on => '2015-06-12 10:36:06', hours => 2},
    );
    &$testSub('2015-06-11', \@wls, undef, 'No valid created_on-timestamps available. Return undef.');
}

subtest "_verifyStartTime", \&_verifyStartTime;
sub _verifyStartTime {
    my $_verifyStartTimeTest = sub {
        eval {
            my ($day, $expected, $start, $duration, $expectedUnderflow) = @_;
            my ($h, $m) = $duration =~ /(\d+)/g;

            my ($expectedDt, $stDt, $underflowDuration);
            $expectedDt = DateTime::Format::MySQL->parse_datetime( "$day $expected" );
            ($stDt, $underflowDuration) = RMS::Worklogs::Day->_verifyStartTime(
                            $day,
                            ($start) ? DateTime::Format::MySQL->parse_datetime( "$start" ) : undef,
                            DateTime::Duration->new(hours => $h, minutes => $m),
            );

            is($stDt->iso8601(), $expectedDt->iso8601(), ($start || 'undef   ')." => $expected using $duration");
            is(RMS::Dates::formatDurationHMS($underflowDuration), $expectedUnderflow, 'Got the expected start time underflow');
        };
        if ($@) {
            ok(0, $@);
        }
    };

    &$_verifyStartTimeTest('2016-05-20', '07:45:00', '2016-05-20 07:45:00', '08:00', '00:00:00');
    &$_verifyStartTimeTest('2016-05-20', '03:45:00', '2016-05-20 03:45:00', '20:15', '00:00:00');
    &$_verifyStartTimeTest('2016-05-20', '03:44:59', '2016-05-20 07:45:00', '20:15', '04:00:00');
    &$_verifyStartTimeTest('2016-05-20', '03:44:59', undef,                 '20:15', '04:15:00');
    &$_verifyStartTimeTest('2016-05-20', '00:00:00', '2016-05-19 23:30:00', '20:15', '00:00:00');
}

subtest "_verifyEndTime", \&_verifyEndTime;
sub _verifyEndTime {
    my $_verifyEndTimeTest = sub {
        eval {
            my ($expected, $start, $end, $duration, $expectedOverflow) = @_;
            my ($h, $m) = $duration =~ /(\d+)/g;

            my ($day, $expectedDt, $stDt, $endDt, $overflow);
            $day = '2016-05-20';
            $expectedDt = DateTime::Format::MySQL->parse_datetime( "$day $expected" );
            ($endDt, $overflow) = RMS::Worklogs::Day->_verifyEndTime(
                            $day,
                            DateTime::Format::MySQL->parse_datetime( "$day $start" ),
                            ($end) ? DateTime::Format::MySQL->parse_datetime( "$day $end" ) : undef,
                            DateTime::Duration->new(hours => $h, minutes => $m),
            );

            is($endDt->iso8601(), $expectedDt->iso8601(), ($end || 'undef   ')." => $expected using $duration");
            is(RMS::Dates::formatDurationHMS($overflow), $expectedOverflow, 'Got the expected end time overflow');
        };
        if ($@) {
            ok(0, $@);
        }
    };

    &$_verifyEndTimeTest('16:45:00', '07:45:00', '16:45:00', '08:00', '00:00:00');
    &$_verifyEndTimeTest('15:45:00', '07:45:00', undef     , '08:00', '00:00:00');
    &$_verifyEndTimeTest('17:45:00', '07:45:00', '10:00:00', '10:00', '07:45:00');
}

subtest "_verifyBreaks", \&_verifyBreaks;
sub _verifyBreaks {
    my $_verifyBreaksTest = sub {
        eval {
            my ($expected, $start, $end, $duration) = @_;
            my ($dH, $dM, $dS) = $duration =~ /(\d+)/g;
            my ($eH, $eM, $eS) = $expected =~ /(\d+)/g;

            my ($day, $expectedDuration, $stDt, $breaks);
            $day = '2016-05-20';
            $expectedDuration = DateTime::Duration->new(hours => $eH, minutes => $eM, seconds => $eS || 0);
            $breaks = RMS::Worklogs::Day->_verifyBreaks(
                            $day,
                            DateTime::Format::MySQL->parse_datetime( "$day $start" ),
                            ($end) ? DateTime::Format::MySQL->parse_datetime( "$day $end" ) : undef,
                            DateTime::Duration->new(hours => $dH, minutes => $dM, seconds => $dS || 0),
            );

            is(RMS::Dates::formatDurationPHMS($breaks), RMS::Dates::formatDurationPHMS($expectedDuration), "$start - $end using $duration => $expected");
        };
        if ($@) {
            ok(0, $@);
        }
    };

    &$_verifyBreaksTest('01:00', '07:45:00', '16:45:00', '08:00');
    &$_verifyBreaksTest('10:30', '03:45:00', '22:15:00', '08:00');
    &$_verifyBreaksTest('00:00', '03:45:12', '05:45:12', '02:00');
    &$_verifyBreaksTest('00:00', '08:14:36', '19:36:48', '11:22:12');
}

subtest "simpleDailyLogging", \&simpleDaily;
sub simpleDaily {
    my $module = Test::MockModule->new('RMS::Worklogs');
    $module->mock('getWorklogs', sub {
        my @wls = (
            {spent_on => '2016-05-20', created_on => '2016-05-20 11:05:17', hours => 1.5},
            {spent_on => '2016-05-20', created_on => '2016-05-20 11:08:29', hours => 0.5},
            {spent_on => '2016-05-20', created_on => '2016-05-20 11:09:06', hours => 0.25},
            {spent_on => '2016-05-20', created_on => '2016-05-20 11:51:26', hours => 0.5},
            {spent_on => '2016-05-20', created_on => '2016-05-20 11:52:18', hours => 0.25},
            {spent_on => '2016-05-20', created_on => '2016-05-20 16:29:21', hours => 3.5},
        );
        t::lib::Helps::worklogDefault(\@wls, {issue_id => 9999, activity => '', user_id => 666});
        return \@wls;
    });

    my $days = RMS::Worklogs->new({user => 'testDude'})->asDays();
    my @k = sort keys %$days;
    is(scalar(keys(%$days)), 1, "1 days");

    #      ($yms,  $day,           $startIso,             $endIso,         $durationPHMS, $breaksPHMS, $overworkPHMS, $dailyOverwork1, $overflowPHMS, $benefits, $remote, $comments)
    testDay($k[0], $days->{$k[0]}, '2016-05-20T08:50:17', '2016-05-20T16:29:21', '+06:30:00', '+01:09:04', '-00:45:00', '+00:00:00', '+00:00:00', undef, undef, '');
}

subtest "advancedDailyLogging", \&advancedDaily;
sub advancedDaily {
    my $module = Test::MockModule->new('RMS::Worklogs');
    $module->mock('getWorklogs', sub {
        my @wls = (
            {spent_on => '2015-07-12', created_on => '2015-07-12 10:34:29', hours => 0.5, comments => "\x{1F911}🤑 This day had a problem with exponentially small 'hours'"},
            {spent_on => '2015-07-12', created_on => '2015-07-12 11:26:06', hours => 0.75,},
            {spent_on => '2015-07-12', created_on => '2015-07-12 11:28:11', hours => 0.25,},
            {spent_on => '2015-07-12', created_on => '2015-07-12 18:10:37', hours => 3,},
            {spent_on => '2015-07-12', created_on => '2015-07-12 18:11:59', hours => 2,},
            {spent_on => '2015-07-12', created_on => '2015-07-12 18:13:46', hours => 2,},
            {spent_on => '2015-07-12', created_on => '2015-07-12 18:14:16', hours => 0.0000001,},

            {spent_on => '2015-07-13', created_on => '2015-07-13 08:54:38', hours => 0.5,},
            {spent_on => '2015-07-13', created_on => '2015-07-13 08:55:45', hours => 0.25,},
            {spent_on => '2015-07-13', created_on => '2015-07-13 09:50:08', hours => 1,},
            {spent_on => '2015-07-13', created_on => '2015-07-13 13:38:01', hours => 1,},
            {spent_on => '2015-07-13', created_on => '2015-07-13 13:41:22', hours => 0.25,},
            {spent_on => '2015-07-13', created_on => '2015-07-13 13:43:10', hours => 2.5,},
            {spent_on => '2015-07-13', created_on => '2015-07-13 14:25:20', hours => 0.25,},
            {spent_on => '2015-07-13', created_on => '2015-07-13 14:36:43', hours => 0.25,},
            {spent_on => '2015-07-13', created_on => '2015-07-13 15:48:20', hours => 1,},
            {spent_on => '2015-07-13', created_on => '2015-07-13 15:48:51', hours => 0.25,},
            {spent_on => '2015-07-13', created_on => '2015-07-13 18:04:17', hours => 0.25,},
            {spent_on => '2015-07-13', created_on => '2015-07-13 18:05:28', hours => 2,},
            {spent_on => '2015-07-13', created_on => '2015-07-13 18:48:14', hours => 0.75,},

            {spent_on => '2015-07-14', created_on => '2015-07-14 11:59:36', hours => 0.375, comments => "\x{1F602}😂 This day had a strange bug in 'breaks'-calculus"},
            {spent_on => '2015-07-14', created_on => '2015-07-14 12:00:00', hours => 0.37,},
            {spent_on => '2015-07-14', created_on => '2015-07-14 16:59:43', hours => 0.25,},
            {spent_on => '2015-07-14', created_on => '2015-07-14 17:03:12', hours => 4,},
            {spent_on => '2015-07-14', created_on => '2015-07-14 17:03:20', hours => 1,},
            {spent_on => '2015-07-14', created_on => '2015-07-14 17:24:45', hours => 0.25,},
            {spent_on => '2015-07-14', created_on => '2015-07-14 18:56:10', hours => 1,},
            {spent_on => '2015-07-14', created_on => '2015-07-14 18:57:50', hours => 0.75,},

            {spent_on => '2015-07-15', created_on => '2015-07-15 23:34:42', hours => 2, comments => "ÅÄÖ Bugfix where these days yield strange hours"},
            {spent_on => '2015-07-15', created_on => '2015-07-15 23:35:07', hours => 3,},
            {spent_on => '2015-07-15', created_on => '2015-07-15 23:35:25', hours => 2.25, comments => "end time - start time = -15:00"},
            {spent_on => '2015-07-16', created_on => '2015-07-16 00:20:48', hours => 0.75, comments => "end time - start time = 00:00"},
            {spent_on => '2015-07-16', created_on => '2015-07-16 15:29:40', hours => 4,},
            {spent_on => '2015-07-16', created_on => '2015-07-16 16:02:33', hours => 0.5,},
            {spent_on => '2015-07-16', created_on => '2015-07-16 16:34:53', hours => 0.6,},
            {spent_on => '2015-07-16', created_on => '2015-07-16 18:25:28', hours => 1.75,},
            {spent_on => '2015-07-16', created_on => '2015-07-16 18:26:02', hours => 0.2,},
            {spent_on => '2015-07-16', created_on => '2015-07-16 19:30:00', hours => 0.95,},
            {spent_on => '2015-07-16', created_on => '2015-07-16 19:36:21', hours => 0.25,},

            {spent_on => '2015-07-17', created_on => '2015-07-17 11:05:17', hours => 10.5, comments => "Dangerous unsyncronized worklog entries"},
            {spent_on => '2015-07-17', created_on => '2015-07-17 11:08:29', hours => 0.5,},
            {spent_on => '2015-07-17', created_on => '2015-07-17 11:09:06', hours => 0.25,},
            {spent_on => '2015-07-17', created_on => '2015-07-17 11:51:26', hours => 0.5,},
            {spent_on => '2015-07-17', created_on => '2015-07-17 11:52:18', hours => 0.25,},
            {spent_on => '2015-07-17', created_on => '2015-07-17 15:29:21', hours => 3.5,},

            {spent_on => '2015-07-18', created_on => '2015-07-18 11:08:29', hours => 0.5, comments => "Dangerous unsyncronized worklog entries fixed days later"},
            {spent_on => '2015-07-18', created_on => '2015-07-18 11:09:06', hours => 0.25, comments => "2015-07-18 is a saturday and all work done should be treated as overwork."},
            {spent_on => '2015-07-18', created_on => '2015-07-18 11:51:26', hours => 0.5,},
            {spent_on => '2015-07-18', created_on => '2015-07-18 11:52:18', hours => 0.25,},
            {spent_on => '2015-07-18', created_on => '2015-07-22 15:29:21', hours => 3.5,},
            {spent_on => '2015-07-18', created_on => '2015-07-23 11:00:00', hours => 10.5,},

            {spent_on => '2015-07-20', created_on => '2015-07-20 17:49:45', hours => 5, comments => "Bug: Negative break duration?"},
            {spent_on => '2015-07-20', created_on => '2015-07-20 17:59:55', hours => 0.666,},
            {spent_on => '2015-07-20', created_on => '2015-07-20 18:06:25', hours => 0.25,},
        );
        t::lib::Helps::worklogDefault(\@wls, {issue_id => 9999, activity => '', user_id => 666});
        return \@wls;
    });

    my $days = RMS::Worklogs->new({user => 'testDude'})->asDays();
    my @k = sort keys %$days;
    is(scalar(@k), 9, "9 days");

    #      ($yms,  $day,           $startIso,             $endIso,       $durationPHMS, $breaksPHMS, $overworkPHMS, $dailyOverwork1, $overflowPHMS, $benefits, $remote, $comments)
    testDay($k[0], $days->{$k[0]}, '2015-07-12T10:04:29', '2015-07-12T18:34:30', '+08:30:01', '+00:00:00', '+08:30:01', '+02:00:00', '+00:20:14',   undef,     undef,   '!END overflow 00:20:14!🤑🤑 This day had a problem with exponentially small \'hours\'');
    testDay($k[1], $days->{$k[1]}, '2015-07-13T08:09:38', '2015-07-13T18:48:14', '+10:15:00', '+00:23:36', '+03:00:00', '+02:00:00', '+00:00:00',   undef,     undef,   '');
    testDay($k[2], $days->{$k[2]}, '2015-07-14T11:14:54', '2015-07-14T19:14:36', '+07:59:42', '+00:00:00', '+00:44:42', '+00:44:42', '+00:16:46',   undef,     undef,   '!END overflow 00:16:46!😂😂 This day had a strange bug in \'breaks\'-calculus');
    testDay($k[3], $days->{$k[3]}, '2015-07-15T16:19:42', '2015-07-15T23:35:25', '+07:15:00', '+00:00:43', '+00:00:00', '+00:00:00', '+00:00:00',   undef,     undef,   "ÅÄÖ Bugfix where these days yield strange hours end time - start time = -15:00");
    testDay($k[4], $days->{$k[4]}, '2015-07-16T00:00:00', '2015-07-16T19:36:21', '+09:00:00', '+10:36:21', '+01:45:00', '+01:45:00', '+00:00:00',   undef,     undef,   "end time - start time = 00:00");
    testDay($k[5], $days->{$k[5]}, '2015-07-17T00:00:00', '2015-07-17T15:30:00', '+15:30:00', '+00:00:00', '+08:15:00', '+02:00:00', '+00:00:39',   undef,     undef,   '!END overflow 00:00:39!Dangerous unsyncronized worklog entries');
    testDay($k[6], $days->{$k[6]}, '2015-07-18T08:29:59', '2015-07-18T23:59:59', '+15:30:00', '+00:00:00', '+15:30:00', '+02:00:00', '+00:00:00',   undef,     undef,   '!START underflow 01:53:29!Dangerous unsyncronized worklog entries fixed days later 2015-07-18 is a saturday and all work done should be treated as overwork.');
    testDay($k[7], $days->{$k[7]}, '2015-07-19T00:00:00', '2015-07-19T00:00:00', '+00:00:00', '+00:00:00', '+00:00:00', '+00:00:00', '+00:00:00',   undef,     undef,   '');
    testDay($k[8], $days->{$k[8]}, '2015-07-20T12:49:45', '2015-07-20T18:44:43', '+05:54:58', '+00:00:00', '-01:20:02', '+00:00:00', '+00:38:18',   undef,     undef,   '!END overflow 00:38:18!Bug: Negative break duration?');
}

subtest "simpleCsvExport", \&simpleCsvExport;
sub simpleCsvExport {
    my ($days, $csv, $fh, $row);

    eval {
    my $module = Test::MockModule->new('RMS::Worklogs');
    $module->mock('getWorklogs', sub {
        my @wls = (
            {spent_on => '2016-05-20', created_on => '2016-05-20 12:00:00', hours => 2},
            {spent_on => '2016-05-23', created_on => '2016-05-23 12:00:00', hours => 2},
            {spent_on => '2016-05-24', created_on => '2016-05-24 12:00:00', hours => 2},
            {spent_on => '2016-05-26', created_on => '2016-05-26 12:00:00', hours => 2},
        );
        t::lib::Helps::worklogDefault(\@wls, {issue_id => 9999, activity => '', user_id => 666});
        return \@wls;
    });

    t::lib::Helps::runPerlScript('scripts/getWorkTime.pl', ['--user', 'testDude', '--file', $tmpWorklogFile, '--type', 'csv', '--year', 2016]);

    $csv = Text::CSV->new({binary => 1}) or die "Cannot use CSV: ".Text::CSV->error_diag ();
    open($fh, "<:encoding(utf8)", $tmpWorklogFile.'.csv') or die "$tmpWorklogFile.csv: $!";

    $row = $csv->getline( $fh );
    is($row->[0], '2016-05-20',          "1st day");
    is($row->[1], '10:00:00',            "1st start");
    is($row->[2], '12:00:00',            "1st end");
    is($row->[3], '+00:00:00',           "1st breaks");
    is($row->[4], '+02:00:00',           "1st duration");
    is($row->[5], '-05:15:00',           "1st overwork");
    $row = $csv->getline( $fh );
    is($row->[0], '2016-05-21',          '2nd day filled');
    is($row->[1], '00:00:00',            "2nd start empty");
    is($row->[2], '00:00:00',            "2nd end empty");
    is($row->[3], '+00:00:00',           "2nd breaks empty");
    is($row->[4], '+00:00:00',           "2nd duration empty");
    is($row->[5], '+00:00:00',           "2nd overwork empty");
    $row = $csv->getline( $fh );
    is($row->[0], '2016-05-22',          '3rd day filled');
    is($row->[1], '00:00:00',            "3rd start empty");
    $row = $csv->getline( $fh );
    is($row->[0], '2016-05-23',          '4th day');
    is($row->[1], '10:00:00',            "4th start");
    $row = $csv->getline( $fh );
    is($row->[0], '2016-05-24',          '5th day');
    is($row->[1], '10:00:00',            "5th start");
    $row = $csv->getline( $fh );
    is($row->[0], '2016-05-25',          '6th day filled');
    is($row->[1], '00:00:00',            "6th start empty");
    $row = $csv->getline( $fh );
    is($row->[0], '2016-05-26',          '7th day');
    is($row->[1], '10:00:00',            "7th start");

    close($fh);
    unlink("$tmpWorklogFile.csv");
    };
    ok(0, $@) if $@;
}

subtest "simpleOdsExport", \&simpleOdsExport;
sub simpleOdsExport {
    my $module = Test::MockModule->new('RMS::Worklogs');
    $module->mock('getWorklogs', sub {
        my @wls = (
            {spent_on => '2016-05-20', created_on => '2016-05-20 12:00:00', hours => 2, issue_id => 9999, activity => ''},
            {spent_on => '2016-05-23', created_on => '2016-05-23 12:00:00', hours => 2, issue_id => 9999, activity => ''},
            {spent_on => '2016-05-24', created_on => '2016-05-24 12:00:00', hours => 2, issue_id => 9999, activity => ''},
            {spent_on => '2016-05-26', created_on => '2016-05-26 12:00:00', hours => 2, issue_id => 9999, activity => ''},
        );
        t::lib::Helps::worklogDefault(\@wls, {issue_id => 9999, activity => '', user_id => 666});
        return \@wls;
    });
    my ($days, $csv, $fh, $row);

    $days = RMS::Worklogs->new({user => 'testDude', year => 2016})->asOds($tmpWorklogFile);
    ok($days);
    unlink("$tmpWorklogFile.ods");
}

done_testing();


sub testDay {
    my ($yms, $day, $startIso, $endIso, $durationPHMS, $breaksPHMS, $overworkPHMS, $dailyOverwork1, $overflowPHMS, $benefits, $remote, $comments) = @_;
    is($day->day(),              $yms,          $yms);
    is($day->start()->iso8601(), $startIso, "$yms start");
    is($day->end()->iso8601(),   $endIso,   "$yms end");
    is(RMS::Dates::formatDurationPHMS($day->duration()), $durationPHMS, "$yms duration");
    is(RMS::Dates::formatDurationPHMS($day->breaks()),   $breaksPHMS,   "$yms breaks");
    is(RMS::Dates::formatDurationPHMS($day->overwork()), $overworkPHMS, "$yms overwork");
    is(RMS::Dates::formatDurationPHMS($day->dailyOverwork1()), $dailyOverwork1, "$yms overwork");
    is(RMS::Dates::formatDurationPHMS($day->overflow()), $overflowPHMS, "$yms overflow");
    is($day->benefits, $benefits, "$yms benefits");
    is($day->remote,   $remote,   "$yms remote");
    is($day->comments, $comments, "$yms comments");
}

sub testTimeEntry {
    my ($ymd, $timeEntry, $spent_on, $created_on, $hours, $comments, $issue_id, $user_id, $activity) = @_;
    is(($timeEntry ? $timeEntry->{spent_on}   : undef), $spent_on,   "$ymd spent_on");
    is(($timeEntry ? $timeEntry->{created_on} : undef), $created_on, "$ymd created_on");
    is(($timeEntry ? $timeEntry->{hours}      : undef), $hours,      "$ymd hours");
    is(($timeEntry ? $timeEntry->{comments}   : undef), $comments,   "$ymd comments");
    is(($timeEntry ? $timeEntry->{issue_id}   : undef), $issue_id,   "$ymd issue_id");
    is(($timeEntry ? $timeEntry->{user_id}    : undef), $user_id,    "$ymd user_id");
    is(($timeEntry ? $timeEntry->{activity}   : undef), $activity,   "$ymd activity");
}
