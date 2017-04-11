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
    $l->info("Getting worklogs for user ".$self->param('user')) if $l->is_info();

    my $user = RMS::Users::getUser($self->param('user'));
    my $dbh = RMS::Context->dbh();
    my $sth = $dbh->prepare("SELECT spent_on, created_on, hours, comments, issue_id, user_id, e.name as activity FROM time_entries te LEFT JOIN enumerations e ON te.activity_id = e.id WHERE user_id = ? ORDER BY spent_on ASC, created_on ASC");
    $sth->execute($user->{id});
    $self->{worklogs} = $sth->fetchall_arrayref({});
    $l->info("Found '".($self->{worklogs} ? scalar(@{$self->{worklogs}}) : 0)."'worklogs for user ".$self->param('user')) if $l->is_info();
    return $self->{worklogs};
}

sub getWorklogsForYear {
    my ($self) = @_;
    $l->info("Getting worklogs for user ".$self->param('user')) if $l->is_info();

    my $user = RMS::Users::getUser($self->param('user'));
    my $dbh = RMS::Context->dbh();
    my $sth = $dbh->prepare(
        "SELECT spent_on, created_on, hours, comments, issue_id, user_id, e.name as activity \n".
        "FROM time_entries te \n".
        "    LEFT JOIN enumerations e ON te.activity_id = e.id \n".
        "WHERE user_id = ? \n".
        "    AND spent_on >= ? \n".
        "    AND spent_on <= ? \n".
        "ORDER BY spent_on ASC, created_on ASC"
    );
    $sth->execute($user->{id},
                  $self->param('year').' 00:00:00',
                  $self->param('year').' 23:59:59'
    );
    $self->{worklogs} = $sth->fetchall_arrayref({});
    $l->info("Found '".($self->{worklogs} ? scalar(@{$self->{worklogs}}) : 0)."'worklogs for user ".$self->param('user')) if $l->is_info();
    return $self->{worklogs};
}

sub asDays () {
    my ($self) = @_;

    return $self->{worklogDays} if $self->{worklogDays};
    my $dailies = $self->_flattenDays();
    $self->{worklogDays} = $self->_calculateDays($dailies);
    return $self->{worklogDays};
}

sub asOds {
    my ($self, $filePath) = @_;
    return RMS::Worklogs::Exporter->new({year => $self->param('year'), file => $filePath, worklogDays => $self->asDays()})->asOds;
}

sub asCsv {
    my ($self, $filePath) = @_;
    return RMS::Worklogs::Exporter->new({year => $self->param('year'), file => $filePath, worklogDays => $self->asDays()})->asCsv;
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
    my $prevOverworkAccumulation;
    my $prevVacationAccumulation;
    foreach my $ymd (sort keys %$dailies) {
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

1;
