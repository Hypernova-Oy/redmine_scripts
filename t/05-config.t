#/usr/bin/perl

#Set pragmas
use 5.18.2;
use utf8;
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");
binmode(STDIN, ":utf8");
use Carp;
use autodie;
$Carp::Verbose = 'true'; #die with stack trace
#Pragmas set

use Test::More;

use RMS::Context;

ok(my $config = RMS::Context::getConfig(), "Given a config");
is($config->{db_user}, 'set this up', "db_user key exsts");
is($config->{db_pass}, 'set this up', "db_pass key exsts");

done_testing();
