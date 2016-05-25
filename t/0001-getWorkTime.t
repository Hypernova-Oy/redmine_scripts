#!/usr/bin/perl

use Modern::Perl;
use Test::More;
use Test::MockModule;

use Text::CSV;
use DateTime;
use DateTime::Duration;
use DateTime::Format::MySQL;
use DateTime::Format::Duration;
my $dtF_hms = DateTime::Format::Duration->new(
                    pattern => '%p%H:%M:%S',
                    normalise => 'ISO',
                    base => DateTime->now(),
                );

use RMS::Worklogs;

subtest "_fillMissingDays", \&_fillMissingDays;
sub _fillMissingDays {
    my $ymds = [
        '2016-05-01',
        '2016-05-02',
        '2016-05-04',
        '2016-05-08',
        '2016-05-09',
        '2016-05-11',
    ];
    $ymds = RMS::Worklogs->_fillMissingDays($ymds);
    is(scalar(@$ymds), 11, '11 days');

    my $i=0;
    foreach my $ymd (qw(2016-05-01 2016-05-02 2016-05-03 2016-05-04 2016-05-05 2016-05-06 2016-05-07 2016-05-08 2016-05-09 2016-05-10 2016-05-11)) {
        is($ymds->[$i++], $ymd, $ymd);
    }
}

subtest "_hoursToDuration", \&_hoursToDuration;
sub _hoursToDuration {
    is($dtF_hms->format_duration(RMS::Worklogs::_hoursToDuration('1')),       '+01:00:00', '+01:00:00');
    is($dtF_hms->format_duration(RMS::Worklogs::_hoursToDuration('22')),      '+22:00:00', '+22:00:00');
    is($dtF_hms->format_duration(RMS::Worklogs::_hoursToDuration('1.5')),     '+01:30:00', '+01:30:00');
    is($dtF_hms->format_duration(RMS::Worklogs::_hoursToDuration('1.25')),    '+01:15:00', '+01:15:00');
    is($dtF_hms->format_duration(RMS::Worklogs::_hoursToDuration('1.375')),   '+01:22:30', '+01:22:30');
    is($dtF_hms->format_duration(RMS::Worklogs::_hoursToDuration('0.0025')),  '+00:00:09', '+00:00:09');
    is($dtF_hms->format_duration(RMS::Worklogs::_hoursToDuration('1.00033')), '+01:00:01', '+01:00:01');
    is($dtF_hms->format_duration(RMS::Worklogs::_hoursToDuration('0.0000001')), '+00:00:01', '1e-07');
}

subtest "_verifyStartTime", \&_verifyStartTime;
sub _verifyStartTime {
    my $_verifyStartTimeTest = sub {
        eval {
            my ($expected, $start, $duration) = @_;
            my ($h, $m) = $duration =~ /(\d+)/g;

            my ($day, $expectedDt, $stDt);
            $day = '2016-05-20';
            $expectedDt = DateTime::Format::MySQL->parse_datetime( "$day $expected" );
            $stDt = RMS::Worklogs->_verifyStartTime(
                            $day,
                            ($start) ? DateTime::Format::MySQL->parse_datetime( "$start" ) : undef,
                            DateTime::Duration->new(hours => $h, minutes => $m),
            );

            is($stDt->iso8601(), $expectedDt->iso8601(), ($start || 'undef   ')." => $expected using $duration");
        };
        if ($@) {
            ok(0, $@);
        }
    };

    &$_verifyStartTimeTest('07:45:00', '2016-05-20 07:45:00', '08:00');
    &$_verifyStartTimeTest('03:45:00', '2016-05-20 03:45:00', '20:15');
    &$_verifyStartTimeTest('03:44:59', '2016-05-20 07:45:00', '20:15');
    &$_verifyStartTimeTest('03:44:59', undef,                 '20:15');
    &$_verifyStartTimeTest('00:00:00', '2016-05-19 23:30:00', '20:15');
}

