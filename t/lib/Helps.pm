use 5.18.2;
use utf8;
use Try::Tiny;
use Scalar::Util qw(blessed);
use Carp;
use autodie;
$Carp::Verbose = 'true'; #die with stack trace


package t::lib::Helps;

=head2 runPerlScript

Executes a perl script as a part of this running test suite. Respecting mocked subroutines.

=cut

sub runPerlScript {
    my ($scriptPath, $cliArgs) = @_;
    @ARGV = @$cliArgs;    #Set cli params for GetOpt::Long
    unless (my $return = do $scriptPath) {  #Basically executes the script in this running program's context
        die "couldn't parse $scriptPath: $@" if $@;
        die "couldn't do $scriptPath: $!"    unless defined $return;
        die "couldn't run $scriptPath"       unless $return;
    }
}

=head2 worklogDefault

Inject default keys to a bunch of time_entry-rows

=cut

sub worklogDefault {
    my ($wls, $defaults) = @_;
    foreach my $wl (@$wls) { #Append defaults for each time_entry
        foreach my $key (keys %$defaults) {
            $wl->{$key} = $defaults->{$key} unless $wl->{$key};
        }
    }
}