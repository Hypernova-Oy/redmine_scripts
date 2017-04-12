use 5.18.2;
use utf8;

package t::lib::Mocks;

use Try::Tiny;
use Scalar::Util qw(blessed);
use Carp;
use autodie;
$Carp::Verbose = 'true'; #die with stack trace

sub RMS_Users_getUser {
    my $p = shift;
    confess("TEST: getUser() parameter 1 not given!") unless $p;
    confess("TEST: getUser() unknown user '$p'. I only know 'testDude || 666'") unless ($p eq 'testDude' || $p == 666);
    return {
        id => 666,
        login => 'testDude',
    };
}

1;