subtest "_verifyEndTime", \&_verifyEndTime;
sub _verifyEndTime {
    my $_verifyEndTimeTest = sub {
        eval {
            my ($expected, $start, $end, $duration) = @_;
            my ($h, $m) = $duration =~ /(\d+)/g;

            my ($day, $expectedDt, $stDt, $endDt);
            $day = '2016-05-20';
            $expectedDt = DateTime::Format::MySQL->parse_datetime( "$day $expected" );
            $endDt = RMS::Worklogs->_verifyEndTime(
                            $day,
                            DateTime::Format::MySQL->parse_datetime( "$day $start" ),
                            ($end) ? DateTime::Format::MySQL->parse_datetime( "$day $end" ) : undef,
                            DateTime::Duration->new(hours => $h, minutes => $m),
            );

            is($endDt->iso8601(), $expectedDt->iso8601(), ($end || 'undef   ')." => $expected using $duration");
        };
        if ($@) {
            ok(0, $@);
        }
    };

    &$_verifyEndTimeTest('16:45:00', '07:45:00', '16:45:00', '08:00');
    &$_verifyEndTimeTest('15:45:00', '07:45:00', undef     , '08:00');
    &$_verifyEndTimeTest('17:45:00', '07:45:00', '10:00:00', '10:00');
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
            $breaks = RMS::Worklogs->_verifyBreaks(
                            $day,
                            DateTime::Format::MySQL->parse_datetime( "$day $start" ),
                            ($end) ? DateTime::Format::MySQL->parse_datetime( "$day $end" ) : undef,
                            DateTime::Duration->new(hours => $dH, minutes => $dM, seconds => $dS || 0),
            );

            is($dtF_hms->format_duration($breaks), $dtF_hms->format_duration($expectedDuration), "$start - $end using $duration => $expected");
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
        return [
            {spent_on => '2016-05-20', created_on => '2016-05-20 11:05:17', hours => 1.5},
            {spent_on => '2016-05-20', created_on => '2016-05-20 11:08:29', hours => 0.5},
            {spent_on => '2016-05-20', created_on => '2016-05-20 11:09:06', hours => 0.25},
            {spent_on => '2016-05-20', created_on => '2016-05-20 11:51:26', hours => 0.5},
            {spent_on => '2016-05-20', created_on => '2016-05-20 11:52:18', hours => 0.25},
            {spent_on => '2016-05-20', created_on => '2016-05-20 15:29:21', hours => 3.5},
        ];
    });

    my $days = RMS::Worklogs->new({user_id => 1})->asDays();
    my @k = sort keys %$days;
    is(scalar(keys(%$days)), 1, "1 days");

    is($days->{$k[0]}->day(),              '2016-05-20',          "1st day");
    is($days->{$k[0]}->start()->iso8601(), '2016-05-20T09:35:17', "1st start");
    is($days->{$k[0]}->end()->iso8601(),   '2016-05-20T16:05:17', "1st end");
    is($dtF_hms->format_duration($days->{$k[0]}->duration()), '+06:30:00', "1st duration");
    is($dtF_hms->format_duration($days->{$k[0]}->breaks()),   '+00:00:00', "1st breaks");
    is($dtF_hms->format_duration($days->{$k[0]}->overwork()), '-00:45:00', "1st overwork");
}

