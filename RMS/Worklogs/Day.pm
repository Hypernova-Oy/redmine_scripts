package RMS::Worklogs::Day;

use Modern::Perl;
use Carp;
use Params::Validate qw(:all);

use DateTime::Duration;

use RMS::Validations;
use RMS::Dates;
use RMS::Worklogs::Tags;
use RMS::WorkRules;

use RMS::Logger;
my $l = bless({}, 'RMS::Logger');

=head2 new

    RMS::Worklogs::Day->new({
      start => DateTime,                 #When the workday started
      end => DateTime,                   #When the workday ended
      breaks => DateTime::Duration,      #How long breaks have been held in total
      duration => DateTime::Duration,    #How long the workday was?
      overflow => DateTime::Duration,    #How much was the ending time forcefully delayed?
      underflow => $underflowDuration,   #How much was the starting time forcefully earlied?
      benefits => 1 || undef,            #Should we calculate extra work bonuses for this day?
      remote => 1 || undef,              #Was this day a remote working day?
      comments => "Freetext",            #All the worklog comments for the day
    });

=cut

our %validations = (
    start =>     {isa => 'DateTime'},
    end =>       {isa => 'DateTime'},
    breaks =>    {isa => 'DateTime::Duration'},
    duration =>  {isa => 'DateTime::Duration'},
    benefits =>  {type => SCALAR|UNDEF},
    remote =>    {type => SCALAR|UNDEF},
    overwork =>  {callbacks => { isa_undef => sub {    not(defined($_[0])) || $_[0]->isa('DateTime::Duration')    }}, optional => 1},
    overworkReimbursed =>   {callbacks => { isa_undef => sub {    not(defined($_[0])) || $_[0]->isa('DateTime::Duration')    }}, optional => 1},
    overworkReimbursedBy => {type => SCALAR|UNDEF, depends => 'overworkReimbursed'},
    overworkAccumulation => {isa => 'DateTime::Duration'},
    overflow =>  {callbacks => { isa_undef => sub {    not(defined($_[0])) || $_[0]->isa('DateTime::Duration')    }}, optional => 1},
    underflow => {callbacks => { isa_undef => sub {    not(defined($_[0])) || $_[0]->isa('DateTime::Duration')    }}, optional => 1},
    comments =>  {type => SCALAR|UNDEF},
);
sub new {
    my ($class) = shift;
    my $params = validate(@_, \%validations);

    #If the end time overflows because workday duration is too long, append a warning to comments
    #eg. "!END overflow 00:33:12!A typical comment."
    $params->{comments} = '!END overflow '.RMS::Dates::formatDurationHMS($params->{overflow}).'!'.($params->{comments} ? $params->{comments} : '') if ($params->{overflow});
    $params->{comments} = '!START underflow '.RMS::Dates::formatDurationHMS($params->{underflow}).'!'.($params->{comments} ? $params->{comments} : '') if ($params->{underflow});

    my $dayLength = RMS::WorkRules->new()->getDayLengthDt($params->{start});
    my $overworkDuration = $params->{duration}->clone->subtract($dayLength);
    my $overworkAccumulation = $params->{overworkAccumulation}->clone()->add_duration($overworkDuration);
    $overworkAccumulation->subtract_duration($params->{overworkReimbursed}) if $params->{overworkReimbursed};
    my $self = {
        ymd => $params->{start}->ymd(),
        start => $params->{start},
        end => $params->{end},
        breaks => $params->{breaks},
        duration => $params->{duration},
        benefits => $params->{benefits},
        remote => $params->{remote},
        overwork => $overworkDuration,
        overworkReimbursed => $params->{overworkReimbursed},
        overworkReimbursedBy => $params->{overworkReimbursedBy},
        overworkAccumulation => $overworkAccumulation,
        overflow => $params->{overflow},
        underflow => $params->{underflow},
        comments => $params->{comments},
    };

    bless($self, $class);
    return $self;
}

=head2 newFromWorklogs

Given a bunch of worklogs for a single day, from the Redmine DB,
a flattened day-representation of the events happened within those worklog entries is returned.



=cut

