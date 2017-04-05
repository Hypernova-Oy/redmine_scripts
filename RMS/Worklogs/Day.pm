package RMS::Worklogs::Day;

use Modern::Perl;
use Carp;

use DateTime::Duration;

use RMS::Dates;
use RMS::WorkRules;


sub new {
    my ($class, $startDt, $endDt, $breakDuration, $workdayDuration, $benefits, $remote, $comments) = @_;

    my $dayLength = RMS::WorkRules->new()->getDayLengthDt($startDt);
    my $self = {
        start => $startDt,
        end => $endDt,
        breaks => $breakDuration,
        duration => $workdayDuration,
        benefits => $benefits,
        remote => $remote,
        overwork => $workdayDuration->clone->subtract($dayLength),
        comments => $comments,
    };

    bless($self, $class);
    return $self;
}

=head2 newFromWorklogs

Given a bunch of worklogs for a single day, from the Redmine DB,
a flattened day-representation of the events happened within those worklog entries is returned.

=cut

sub newFromWorklogs {
    my ($class, $day, $worklogs) = @_;
    unless ($day =~ /^\d\d\d\d-\d\d-\d\d$/) {
        confess "\$day '$day' is not a proper YYYY-MM-DD date";
    }

    my ($startDt, $endDt, $breaksDuration, $workdayDuration, $benefits, $remote, $overflow);
    my @wls = sort {$a->{created_on} cmp $b->{created_on}} @$worklogs; #Sort from morning to evening, so first index is the earliest log entry

    ##Flatten all comments and look for tags
    my @comments;
    foreach my $log (@wls) {
        push(@comments, $log->{comments});
    }
    my $comments = join(' ', @comments);
    ($benefits, $remote, $startDt, $endDt, $comments) = RMS::Worklogs::Tags::parseTags($comments);


    #Hope to find some meaningful start time
    if (not($startDt) && $wls[0]->{created_on} =~ /^$day/) {
        $startDt = DateTime::Format::MySQL->parse_datetime( $wls[0]->{created_on} );
        $startDt->subtract_duration( RMS::Dates::hoursToDuration( $wls[0]->{hours} ) );
    }


    #Sum the separate worklog entries and hope to find some meaningful end time
    $workdayDuration = DateTime::Duration->new();
    foreach my $wl (@wls) {
        $workdayDuration->add_duration(RMS::Dates::hoursToDuration( $wl->{hours} ));
        if (not($endDt) && $wl->{created_on} =~ /^$day/) {
            $endDt = DateTime::Format::MySQL->parse_datetime( $wl->{created_on} );
        }
    }


    $startDt = $class->_verifyStartTime($day, $startDt, $workdayDuration);
    ($endDt, $overflow) = $class->_verifyEndTime($day, $startDt, $endDt, $workdayDuration);
    $breaksDuration = $class->_verifyBreaks($day, $startDt, $endDt, $workdayDuration);

    $comments = "!END overflow $overflow!$comments" if ($overflow);
    return RMS::Worklogs::Day->new($startDt, $endDt, $breaksDuration, $workdayDuration, $benefits, $remote, $comments);
}

sub day {
    return shift->start->ymd('-');
}
sub start {
    return shift->{start};
}
sub end {
    return shift->{end};
}
sub duration {
    return shift->{duration};
}
sub breaks {
    return shift->{breaks};
}
sub overwork {
    return shift->{overwork};
}
sub remote {
    return shift->{remote};
}
sub benefits {
    return shift->{benefits};
}
sub comments {
    return shift->{comments};
}


=head2 $class->_verifyStartTime

Start time defaults to 08:00, or the one given, but we must check if the workday
duration actually can fit inside one day if it starts at 08:00

We might have to shift the start time earlier than 08:00 in some cases where
days have been very long.

It is possible for the $startDt to be earlier than the current day, so we must
adjust that back to 00:00:00. This can happen when one logs more hours than there
have been up to the moment of logging

=cut

sub _verifyStartTime {
    my ($class, $day, $startDt, $duration) = @_;

    unless ($startDt) {
        $startDt = DateTime::Format::MySQL->parse_datetime( "$day 08:00:00" );
    }
    if ($startDt->isa('DateTime::Duration')) {
        $startDt = DateTime::Format::MySQL->parse_datetime( "$day ".RMS::Dates::formatDurationHMS($startDt) );
    }
    unless ($startDt->ymd('-') eq $day) { #$startDt might get moved to the previous day, so catch this and fix it.
        $startDt = DateTime::Format::MySQL->parse_datetime( "$day 00:00:00" );
    }

    my $remainder = DateTime::Duration->new(days => 1)->subtract( $duration );

    my $startDuration = $startDt->subtract_datetime(  DateTime::Format::MySQL->parse_datetime( "$day 00:00:00" )  ); #We get the hours and minutes
    if (DateTime::Duration->compare($remainder, $startDuration, $startDt) >= 0) { #Remainder is bigger than the starting hours, so we have plenty of time today to fill the worktime starting from the given startTime
        return $startDt;
    }
    #If we started working on the starting time, and we cannot fit the whole workday duration to the current day. So we adjust the starting time to an earlier time.
    $remainder->subtract($startDuration);
    $startDt->add_duration($remainder); #Remainder is negative, because it has got $startDuration subtracted from it
    $startDt->subtract_duration(DateTime::Duration->new(seconds => 1)); #remove one minute from midnight so $endDt is not 00:00:00 but 23:59:59 instead
    return $startDt;
}

=head2 $class->_verifyEndTime

End time defaults to $startTime + workday duration, or the one given
If the given workday duration cannot fit between the given start time and the given end time,
  a comment !END overflow HH:MM:SS! is appended to the workday comments.
@RETURNS (DateTime, $overflow);

=cut

sub _verifyEndTime {
    my ($class, $day, $startDt, $endDt, $duration) = @_;

    #Create default end time from start + duration
    unless ($endDt) {
        $endDt = $startDt->clone()->add_duration($duration);
    }
    if ($endDt->isa('DateTime::Duration')) {
        $endDt = DateTime::Format::MySQL->parse_datetime( "$day ".RMS::Dates::formatDurationHMS($endDt) );
    }

    #Check if workday duration fits between start and end.
    if (DateTime->compare($startDt->clone()->add_duration($duration), $endDt) <= 0) {
        return ($endDt, undef);
    }

    #it didn't fit, push end time forward. _verifyStartTime() should make sure this doesn't push the ending date to the next day.
    my $overflow = $startDt->clone()->add_duration($duration)->subtract_datetime($endDt);
    return ($startDt->clone()->add_duration($duration),
            RMS::Dates::formatDurationHMS($overflow));
}

sub _verifyBreaks {
    my ($class, $day, $startDt, $endDt, $duration) = @_;

    my $realDuration = $endDt->subtract_datetime($startDt);
    $realDuration->subtract($duration);
    return $realDuration if (DateTime::Duration->compare($realDuration, DateTime::Duration->new(), $startDt) >= 0); #$realDuration is positive.

    #Break is negative, so $startDt and $endDt are too tight for $duration
    #If duration is -00:00:01 (-1 second) we let it slip, but only this time!
    return $realDuration if (DateTime::Duration->compare($realDuration, DateTime::Duration->new(seconds => -1), $startDt) >= 0); #$realDuration is bigger than -1 seconds.

    confess "\$startDt '".$startDt->iso8601()."' and \$endDt '".$endDt->iso8601()."' is too tight to fit the workday duration '".RMS::Dates::formatDurationPHMS($duration)."'. Break '".RMS::Dates::formatDurationPHMS($realDuration)."' cannot be negative!\n";
}

1;