subtest "advancedDailyLogging", \&advancedDaily;
sub advancedDaily {
    my $module = Test::MockModule->new('RMS::Worklogs');
    $module->mock('getWorklogs', sub {
        return [
            {spent_on => '2015-06-11', created_on => '2015-06-11 10:34:29', hours => 0.5}, #This day had a problem with exponentially small 'hours'
            {spent_on => '2015-06-11', created_on => '2015-06-11 11:26:06', hours => 0.75},
            {spent_on => '2015-06-11', created_on => '2015-06-11 11:28:11', hours => 0.25},
            {spent_on => '2015-06-11', created_on => '2015-06-11 18:10:37', hours => 3},
            {spent_on => '2015-06-11', created_on => '2015-06-11 18:11:59', hours => 2},
            {spent_on => '2015-06-11', created_on => '2015-06-11 18:13:46', hours => 2},
            {spent_on => '2015-06-11', created_on => '2015-06-11 18:14:16', hours => 0.0000001},

            {spent_on => '2015-11-03', created_on => '2015-11-03 08:54:38', hours => 0.5},
            {spent_on => '2015-11-03', created_on => '2015-11-03 08:55:45', hours => 0.25},
            {spent_on => '2015-11-03', created_on => '2015-11-03 09:50:08', hours => 1},
            {spent_on => '2015-11-03', created_on => '2015-11-03 13:38:01', hours => 1},
            {spent_on => '2015-11-03', created_on => '2015-11-03 13:41:22', hours => 0.25},
            {spent_on => '2015-11-03', created_on => '2015-11-03 13:43:10', hours => 2.5},
            {spent_on => '2015-11-03', created_on => '2015-11-03 14:25:20', hours => 0.25},
            {spent_on => '2015-11-03', created_on => '2015-11-03 14:36:43', hours => 0.25},
            {spent_on => '2015-11-03', created_on => '2015-11-03 15:48:20', hours => 1},
            {spent_on => '2015-11-03', created_on => '2015-11-03 15:48:51', hours => 0.25},
            {spent_on => '2015-11-03', created_on => '2015-11-03 18:04:17', hours => 0.25},
            {spent_on => '2015-11-03', created_on => '2015-11-03 18:05:28', hours => 2},
            {spent_on => '2015-11-03', created_on => '2015-11-03 18:48:14', hours => 0.75},

            {spent_on => '2015-11-04', created_on => '2015-11-04 11:59:36', hours => 0.375}, #This day had a strange bug in 'breaks'-calculus
            {spent_on => '2015-11-04', created_on => '2015-11-04 12:00:00', hours => 0.37},
            {spent_on => '2015-11-04', created_on => '2015-11-04 16:59:43', hours => 0.25},
            {spent_on => '2015-11-04', created_on => '2015-11-04 17:03:12', hours => 4},
            {spent_on => '2015-11-04', created_on => '2015-11-04 17:03:20', hours => 1},
            {spent_on => '2015-11-04', created_on => '2015-11-04 17:24:45', hours => 0.25},
            {spent_on => '2015-11-04', created_on => '2015-11-04 18:56:10', hours => 1},
            {spent_on => '2015-11-04', created_on => '2015-11-04 18:57:50', hours => 0.75},

            {spent_on => '2016-04-26', created_on => '2016-04-26 23:34:42', hours => 2},    #Bugfix where these days yield strange hours
            {spent_on => '2016-04-26', created_on => '2016-04-26 23:35:07', hours => 3},
            {spent_on => '2016-04-26', created_on => '2016-04-26 23:35:25', hours => 2.25}, #end time - start time = -15:00
            {spent_on => '2016-04-27', created_on => '2016-04-27 00:20:48', hours => 0.75}, #end time - start time = 00:00
            {spent_on => '2016-04-27', created_on => '2016-04-27 15:29:40', hours => 4},
            {spent_on => '2016-04-27', created_on => '2016-04-27 16:02:33', hours => 0.5},
            {spent_on => '2016-04-27', created_on => '2016-04-27 16:34:53', hours => 0.6},
            {spent_on => '2016-04-27', created_on => '2016-04-27 18:25:28', hours => 1.75},
            {spent_on => '2016-04-27', created_on => '2016-04-27 18:26:02', hours => 0.2},
            {spent_on => '2016-04-27', created_on => '2016-04-27 19:30:00', hours => 0.95},
            {spent_on => '2016-04-27', created_on => '2016-04-27 19:36:21', hours => 0.25},

            {spent_on => '2016-05-20', created_on => '2016-05-20 11:05:17', hours => 10.5},  #Dangerous unsyncronized worklog entries
            {spent_on => '2016-05-20', created_on => '2016-05-20 11:08:29', hours => 0.5},
            {spent_on => '2016-05-20', created_on => '2016-05-20 11:09:06', hours => 0.25},
            {spent_on => '2016-05-20', created_on => '2016-05-20 11:51:26', hours => 0.5},
            {spent_on => '2016-05-20', created_on => '2016-05-20 11:52:18', hours => 0.25},
            {spent_on => '2016-05-20', created_on => '2016-05-20 15:29:21', hours => 3.5},

            {spent_on => '2016-05-21', created_on => '2016-05-21 11:08:29', hours => 0.5},  #Dangerous unsyncronized worklog entries fixed days later
            {spent_on => '2016-05-21', created_on => '2016-05-21 11:09:06', hours => 0.25},
            {spent_on => '2016-05-21', created_on => '2016-05-21 11:51:26', hours => 0.5},
            {spent_on => '2016-05-21', created_on => '2016-05-21 11:52:18', hours => 0.25},
            {spent_on => '2016-05-21', created_on => '2016-05-22 15:29:21', hours => 3.5},
            {spent_on => '2016-05-21', created_on => '2016-05-23 11:00:00', hours => 10.5},
        ];
    });

    my $days = RMS::Worklogs->new({user_id => 1})->asDays();
    my @k = sort keys %$days;
    is(scalar(keys(%$days)), 7, "7 days");

    is($days->{$k[0]}->day(),              '2015-06-11',          "2015-06-11");
    is($days->{$k[0]}->start()->iso8601(), '2015-06-11T10:04:29', "2015-06-11 start");
    is($days->{$k[0]}->end()->iso8601(),   '2015-06-11T18:34:30', "2015-06-11 end");
    is($dtF_hms->format_duration($days->{$k[0]}->duration()), '+08:30:01', "2015-06-11 duration");
    is($dtF_hms->format_duration($days->{$k[0]}->breaks()),   '+00:00:00', "2015-06-11 breaks");
    is($dtF_hms->format_duration($days->{$k[0]}->overwork()), '+01:15:01', "2015-06-11 overwork");

    is($days->{$k[1]}->day(),              '2015-11-03',          "2015-11-03 day");
    is($days->{$k[1]}->start()->iso8601(), '2015-11-03T08:24:38', "2015-11-03 start");
    is($days->{$k[1]}->end()->iso8601(),   '2015-11-03T18:48:14', "2015-11-03 end");
    is($dtF_hms->format_duration($days->{$k[1]}->duration()), '+10:15:00', "2015-11-03 duration");
    is($dtF_hms->format_duration($days->{$k[1]}->breaks()),   '+00:08:36', "2015-11-03 breaks");
    is($dtF_hms->format_duration($days->{$k[1]}->overwork()), '+03:00:00', "2015-11-03 overwork");

    is($days->{$k[2]}->day(),              '2015-11-04',          "2015-11-04 day");
    is($days->{$k[2]}->start()->iso8601(), '2015-11-04T11:37:06', "2015-11-04 start");
    is($days->{$k[2]}->end()->iso8601(),   '2015-11-04T19:36:48', "2015-11-04 end");
    is($dtF_hms->format_duration($days->{$k[2]}->duration()), '+07:59:42', "2015-11-04 duration");
    is($dtF_hms->format_duration($days->{$k[2]}->breaks()),   '+00:00:00', "2015-11-04 breaks");
    is($dtF_hms->format_duration($days->{$k[2]}->overwork()), '+00:44:42', "2015-11-04 overwork");

    is($days->{$k[3]}->day(),              '2016-04-26',          "2016-04-26 day");
    is($days->{$k[3]}->start()->iso8601(), '2016-04-26T16:44:59', "2016-04-26 start");
    is($days->{$k[3]}->end()->iso8601(),   '2016-04-26T23:59:59', "2016-04-26 end");
    is($dtF_hms->format_duration($days->{$k[3]}->duration()), '+07:15:00', "2016-04-26 duration");
    is($dtF_hms->format_duration($days->{$k[3]}->breaks()),   '+00:00:00', "2016-04-26 breaks");
    is($dtF_hms->format_duration($days->{$k[3]}->overwork()), '+00:00:00', "2016-04-26 overwork");
    is($days->{$k[4]}->day(),              '2016-04-27',          "2016-04-27 day");
    is($days->{$k[4]}->start()->iso8601(), '2016-04-27T00:00:00', "2016-04-27 start");
    is($days->{$k[4]}->end()->iso8601(),   '2016-04-27T19:36:21', "2016-04-27 end");
    is($dtF_hms->format_duration($days->{$k[4]}->duration()), '+09:00:00', "2016-04-27 duration");
    is($dtF_hms->format_duration($days->{$k[4]}->breaks()),   '+10:36:21', "2016-04-27 breaks");
    is($dtF_hms->format_duration($days->{$k[4]}->overwork()), '+01:45:00', "2016-04-27 overwork");

    is($days->{$k[5]}->day(),              '2016-05-20',          "2016-05-20 day");
    is($days->{$k[5]}->start()->iso8601(), '2016-05-20T00:35:17', "2016-05-20 start");
    is($days->{$k[5]}->end()->iso8601(),   '2016-05-20T16:05:17', "2016-05-20 end");
    is($dtF_hms->format_duration($days->{$k[5]}->duration()), '+15:30:00', "2016-05-20 duration");
    is($dtF_hms->format_duration($days->{$k[5]}->breaks()),   '+00:00:00', "2016-05-20 breaks");
    is($dtF_hms->format_duration($days->{$k[5]}->overwork()), '+08:15:00', "2016-05-20 overwork");

    is($days->{$k[6]}->day(),              '2016-05-21',          "2016-05-21 day");
    is($days->{$k[6]}->start()->iso8601(), '2016-05-21T08:29:59', "2016-05-21 start");
    is($days->{$k[6]}->end()->iso8601(),   '2016-05-21T23:59:59', "2016-05-21 end");
    is($dtF_hms->format_duration($days->{$k[6]}->duration()), '+15:30:00', "2016-05-21 duration");
    is($dtF_hms->format_duration($days->{$k[6]}->breaks()),   '+00:00:00', "2016-05-21 breaks");
    is($dtF_hms->format_duration($days->{$k[6]}->overwork()), '+08:15:00', "2016-05-21 overwork");
}

