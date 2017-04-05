package RMS::Dates;

use Modern::Perl;
use Carp;

use DateTime::Format::Duration;
my $dtF_phms = DateTime::Format::Duration->new(
                    pattern => '%p%H:%M:%S',
                    normalise => 'ISO',
                    base => DateTime->now(),
                );
my $dtF_hms = DateTime::Format::Duration->new(
                    pattern => '%H:%M:%S',
                    normalise => 'ISO',
                    base => DateTime->now(),
                );

sub formatDurationPHMS {
    return $dtF_phms->format_duration(shift);
}

sub formatDurationHMS {
    return $dtF_hms->format_duration(shift);
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

    my $duration = DateTime::Duration->new( hours => $h, minutes => $m, seconds => $s || 0 );
    return $duration;
}

1;
