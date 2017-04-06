#!/usr/bin/perl

use Modern::Perl;
use Test::More;
use Test::MockModule;

use RMS::Dates;
use RMS::Worklogs;
use RMS::Worklogs::Tags;




subtest "parseTags", \&parseTags;
sub parseTags {
    my ($benefits, $remote, $start, $end, $overworkReimbursed, $overworkReimbursedBy, $remainingComment);
    eval {

    ($benefits, $remote, $start, $end, $overworkReimbursed, $overworkReimbursedBy, $remainingComment) =
        RMS::Worklogs::Tags::parseTags('{{BEGIN0800}} - {{CLOSE1600}}{{REMOTE}}. This is a {{odd}} nice day.{{BONUS}} and overwork paid {{REIMBURSED 50:00 @bossman}}');
    is($benefits, 1, 'Benefits ok');
    is($remote, 1, 'Remote ok');
    is(ref($start), 'DateTime::Duration', 'Start ok');
    is(RMS::Dates::formatDurationPHMS($start), '+08:00:00', 'Start ok');
    is(ref($end), 'DateTime::Duration', 'End ok');
    is(RMS::Dates::formatDurationPHMS($end),   '+16:00:00', 'End ok');
    is(ref($overworkReimbursed), 'DateTime::Duration', 'Overwork reimbursed ok');
    is(RMS::Dates::formatDurationHMS($overworkReimbursed),   '50:00:00', 'Overwork reimbursed ok');
    is($overworkReimbursedBy, '@bossman', 'Overwork reimbursed by ok');
    is($remainingComment, 'Strange tag {{odd}}?  - . This is a  nice day. and overwork paid ', 'Comment remnants ok');

    };
    ok(0, $@) if $@;
}

subtest "extractTags", \&extractTags;
sub extractTags {
    eval {
    my $module = Test::MockModule->new('RMS::Worklogs');
    $module->mock('getWorklogs', sub {
        return [
            {comments => '{{START08:33}}. This is a nice day.',
             spent_on => '2017-05-20', created_on => '2017-05-20 11:05:17', hours => 1.5,  issue_id => 9999, activity => ''},
            {comments => 'Today I am working {{REMOTE}}:ly and it is ok.',
             spent_on => '2017-05-20', created_on => '2017-05-20 11:08:29', hours => 0.5,  issue_id => 9999, activity => ''},
            {comments => 'My boss said "{{BENEFITS}}" so I get paid for weekend-work',
             spent_on => '2017-05-20', created_on => '2017-05-20 11:09:06', hours => 0.25, issue_id => 9999, activity => ''},
            {comments => 'This is just a comment to confuse you',
             spent_on => '2017-05-20', created_on => '2017-05-20 11:51:26', hours => 0.5,  issue_id => 9999, activity => ''},
            {comments => 'This {comment} is here to {{confuse}} the program',
             spent_on => '2017-05-20', created_on => '2017-05-20 11:52:18', hours => 0.25, issue_id => 9999, activity => ''},
            {comments => '{{END1633}}. I hope I did it all.',
             spent_on => '2017-05-20', created_on => '2017-05-20 15:29:21', hours => 3.5,  issue_id => 9999, activity => ''},
            {comments => '{{BEGIN 08:00}} - {{CLOSE1600}}{{REMOTE}}. This is a nice day.{{BONUS}}',
             spent_on => '2017-05-21', created_on => '2017-05-21 16:05:02', hours => 8.5,  issue_id => 9999, activity => ''},
            {comments => '{{PAID 08:00 @bossman}}',
             spent_on => '2017-05-22', created_on => '2017-05-22 16:05:02', hours => 8.5,  issue_id => 9999, activity => ''},
            {comments => '{{REIMBURSED 05:00 @bossman}}',
             spent_on => '2017-05-23', created_on => '2017-05-23 16:05:02', hours => 8.5,  issue_id => 9999, activity => ''},
        ];
    });

    my $days = RMS::Worklogs->new({user => 1})->asDays();
    my @k = sort keys %$days;
    is(scalar(keys(%$days)), 4, "4 days");

    is($days->{$k[0]}->day(),              '2017-05-20',          "1st day");
    is($days->{$k[0]}->start()->iso8601(), '2017-05-20T08:33:00', "1st start from tag BEGIN");
    is($days->{$k[0]}->end()->iso8601(),   '2017-05-20T16:33:00', "1st end from tag CLOSE");
    is(RMS::Dates::formatDurationPHMS($days->{$k[0]}->duration()), '+06:30:00', "1st duration");
    is(RMS::Dates::formatDurationPHMS($days->{$k[0]}->breaks()),   '+01:30:00', "1st breaks");
    is(RMS::Dates::formatDurationPHMS($days->{$k[0]}->overwork()), '-00:51:00', "1st overwork");
    is($days->{$k[0]}->benefits(),         1,                     "Benefits allowed");
    is($days->{$k[0]}->remote(),           1,                     "Worked remotely");
    like(  $days->{$k[0]}->comments(),     qr/\{\{confuse\}\}/i,   "Unknown tag {{confuse}} caught in the comments");
    unlike($days->{$k[0]}->comments(),     qr/BEGIN/i,             "Known tags trimmed from the comments 1");
    unlike($days->{$k[0]}->comments(),     qr/BENEFITS/i,          "Known tags trimmed from the comments 2");
    unlike($days->{$k[0]}->comments(),     qr/REMOTE/i,            "Known tags trimmed from the comments 3");

    is($days->{$k[1]}->day(),              '2017-05-21',          "2nd day");
    is($days->{$k[1]}->start()->iso8601(), '2017-05-21T08:00:00', "2nd start from tag BEGIN");
    isnt($days->{$k[1]}->end()->iso8601(), '2017-05-21T16:00:00', "2nd end from tag CLOSE isnt from the tag");
    is($days->{$k[1]}->end()->iso8601(),   '2017-05-21T16:30:00', "2nd end from tag CLOSE autocorrected");
    is(RMS::Dates::formatDurationPHMS($days->{$k[1]}->duration()), '+08:30:00', "2nd duration");
    is(RMS::Dates::formatDurationPHMS($days->{$k[1]}->breaks()),   '+00:00:00', "2nd breaks");
    is(RMS::Dates::formatDurationPHMS($days->{$k[1]}->overwork()), '+01:09:00', "2nd overwork");
    is($days->{$k[1]}->benefits(),       1,                       "Benefits allowed");
    is($days->{$k[1]}->remote(),         1,                       "Worked remotely");
    like($days->{$k[1]}->comments(), qr/!END overflow 00:30:00!/, "Warning about ENDing time calculation overflow");
    is($days->{$k[1]}->comments(), '!END overflow 00:30:00! - . This is a nice day.',    "Known tags trimmed from the comment");

    is(RMS::Dates::formatDurationHMS($days->{$k[2]}->overworkReimbursed()), '08:00:00', 'Overwork paid');
    is($days->{$k[2]}->overworkReimbursedBy(), '@bossman', 'Overwork paid by');

    is(RMS::Dates::formatDurationHMS($days->{$k[3]}->overworkReimbursed()), '05:00:00', 'Overwork reimbursed');
    is($days->{$k[3]}->overworkReimbursedBy(), '@bossman', 'Overwork reimbursed by');

    };
    ok(0, $@) if $@;
}



done_testing();
