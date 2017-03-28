package RMS::Worklogs::Exporter;

## Omnipresent pragma setter
use Modern::Perl;
use utf8;
use Carp;
use autodie;
$Carp::Verbose = 'true'; #die with stack trace
## Pragmas set

use OpenOffice::OODoc;

=head2 new

@PARAM1 {
          worklogDays => RMS::Worklogs->asDays(),
          file => '/tmp/workdays.odf',
        }

=cut

my $dtF_hms = DateTime::Format::Duration->new(
                    pattern => '%p%H:%M:%S',
                    normalise => 'ISO',
                    base => DateTime->now(),
                );

sub new {
  my ($class, $params) = @_;

  my $self = {
    worklogDays => $params->{worklogDays},
    file => $params->{file},
  };

  bless($self, $class);
  return $self;
}

sub asOds {
  my ($self) = @_;

  my $doc = odfDocument(file => $self->{file},
                        class => 'spreadsheet');

  my $days = $self->{worklogDays};
  my @dates = sort keys %{$days};
  my $dates = $self->_fillMissingDays(\@dates);

  ##Start building the .ods
  #Print header
  #      table, line, col, value, formatter
  $doc->updateCell(1, 1, 1, 'day', undef);
  $doc->updateCell(1, 1, 2, 'start', undef);
  $doc->updateCell(1, 1, 3, 'end', undef);
  $doc->updateCell(1, 1, 4, 'breaks', undef);
  $doc->updateCell(1, 1, 5, '+/-', undef);
  $doc->updateCell(1, 1, 6, 'duration', undef);
  $doc->updateCell(1, 1, 7, 'cumulator', undef);

  my $i=0;
  foreach my $ymd (@$dates) {
    $i++;
    my $day = $days->{$ymd};
    my $row;
    if ($day) {
      $doc->updateCell(1, $i, 1, $ymd, undef);
      $doc->updateCell(1, $i, 2, $day->start->hms, undef);
      $doc->updateCell(1, $i, 1, $day->end->hms, undef);
      $doc->updateCell(1, $i, 1, $dtF_hms->format_duration($day->breaks), undef);
      $doc->updateCell(1, $i, 1, $dtF_hms->format_duration($day->overwork), undef);
      $doc->updateCell(1, $i, 1, $dtF_hms->format_duration($day->duration), undef);
      $doc->updateCell(1, $i, 1, "=SUM(${i}F,${i}G)", undef);
    }
    else {
      $days->{$ymd} = undef;
      $doc->updateCell(1, $i, 1, $ymd, undef);
    }
  }

  $doc->save();
  return $self->{file};
}

=head2 $class->_fillMissingDays

Fill days between the first and last workday that don't have any worklogs with empty values

=cut

sub _fillMissingDays {
    my ($class, $ymds) = @_;

    my @ymds;
    for (my $i=0 ; $i<scalar(@$ymds) ; $i++) {
        my $a = DateTime::Format::MySQL->parse_datetime( $ymds->[$i].' 00:00:00' );
        my $b = DateTime::Format::MySQL->parse_datetime( $ymds->[$i+1].' 00:00:00' ) if $ymds->[$i+1];

        do {
            push(@ymds, $a->ymd());
            $a->add_duration( DateTime::Duration->new(days => 1) );
        } while ($b && $a < $b);
    }
    return \@ymds;
}

1;
