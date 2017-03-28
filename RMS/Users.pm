package RMS::Worklogs;

use Modern::Perl;
use Carp;

use RMS::Context;

sub new {
    my ($class, $params) = @_;

    my $self = {params => $params};
    bless($self, $class);
    return $self;
}

sub getUser {
    my ($self, $userid, $username) = @_;
    return $self->{users}->{$userid || $username} if ($self->{users} && $self->{users}->{$userid || $username});

    my $dbh = RMS::Context->dbh();
    my $sth = $dbh->prepare("SELECT * FROM users WHERE login = ? OR id = ?");
    $sth->execute($self->param('user_id'));
    my $users = $sth->fetchall_arrayref({});
    die "getUser():> Too many results with ".($userid || '')." or ".($username || '') if (scalar(@$users) > 1);
    die "getUser():> No results with ".($userid || '')." or ".($username || '') unless (scalar(@$users));
    return $self->{users}->{$userid || $username} = shift @$users;
}

1;
