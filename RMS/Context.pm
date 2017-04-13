package RMS::Context;

use Modern::Perl;

use DBI;

my $config;
sub getConfig {
    if (-e '/etc/redmine_scripts/rms.conf') {
        $config = require '/etc/redmine_scripts/rms.conf';
    }
    elsif (-e 'config/rms.conf') {
        $config = require 'config/rms.conf';
    }
    else {
        die "No valid configuration file present";
    }
}

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
    $config = getConfig() unless $config;
    DBI->connect($dsn, $config->{db_user}, $config->{db_pass}, {mysql_enable_utf8 => 1});
}

1;