sub newFromWorklogs {
    my ($class, $dayYMD, $overworkAccumulation, $worklogs) = @_;
    unless ($dayYMD =~ /^\d\d\d\d-\d\d-\d\d$/) {
        confess "\$day '$dayYMD' is not a proper YYYY-MM-DD date";
    }

    my ($startDt, $endDt, $breaksDuration, $workdayDuration, $benefits, $remote, $overflowDuration, $underflowDuration, $overworkReimbursed, $overworkReimbursedBy);
    my @wls = sort {$a->{created_on} cmp $b->{created_on}} @$worklogs; #Sort from morning to evening, so first index is the earliest log entry

    ##Flatten all comments so tags can be looked for
    my @comments;
    ##Sum the durations of all individual worklog entries
    $workdayDuration = DateTime::Duration->new();
    foreach my $wl (@wls) {
        push(@comments, $wl->{comments}) if $wl->{comments};
        $l->trace("$dayYMD -> Comment prepended '".$wl->{comments}."'") if $wl->{comments} && $l->is_trace();

        $workdayDuration->add_duration(RMS::Dates::hoursToDuration( $wl->{hours} ));
        $l->trace("$dayYMD -> Duration grows to ".RMS::Dates::formatDurationHMS($workdayDuration)) if $l->is_trace();
    }
    my $comments = join(' ', @comments);
    ($benefits, $remote, $startDt, $endDt, $overworkReimbursed, $overworkReimbursedBy, $comments) = RMS::Worklogs::Tags::parseTags($comments);


    #Hope to find some meaningful start time
    if (not($startDt) && $wls[0]->{created_on} =~ /^$dayYMD/) {
        $startDt = DateTime::Format::MySQL->parse_datetime( $wls[0]->{created_on} );
        $startDt->subtract_duration( RMS::Dates::hoursToDuration( $wls[0]->{hours} ) );
        $l->trace("$dayYMD -> Start ".$startDt->hms()) if $l->is_trace();
    }

    #Hope to find some meaningful end time from the last worklog
    if (not($endDt) && $wls[-1]->{created_on} =~ /^$dayYMD/) {
        $endDt = DateTime::Format::MySQL->parse_datetime( $wls[-1]->{created_on} );
        $l->trace("$dayYMD -> End ".$endDt->hms()) if $l->is_trace();
    }


    ($startDt, $underflowDuration) = $class->_verifyStartTime($dayYMD, $startDt, $workdayDuration);
    ($endDt, $overflowDuration) = $class->_verifyEndTime($dayYMD, $startDt, $endDt, $workdayDuration);
    $breaksDuration = $class->_verifyBreaks($dayYMD, $startDt, $endDt, $workdayDuration);

    return RMS::Worklogs::Day->new({
        start => $startDt, end => $endDt, breaks => $breaksDuration, duration => $workdayDuration,
        overflow => $overflowDuration, underflow => $underflowDuration, benefits => $benefits,
        remote => $remote, comments => $comments,
        overworkReimbursed => $overworkReimbursed, overworkReimbursedBy => $overworkReimbursedBy,
        overworkAccumulation => $overworkAccumulation,
    });
}

