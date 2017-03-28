package RMS::Worklogs::Exporter;

## Omnipresent pragma setter
use Modern::Perl;
use utf8;
use Carp;
use autodie;
$Carp::Verbose = 'true'; #die with stack trace
## Pragmas set

use DateTime::Format::Duration;
use DateTime::Format::Strptime;
use OpenOffice::OODoc;

=head2 new

@PARAM1 {
          worklogDays => RMS::Worklogs->asDays(),
          file => '/tmp/workdays.odf',
        }

=cut

my $dtF_hms = DateTime::Format::Strptime->new(
    pattern   => 'PT%HH%MM%SS',
);
my $ddF_hms = DateTime::Format::Duration->new(
                    pattern => '%PPT%HH%MM%SS',
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
  my $days = $self->{worklogDays};
  my @dates = sort keys %{$days};
  my $dates = $self->_fillMissingDays(\@dates);

#  my $doc = odfDocument(file   => '/tmp/workTime.ods');
  my $doc = odfDocument(file   => '/home/kivilahtio/base.ods');
#  my $doc = odfDocument(file   => $self->{file}, create => 'spreadsheet');
#  my $sheet = $doc->expandTable(0, scalar(@$dates)+10, 10);
#  $doc->renameTable($sheet, $self->{file});
  $doc->normalizeSheet(0);
my $c = $doc->getCell(0, 1, 7);
#my $c = $doc->getCell(0, 3, 2);
#my $s = $doc->textStyle($c);
my %st = $doc->getStyleAttributes('ce2');
my %st = $doc->getStyleAttributes('ce4');
#my $st = $doc->getStyleAttributes('table:style-name ce8');
#my $c = $doc->getCell(0, 2, 2);
#my $c = $doc->getCell(0, 3, 2);
  ##Start building the .ods
  #Print header
  #      table, line, col, value, formatter
  $doc->updateCell(0, 0, 0, 'day', undef);
  $doc->updateCell(0, 0, 1, 'strt', undef);
  $doc->updateCell(0, 0, 2, 'end', undef);
  $doc->updateCell(0, 0, 3, 'brk', undef);
  $doc->updateCell(0, 0, 4, '+/-', undef);
  $doc->updateCell(0, 0, 5, 'dur', undef);
  $doc->updateCell(0, 0, 6, 'cum', undef);
  $doc->updateCell(0, 0, 7, 'rmt?', undef);
  $doc->updateCell(0, 0, 8, 'bnft?', undef);

  my $i=1;
  foreach my $ymd (@$dates) {
    my $n = $i+1;
    my $day = $days->{$ymd};
    my ($c, $v);
    #1
    $c = $doc->getCell(0, $i, 0);
    $doc->cellType($c, 'date');
    $doc->cellStyle($c, 'ce2');
    $v = $ymd;
    $doc->updateCell($c, $v, undef);
    #2
    $c = $doc->getCell(0, $i, 1);
    $doc->cellType($c, 'time');
    $doc->cellStyle($c, 'ce4');
    $v = $day ? $dtF_hms->format_datetime($day->start) : 'PT00H00M00S';
    $doc->updateCell($c, $v, undef);
    #3
    $c = $doc->getCell(0, $i, 2);
    $doc->cellType($c, 'time');
    $doc->cellStyle($c, 'ce4');
    $v = $day ? $dtF_hms->format_datetime($day->end) : 'PT00H00M00S';
    $doc->updateCell($c, $v, undef);
    #4
    $c = $doc->getCell(0, $i, 3);
    $doc->cellType($c, 'time');
    $doc->cellStyle($c, 'ce4');
    $v = $day ? $ddF_hms->format_duration($day->breaks) : 'PT00H00M00S';
    $doc->updateCell($c, $v, undef);
    #5
    $c = $doc->getCell(0, $i, 4);
    $doc->cellType($c, 'time');
    $doc->cellStyle($c, 'ce4');
    $v = $day ? $ddF_hms->format_duration($day->overwork) : 'PT00H00M00S';
    $doc->updateCell($c, $v, undef);
    #6
    $c = $doc->getCell(0, $i, 5);
    $doc->cellType($c, 'time');
    $doc->cellStyle($c, 'ce4');
    $v = "=(C$n-B$n-D$n)";
    $doc->cellFormula($c, $v);
    #7
    $c = $doc->getCell(0, $i, 6);
    $doc->cellType($c, 'time');
    $doc->cellStyle($c, 'ce4');
    $v = "=SUM(F".($i+1).";G".($i+0);
    $doc->cellFormula($c, $v);
    #8
    $c = $doc->getCell(0, $i, 7);
    $doc->cellType($c, 'number');
    $doc->cellStyle($c, 'ce9');
    $v = $day ? $day->remoteWork : undef;
    $doc->updateCell($c, $v);
    #9
    $c = $doc->getCell(0, $i, 8);
    $doc->cellType($c, 'float');
    $doc->cellStyle($c, 'ce9');
    $v = $day ? $day->benefits : undef;
    $doc->updateCell($c, $v);
    $i++;
  }

  $doc->normalizeSheet(0);
  $doc->save($self->{file});
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