subtest "simpleCsvExport", \&simpleCsvExport;
sub simpleCsvExport {
    my $module = Test::MockModule->new('RMS::Worklogs');
    $module->mock('getWorklogs', sub {
        return [
            {spent_on => '2016-05-20', created_on => '2016-05-20 12:00:00', hours => 2},
            {spent_on => '2016-05-23', created_on => '2016-05-23 12:00:00', hours => 2},
            {spent_on => '2016-05-24', created_on => '2016-05-24 12:00:00', hours => 2},
            {spent_on => '2016-05-26', created_on => '2016-05-26 12:00:00', hours => 2},
        ];
    });
    my ($days, $csv, $fh, $row);

    $days = RMS::Worklogs->new({user_id => 1})->asCsv('/tmp/workTime.csv');
    is(scalar(keys(%$days)), 7, "7 days");

    $csv = Text::CSV->new({binary => 1}) or die "Cannot use CSV: ".Text::CSV->error_diag ();
    open($fh, "<:encoding(utf8)", '/tmp/workTime.csv') or die "/tmp/workTime.csv: $!";

    $row = $csv->getline( $fh );
    is($row->[0], '2016-05-20',          "1st day");
    is($row->[1], '10:00:00', "1st start");
    is($row->[2], '12:00:00', "1st end");
    is($row->[3], '+00:00:00', "1st breaks");
    is($row->[4], '+02:00:00', "1st duration");
    is($row->[5], '-05:15:00', "1st overwork");
    $row = $csv->getline( $fh );
    is($row->[0], '2016-05-21',          '2nd day filled');
    is($row->[1], '',                    "2nd start empty");
    is($row->[2], '',                    "2nd end empty");
    is($row->[3], '',                    "2nd breaks empty");
    is($row->[4], '',                    "2nd duration empty");
    is($row->[5], '',                    "2nd overwork empty");
    $row = $csv->getline( $fh );
    is($row->[0], '2016-05-22',          '3rd day filled');
    is($row->[1], '',                    "3rd start empty");
    $row = $csv->getline( $fh );
    is($row->[0], '2016-05-23',          '4th day');
    is($row->[1], '10:00:00', "4th start");
    $row = $csv->getline( $fh );
    is($row->[0], '2016-05-24',          '5th day');
    is($row->[1], '10:00:00', "5th start");
    $row = $csv->getline( $fh );
    is($row->[0], '2016-05-25',          '6th day filled');
    is($row->[1], '',                    "6th start empty");
    $row = $csv->getline( $fh );
    is($row->[0], '2016-05-26',          '7th day');
    is($row->[1], '10:00:00', "7th start");

    close($fh);
    `rm /tmp/workTime.csv`;
}

done_testing();
