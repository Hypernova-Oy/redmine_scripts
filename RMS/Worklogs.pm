package RMS::Worklogs;

use Modern::Perl;
use Carp;

use DateTime;
use DateTime::Format::MySQL;
use DateTime::Duration;
use DateTime::Format::Duration;
use Text::CSV;

use RMS::Context;
use RMS::Worklogs::Day;

my $dtF_hms = DateTime::Format::Duration->new(
                    pattern => '%p%H:%M:%S',
                    normalise => 'ISO',
                    base => DateTime->now(),
                );


sub new {
    my ($class, $params) = @_;

    my $self = {params => $params};
    bless($self, $class);
    return $self;
}

sub worklogs {
    my ($self) = @_;
    return $self->{worklogs} if $self->{worklogs};
    return $self->getWorklogs();
}
sub getWorklogs {
    my ($self) = @_;

    my $dbh = RMS::Context->dbh();
    my $sth = $dbh->prepare("SELECT spent_on, created_on, hours FROM time_entries WHERE user_id = ? ORDER BY spent_on ASC, created_on ASC");
    $sth->execute($self->param('user_id'));
    $self->{worklogs} = $sth->fetchall_arrayref({});
    return $self->{worklogs};
}

sub asDays () {
    my ($self) = @_;

    my $dailies = $self->_flattenDays();
    return $self->_calculateDays($dailies);
}

sub asCsv {
    my ($self, $filePath) = @_;
    my $days = $self->asDays();

    my $csv = Text::CSV->new or die "Cannot use CSV: ".Text::CSV->error_diag ();
    $csv->eol("\n");
    open my $fh, ">:encoding(utf8)", $filePath or die "$filePath: $!";

    my @dates = sort keys %{$days};
    my $dates = $self->_fillMissingDays(\@dates);

    foreach my $ymd (@$dates) {
        my $day = $days->{$ymd};
        my $row;
        if ($day) {
            $row = [
                $ymd,
                $day->start->hms,
                $day->end->hms,
                $dtF_hms->format_duration($day->breaks),
                $dtF_hms->format_duration($day->duration),
                $dtF_hms->format_duration($day->overwork),
            ];
        }
        else {
            $days->{$ymd} = undef;
            $row = [
                $ymd,
                undef, undef, undef, undef, undef,
            ];
        }
        $csv->print($fh, $row);
    }

    close $fh or die "$filePath: $!";
    return $days;
}

sub params {
    return shift->{params};
}
sub param {
    my ($self, $param) = @_;
    unless (defined($self->{params}->{$param})) {
        my @cc = caller(1);
        confess $cc[3]."():> No such \$param '$param'";
    }
    return $self->{params}->{$param};
}

sub _flattenDays {
    my ($self) = @_;
    my $worklogs = $self->worklogs;

    my %dailies;
    foreach my $worklog (@$worklogs) {
        $dailies{ $worklog->{spent_on} } = [] unless $dailies{ $worklog->{spent_on} };
        push(@{$dailies{ $worklog->{spent_on} }}, $worklog);
    }
    return \%dailies;
}

