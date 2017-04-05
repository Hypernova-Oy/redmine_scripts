package RMS::Worklogs;

use Modern::Perl;
use Carp;

use DateTime;
use DateTime::Format::MySQL;
use DateTime::Duration;
use Text::CSV;

use RMS::Context;
use RMS::Dates;
use RMS::Worklogs::Day;
use RMS::Worklogs::Exporter;
use RMS::Users;

use RMS::Logger;
my $l = bless({}, 'RMS::Logger');

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

    my $user = RMS::Users::getUser($self->param('user'));
    my $dbh = RMS::Context->dbh();
    my $sth = $dbh->prepare("SELECT spent_on, created_on, hours, comments FROM time_entries WHERE user_id = ? ORDER BY spent_on ASC, created_on ASC");
    $sth->execute($user->{id});
    $self->{worklogs} = $sth->fetchall_arrayref({});
    return $self->{worklogs};
}

sub asDays () {
    my ($self) = @_;

    my $dailies = $self->_flattenDays();
    return $self->_calculateDays($dailies);
}

sub asOds {
    my ($self, $filePath) = @_;
    return RMS::Worklogs::Exporter->new({file => $filePath, worklogDays => $self->asDays()})->asOds;
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
                RMS::Dates::formatDurationPHMS($day->breaks),
                RMS::Dates::formatDurationPHMS($day->duration),
                RMS::Dates::formatDurationPHMS($day->overwork),
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
        my $day = RMS::Worklogs::Day->newFromWorklogs($ymd, $worklogs);
        $days{ $day->day() } = $day;
    }
    return \%days;
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
