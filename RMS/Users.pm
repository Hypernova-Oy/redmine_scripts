## Omnipresent pragma setter
use 5.18.2;
use utf8;
use Carp;
use autodie;
$Carp::Verbose = 'true'; #die with stack trace
## Pragmas set

package RMS::Users;

use RMS::Context;

sub getUser {
    my ($useridOrName) = @_;

    my $dbh = RMS::Context->dbh();
    my $sth = $dbh->prepare("SELECT * FROM users WHERE login = ? OR id = ?");
    $sth->execute($useridOrName, $useridOrName);
    my $users = $sth->fetchall_arrayref({});
    die "getUser():> Too many results with ".($useridOrName || '') if (scalar(@$users) > 1);
    die "getUser():> No results with ".($useridOrName || '') unless (scalar(@$users));
    return shift @$users;
}

1;
