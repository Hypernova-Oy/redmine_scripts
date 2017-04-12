package RMS::Worklogs;

use Modern::Perl;
use Carp;
use Params::Validate qw(:all);

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


=head2 new

@PARAM1 HASHRef of params:
    {
        user => 1 || 'kivilahtio', #userid or login name of the Redmine user to extract worklogs for
        year => undef || 2017,     #Year to extract.
    }

=cut

our %validations = (
    user     =>   {type => SCALAR},
    year     =>   {type => SCALAR|UNDEF, optional => 1},
);
sub new {
    my ($class) = shift;
    my $params = validate(@_, \%validations);

    my $self = {
        user => RMS::Users::getUser($params->{user}),
        year => $params->{year},
    };
    bless($self, $class);
    return $self;
}

####  OBJECT ACCESSORS   ####

sub user {
    return shift->{user};
}
sub userLogin {
    return shift->{user}->{login};
}
sub year {
    return shift->{year};
}

####  EO OBJECT ACCESSORS  ####



sub worklogs {
    my ($self) = @_;
    return $self->{worklogs} if $self->{worklogs};
    return $self->getWorklogs();
}
sub getWorklogs {
    my ($self) = @_;
    $l->info("Getting worklogs for user ".$self->userLogin) if $l->is_info();

    my $dbh = RMS::Context->dbh();
    ##                       WHEN adding/removing new columns to this list, remember to add defaults to $self->fillMissingTimeEntries() !! ##
    my $sth = $dbh->prepare("SELECT spent_on, created_on, hours, comments, issue_id, user_id, e.name as activity FROM time_entries te LEFT JOIN enumerations e ON te.activity_id = e.id WHERE user_id = ? ORDER BY spent_on ASC, created_on ASC");
    $sth->execute($self->user->{id});
    $self->{worklogs} = $sth->fetchall_arrayref({});
    $l->info("Found '".($self->{worklogs} ? scalar(@{$self->{worklogs}}) : 0)."'worklogs for user ".$self->userLogin) if $l->is_info();
    return $self->{worklogs};
}

sub getWorklogsForYear {
    my ($self) = @_;
    $l->info("Getting worklogs for user ".$self->userLogin) if $l->is_info();

    my $dbh = RMS::Context->dbh();
    ##                       WHEN adding/removing new columns to this list, remember to add defaults to $self->fillMissingTimeEntries() !! ##
    my $sth = $dbh->prepare(
        "SELECT spent_on, created_on, hours, comments, issue_id, user_id, e.name as activity \n".
        "FROM time_entries te \n".
        "    LEFT JOIN enumerations e ON te.activity_id = e.id \n".
        "WHERE user_id = ? \n".
        "    AND spent_on >= ? \n".
        "    AND spent_on <= ? \n".
        "ORDER BY spent_on ASC, created_on ASC"
    );
    $sth->execute($self->user->{id},
                  $self->year.' 00:00:00',
                  $self->year.' 23:59:59'
    );
    $self->{worklogs} = $sth->fetchall_arrayref({});
    $l->info("Found '".($self->{worklogs} ? scalar(@{$self->{worklogs}}) : 0)."'worklogs for user ".$self->userLogin) if $l->is_info();
    return $self->{worklogs};
}

sub asDays () {
    my ($self) = @_;

    return $self->{worklogDays} if $self->{worklogDays};
    my $filledTimeEntries = fillMissingTimeEntries($self->worklogs);
    my $dailies = $self->_flattenDays($filledTimeEntries);
    $self->{worklogDays} = $self->_calculateDays($dailies);
    return $self->{worklogDays};
}

sub asOds {
    my ($self, $filePath) = @_;
    return RMS::Worklogs::Exporter->new({year => $self->year, file => $filePath, worklogDays => $self->asDays(), user => $self->user})->asOds;
}

sub asCsv {
    my ($self, $filePath) = @_;
    return RMS::Worklogs::Exporter->new({year => $self->year, file => $filePath, worklogDays => $self->asDays(), user => $self->user})->asCsv;
}

sub _flattenDays {
    my ($self, $worklogs) = @_;

    my %dailies;
    foreach my $worklog (@$worklogs) {
        $dailies{ $worklog->{spent_on} } = [] unless $dailies{ $worklog->{spent_on} };
        push(@{$dailies{ $worklog->{spent_on} }}, $worklog);
    }
    return \%dailies;
}

sub _calculateDays {
    my ($self, $dailies) = @_;

    my @ymds = sort keys %$dailies;
    my %days;

    my $prevOverworkAccumulation;
    my $prevVacationAccumulation;

    #Calculate previous vacations moving to this work contract
    my $prevVacationDays = RMS::WorkRules::getVacationsFromPriorContracts($self->user->{id});
    if ($prevVacationDays) {
        my $firstWorkDayDt = RMS::Dates::dateTimeFromYMD(    $dailies->{ $ymds[0] }->[0]->{spent_on}    );
        my $prevVacationDayLength = RMS::WorkRules::getDayLengthDd($firstWorkDayDt);
        $prevVacationAccumulation = $prevVacationDayLength->clone()->multiply($prevVacationDays);
    }

    foreach my $ymd (@ymds) {
        $l->info("Creating day '$ymd'") if $l->is_info();
        my $worklogs = $dailies->{$ymd};
        my $day = RMS::Worklogs::Day->newFromWorklogs($ymd,
                                                      $prevOverworkAccumulation || DateTime::Duration->new(),
                                                      $prevVacationAccumulation || DateTime::Duration->new(),
                                                      $worklogs);
        $days{ $day->day() } = $day;
        $prevOverworkAccumulation = $day->overworkAccumulation();
        $prevVacationAccumulation = $day->vacationAccumulation();
    }
    return \%days;
}

=head2 $class->fillMissingTimeEntries

Fills any days missing between the first and the last day in the given HASHRef of time_entries with blank time_entries

@PARAM1 ARRAYRef of HASHRef of redmine.time_entry-rows
@RETURNS ARRAYRef of HashRef of redmine.time_entry-rows with empty days filled with empty defaults, keyed with String YYYY-MM-DD

=cut

my $oneDayDd = DateTime::Duration->new(days => 1);
sub fillMissingTimeEntries {
    my ($timeEntries) = @_;

    my @timeEntries;
    for (my $i=0 ; $i<scalar(@$timeEntries) ; $i++) {
        my $a = $timeEntries->[$i];
        my $b = $timeEntries->[$i+1] if $timeEntries->[$i+1];

        push(@timeEntries, $a);

        my $nextDay = DateTime::Format::MySQL->parse_datetime( $a->{spent_on}.' 00:00:00' )->add_duration( $oneDayDd );
        my $nextDayYMD = $nextDay->ymd;
        while ($b && not($nextDayYMD ge $b->{spent_on})) {
            $l->trace("time_entry filling with date='$nextDayYMD', from='".$a->{spent_on}."', to='".$b->{spent_on}."'") if $l->is_trace();
            push(@timeEntries, {
                spent_on => $nextDayYMD,
                created_on => "$nextDayYMD 00:00:00",
                hours => 0,
                comments => '',
                issue_id => 0,
                user_id => $a->{user_id},
                activity => '',
            });
            $nextDay->add_duration( $oneDayDd );
            $nextDayYMD = $nextDay->ymd;
        }
    }
    return \@timeEntries;
}

1;