sub ymd {
    return shift->{ymd};
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
sub overworkAccumulation {
    return shift->{overworkAccumulation};
}
sub overworkReimbursed {
    return shift->{overworkReimbursed};
}
sub overworkReimbursedBy {
    return shift->{overworkReimbursedBy};
}
sub overflow {
    return shift->{overflow};
}
sub underflow {
    return shift->{underflow};
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
If such an underflow event occurs, the underflow duration is returned

@RETURNS (DateTime, $underflowDuration);

=cut

sub _verifyStartTime {
    my ($class, $dayYMD, $startDt, $duration) = @_;

    unless ($startDt) {
        $startDt = DateTime::Format::MySQL->parse_datetime( "$dayYMD 08:00:00" );
        $l->trace("$dayYMD -> Spoofing \$startDt") if $l->is_trace();
    }
    if ($startDt->isa('DateTime::Duration')) {
        $startDt = DateTime::Format::MySQL->parse_datetime( "$dayYMD ".RMS::Dates::formatDurationHMS($startDt) );
    }
    unless ($startDt->ymd('-') eq $dayYMD) { #$startDt might get moved to the previous day, so catch this and fix it.
        $l->trace("$dayYMD -> Moving \$startDt to $dayYMD from ".$startDt->ymd()) if $l->is_trace();
        $startDt = DateTime::Format::MySQL->parse_datetime( "$dayYMD 00:00:00" );
    }

    ##Calculate how many hours is left for today after work
    my $remainder = DateTime::Duration->new(days => 1)->subtract( $duration );

    my $startDuration = $startDt->subtract_datetime(  DateTime::Format::MySQL->parse_datetime( "$dayYMD 00:00:00" )  ); #We get the hours and minutes
    if (DateTime::Duration->compare($remainder, $startDuration, $startDt) >= 0) { #Remainder is bigger than the starting hours, so we have plenty of time today to fill the worktime starting from the given startTime
        return ($startDt, undef);
    }
    #If we started working on the starting time, and we cannot fit the whole workday duration to the current day. So we adjust the starting time to an earlier time.
    $startDuration->subtract($remainder);
    $l->trace("$dayYMD -> Rewinding \$startDt to fit the whole workday ".RMS::Dates::formatDurationHMS($duration)." from ".$startDt->hms().' by '.RMS::Dates::formatDurationHMS($startDuration)) if $l->is_trace();
    $startDt->subtract_duration($startDuration);
    $startDt->subtract_duration(DateTime::Duration->new(seconds => 1)); #remove one minute from midnight so $endDt is not 00:00:00 but 23:59:59 instead
    return ($startDt, $startDuration);
}

=head2 $class->_verifyEndTime

End time defaults to $startTime + workday duration, or the one given
If the given workday duration cannot fit between the given start time and the given end time,
  a comment !END overflow HH:MM:SS! is appended to the workday comments.
@RETURNS (DateTime, $overflowDuration);

=cut

sub _verifyEndTime {
    my ($class, $dayYMD, $startDt, $endDt, $duration) = @_;

    #Create default end time from start + duration
    unless ($endDt) {
        $endDt = $startDt->clone()->add_duration($duration);
        $l->trace("$dayYMD -> Spoofing \$endDt") if $l->is_trace();
    }
    if ($endDt->isa('DateTime::Duration')) {
        $endDt = DateTime::Format::MySQL->parse_datetime( "$dayYMD ".RMS::Dates::formatDurationHMS($endDt) );
    }

    #Check if workday duration fits between start and end.
    if (DateTime->compare($startDt->clone()->add_duration($duration), $endDt) <= 0) {
        return ($endDt, undef);
    }

    #it didn't fit, push end time forward. _verifyStartTime() should make sure this doesn't push the ending date to the next day.
    my $overflowDuration = $startDt->clone()->add_duration($duration)->subtract_datetime($endDt);
    $l->trace("$dayYMD -> Overflowing \$endDt from ".$endDt->hms().' by '.RMS::Dates::formatDurationHMS($overflowDuration)) if $l->is_trace();
    return ($startDt->clone()->add_duration($duration),
            $overflowDuration);
}

sub _verifyBreaks {
    my ($class, $dayYMD, $startDt, $endDt, $duration) = @_;

    my $realDuration = $endDt->subtract_datetime($startDt);
    $realDuration->subtract($duration);
    return $realDuration if (DateTime::Duration->compare($realDuration, DateTime::Duration->new(), $startDt) >= 0); #$realDuration is positive.

    #Break is negative, so $startDt and $endDt are too tight for $duration
    #If duration is -00:00:01 (-1 second) we let it slip, but only this time!
    return $realDuration if (DateTime::Duration->compare($realDuration, DateTime::Duration->new(seconds => -1), $startDt) >= 0); #$realDuration is bigger than -1 seconds.

    confess "\$startDt '".$startDt->iso8601()."' and \$endDt '".$endDt->iso8601()."' is too tight to fit the workday duration '".RMS::Dates::formatDurationPHMS($duration)."'. Break '".RMS::Dates::formatDurationPHMS($realDuration)."' cannot be negative!\n";
}

1;
