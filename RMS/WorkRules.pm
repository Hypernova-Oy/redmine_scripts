package RMS::WorkRules;

use Modern::Perl;
use Carp;

sub new {
  my ($class, $params) = @_;

  my $self = {params => $params};
  bless($self, $class);
  return $self;
}

sub _loadStaticDefaults {
  return {
    '2015' => {
      since => '2015-01-01',
      dailyHours => 7.25,
    },
    '2017' => {
      '02' => {
        since => '2017-02-01',
        dailyHours =>  7.35,
      },
    },
  };
}

sub getRuleForDatetime {
  my ($self, $dt) = @_;

  
}

1;
