#!/usr/bin/perl

use Modern::Perl;
use Test::More;
use Test::MockModule;

use RMS::Dates;



subtest "formatDurationPHMS", \&formatDurationPHMS;
sub formatDurationPHMS {
    eval {

    my $testSub = sub {
        my ($dd, $phms) = @_;
        is(RMS::Dates::formatDurationPHMS( $dd ), $phms, "$phms");
    };
    &$testSub( DateTime::Duration->new() , '+00:00:00');
    &$testSub( DateTime::Duration->new(days => 0, minutes => 0, seconds => 0),          '+00:00:00');
    &$testSub( DateTime::Duration->new(days => -1, minutes => 30, seconds => -15),      '-23:30:15');
    &$testSub( DateTime::Duration->new(days => -2, minutes => 30, seconds => -15),      '-47:30:15');
    &$testSub( DateTime::Duration->new(days => 2, minutes => 30, seconds => -15),       '+48:29:45');
    &$testSub( DateTime::Duration->new(hours => 2, minutes => -10, seconds => -15),     '+01:49:45');
    &$testSub( DateTime::Duration->new(hours => -2, minutes => 150.5, seconds => -15),  '+00:30:15');
    &$testSub( DateTime::Duration->new(days => -0.25, minutes => 0.25, seconds => -15), '-06:00:00');
    &$testSub( DateTime::Duration->new(seconds => -0.67),                               '-00:00:01'); #This interesting fringe case can happen when DateTime::Durations are subtracted and added even if there are no fractions involved?
    &$testSub( DateTime::Duration->new(seconds => 0.25),                                '+00:00:01');

    };
    ok(0, $@) if $@;
}

#This test uses almost the same backend as formatDurationPHMS()
subtest "formatDurationHMS", \&formatDurationHMS;
sub formatDurationHMS {
    eval {

    my $testSub = sub {
        my ($dd, $phms) = @_;
        is(RMS::Dates::formatDurationHMS( $dd ), $phms, "$phms");
    };
    &$testSub( DateTime::Duration->new(),                                               '00:00:00');
    &$testSub( DateTime::Duration->new(hours => 2, minutes => -10, seconds => -15),     '01:49:45');

    };
    ok(0, $@) if $@;
}


done_testing();