sub _calculateDays {
    my ($self, $dailies) = @_;

    my %days;
    foreach my $ymd (sort keys %$dailies) {
        my $worklogs = $dailies->{$ymd};
        my $day = $self->_calculateDay($ymd, $worklogs);
        $days{ $day->day() } = $day;
    }
    return \%days;
}
sub _calculateDay {
    my ($class, $day, $worklogs) = @_;
    #print "$day\n";
    my ($startDt, $endDt, $breaksDuration, $workdayDuration);
    my @wls = sort {$a->{created_on} cmp $b->{created_on}} @$worklogs; #Sort from morning to evening, so first index is the earliest log entry

    if ($wls[0]->{created_on} =~ /^$day/) { #Hope to find some meaningful start time
        $startDt = DateTime::Format::MySQL->parse_datetime( $wls[0]->{created_on} );
        $startDt->subtract_duration( _hoursToDuration( $wls[0]->{hours} ) );
    }

    $workdayDuration = DateTime::Duration->new();
    foreach my $wl (@wls) { #Sum the separate worklog entries
        $workdayDuration->add_duration(_hoursToDuration( $wl->{hours} ));
        if ($wl->{created_on} =~ /^$day/) { #Hope to find some meaningful end time
            $endDt = DateTime::Format::MySQL->parse_datetime( $wl->{created_on} );
        }
    }

    $startDt = $class->_verifyStartTime($day, $startDt, $workdayDuration);
    $endDt = $class->_verifyEndTime($day, $startDt, $endDt, $workdayDuration);
    $breaksDuration = $class->_verifyBreaks($day, $startDt, $endDt, $workdayDuration);

    return RMS::Worklogs::Day->new($startDt, $endDt, $breaksDuration, $workdayDuration);
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
    unless ($day =~ /^\d\d\d\d-\d\d-\d\d$/) {
        confess "\$day '$day' is not a proper YYYY-MM-DD date";
    }

    unless ($startDt) {
        $startDt = DateTime::Format::MySQL->parse_datetime( "$day 08:00:00" );
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

=cut

sub _verifyEndTime {
    my ($class, $day, $startDt, $endDt, $duration) = @_;

    #Create default end time from start + duration
    unless ($endDt) {
        $endDt = $startDt->clone()->add_duration($duration);
    }

    #Check if workday duration fits between start and end.
    if (DateTime->compare($startDt->clone()->add_duration($duration), $endDt) <= 0) {
        return $endDt;
    }

    #it didn't fit, push end time forward. _verifyStartTime() should make sure this doesn't push the ending date to the next day.
    return $startDt->clone()->add_duration($duration);
}

sub _verifyBreaks {
    my ($class, $day, $startDt, $endDt, $duration) = @_;

    my $realDuration = $endDt->subtract_datetime($startDt);
    $realDuration->subtract($duration);
    return $realDuration if (DateTime::Duration->compare($realDuration, DateTime::Duration->new(), $startDt) >= 0); #$realDuration is positive.

    #Break is negative, so $startDt and $endDt are too tight for $duration
    #If duration is -00:00:01 (-1 second) we let it slip, but only this time!
    return $realDuration if (DateTime::Duration->compare($realDuration, DateTime::Duration->new(seconds => -1), $startDt) >= 0); #$realDuration is bigger than -1 seconds.

    confess "\$startDt '".$startDt->iso8601()."' and \$endDt '".$endDt->iso8601()."' is too tight to fit the workday duration '".$dtF_hms->format_duration($duration)."'. Break '".$dtF_hms->format_duration($realDuration)."' cannot be negative!\n";
}

sub _hoursToDuration {
    my ($hours) = @_;

    my $splitDecimalDivisibleBy60 = sub {
        my ($a, $b) = @_;
        my ($x, $y);
        $x = $a || 0;
        $y = "0.$b";
        $y = $y*60 if $y;
        $y = 0 unless $y;
        return ($x, $y);
    };

    my ($h, $m, $s);
    if ($hours =~ /^(\d+)[.,]?(\d*)$/) {
        ($h, $m) = &$splitDecimalDivisibleBy60($1, $2);
    }
    elsif ($hours =~ /\d+e-\d+/) { #1e-07, exponential stringification of a number :(
        ($h, $m, $s) = (0, 0, 1);
    }
    else {
        confess "Couldn't parse hours '$hours'";
    }
    if ($m) {
        if ($m =~ /^(\d+)[.,]?(\d*)$/) {
            ($m, $s) = &$splitDecimalDivisibleBy60($1, $2);
        }
        elsif ($m =~ /\d+e-\d+/) { #1e-07, exponential stringification of a number :(
            ($m, $s) = (0, 1);
        }
        else {
            confess "Couldn't parse minutes '$m'";
        }
    }

    my $duration = DateTime::Duration->new( hours => $h, minutes => $m, seconds => $s || 0 );
    return $duration;
}

=head2 $class->_fillMissingDays

Fill days between the first and last workday that don't have any worklogs with empty values

=cut

sub _fillMissingDays {
    my ($class, $ymds) = @_;

    my @ymds;
    for (my $i=0 ; $i<scalar(@$ymds) ; $i++) {
        my $a = DateTime::Format::MySQL->parse_datetime( $ymds->[$i].' 00:00:00' );
        my $b = DateTime::Format::MySQL->parse_datetime( $ymds->[$i+1].' 00:00:00' ) if $ymds->[$i+1];

        do {
            push(@ymds, $a->ymd());
            $a->add_duration( DateTime::Duration->new(days => 1) );
        } while ($b && $a < $b);
    }
    return \@ymds;
}

1;
