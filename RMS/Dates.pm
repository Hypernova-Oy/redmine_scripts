package RMS::Dates;

use Modern::Perl;
use Carp;
use POSIX;

use DateTime::Format::Duration;
my $dtF_phms = DateTime::Format::Duration->new(
                    pattern => '%p%H:%M:%S',
                    normalise => 1,
                    base => DateTime->now(),
                );
my $dtF_hms = DateTime::Format::Duration->new(
                    pattern => '%H:%M:%S',
                    normalise => 1,
                    base => DateTime->now(),
                );

sub formatDurationPHMS {
    return '+00:00:00' unless $_[0];
    #return $dtF_phms->format_duration(shift);
    my ($positive, $hours, $minutes, $seconds, $sumOfDurationAsSeconds) = durationToPHMSS($_[0]);
    return ($positive ? '+' : '-').sprintf("%02d:%02d:%02d", $hours, $minutes, $seconds);
}

sub formatDurationHMS {
    return '00:00:00' unless $_[0];
    #return $dtF_hms->format_duration(shift);
    #DateTime::Duration cannot deal with days when exporting values in units. So give it a hand and add days as minutes.
    my ($positive, $hours, $minutes, $seconds, $sumOfDurationAsSeconds) = durationToPHMSS($_[0]);
    return sprintf("%02d:%02d:%02d", $hours, $minutes, $seconds);
}

sub formatDurationOdf {
    return '+00:00:00' unless $_[0];
    #return $dtF_phms->format_duration(shift);
    my ($positive, $hours, $minutes, $seconds, $sumOfDurationAsSeconds) = durationToPHMSS($_[0]);
    return ($positive ? '' : '-').sprintf("PT%02dH%02dM%02dS", $hours, $minutes, $seconds);
}

sub hoursToDuration {
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

    my $duration = DateTime::Duration->new( hours => $h, minutes => $m, seconds => ($s ? ceil($s) : 0) );
    return $duration;
}

=head2 durationToHHMM

Turns DateTime::Duration to $hours, $minutes.
DateTime::Duration starts to bug with some complex duration calculations and loses track of it's internal values.
Also the formatting options normalize 24h to 1 day which is undesirable.

@RETURNS ($positive, $hours, $minutes, $seconds, $sumOfDurationAsSeconds)

=cut

sub durationToPHMSS {
    #Flatten time elements, so negatives and positives are summed and we find a reliable way of telling if this Duration is negative or positive
    my $sumSeconds = 0;
    $sumSeconds += $_[0]->{days}*24*3600 if $_[0]->{days};
    $sumSeconds += $_[0]->{hours}*3600   if $_[0]->{hours};
    $sumSeconds += $_[0]->{minutes}*60   if $_[0]->{minutes};
    $sumSeconds += $_[0]->{seconds}      if $_[0]->{seconds};
    my $p;
    if ($sumSeconds >= 0) {
        $p = 1;
        $sumSeconds = ceil($sumSeconds);
    } else {
        $p = 0;
        $sumSeconds = floor($sumSeconds);
    }

    my $secondsNormalized = ($sumSeconds < 0) ? $sumSeconds * -1 : $sumSeconds;
    my $h = int($secondsNormalized/3600);
    my $m = int(($secondsNormalized-$h*3600)/60);
    my $s = int($secondsNormalized - $h*3600 - $m*60);
    return ($p, $h, $m, $s, $sumSeconds);
}

sub dateTimeFromYMD {
    my ($y, $m, $d) = $_[0] =~ /^(\d\d\d\d)-(\d\d)-(\d\d)/;
    die __PACKAGE__."::dateTimeFromYMD($_[0]):> Couldn't parse $_[0]" unless ($y && $m && $d);
    return DateTime->new(year => $y, month => $m, day => $d);
}

my $zeroDuration = DateTime::Duration->new();
sub zeroDuration {
    return $zeroDuration;
}

1;
