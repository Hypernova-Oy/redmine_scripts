package RMS::Worklogs::Day;

use Modern::Perl;

use DateTime::Duration;

my $dayLength = DateTime::Duration->new(hours => 7, minutes => 15);

sub new {
    my ($class, $startDt, $endDt, $breakDuration, $workdayDuration) = @_;

    my $self = {
        start => $startDt,
        end => $endDt,
        breaks => $breakDuration,
        duration => $workdayDuration,
    };

    bless($self, $class);
    return $self;
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
    return shift->duration->clone->subtract($dayLength);
}
sub remoteWork {
    return shift->{remoteWork};
}
sub benefits {
    return 1 || shift->{benefits};
}

1;
