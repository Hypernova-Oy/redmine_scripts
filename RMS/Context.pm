package RMS::Context;

use Modern::Perl;

use DBI;

my $dbh;
my $dsn = "DBI:mysql:database=redmine;host=localhost;port=3306";
sub dbh {
    if ($dbh) {
        unless ($dbh->ping()) {
            return _dbh_connect($dbh);
        }
    }

    $dbh = _dbh_connect();
    return $dbh;
}
sub _dbh_connect {
    DBI->connect($dsn, 'redmine', 'red is mine');
}

1;
