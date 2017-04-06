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
use ODF::lpOD;

use RMS::Logger;
my $l = bless({}, 'RMS::Logger');

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
    baseOds => 'base4.ods',
  };

  bless($self, $class);
  return $self;
}

sub asOds {
  my ($self) = @_;
  my $days = $self->{worklogDays};
  my @dates = sort keys %{$days};
  my $dates = $self->_fillMissingDays(\@dates);

  my $rowsPerMonth = 40;

  #Load document and write metadata
  my $doc = odf_document->get( $self->{baseOds} );
  my $meta = $doc->meta;
  $meta->set_title('Työaika kivajuttu');
  $meta->set_creator('Olli-Antti Kivilahti');
  $meta->set_keywords('Koha-Suomi', 'Työajanseuranta');

  my $t = $doc->get_body->get_table_by_name('_data_');
  _checksAndVerifications($t);
  ##Make sure the _data_-sheet is big enough (but not too big)
  #We put each day in monthly chunks to the _data_-sheet with ample spacing between months.
  #So roughly 40 rows per months should do it cleanly.
  my ($neededHeight, $neededWidth) = ($rowsPerMonth*12, 20);
  my ($height, $width) = $t->get_size();
  if ($height < $neededHeight) {
    $l->debug("Base .ods '".$self->{baseOds}."' is lower '$height' than needed '$neededHeight'") if $l->is_debug();
    $t->add_row(number => $neededHeight-$height);
  }
  elsif ($height > $neededHeight) {
    $l->error("Base .ods '".$self->{baseOds}."' is higher '$height' than needed '$neededHeight'. This has performance implications.") if $l->is_error();
    $t->delete_row(-1) for 1..($height-$neededHeight);
  }
  if ($width < $neededWidth) {
    $l->debug("Base .ods '".$self->{baseOds}."' is narrower '$width' than needed '$neededWidth'") if $l->is_debug();
    $t->add_column(number => $neededWidth-$width);
  }
  elsif ($width > $neededWidth) {
    $l->error("Base .ods '".$self->{baseOds}."' is wider '$width' than needed '$neededWidth'. This has performance implications.") if $l->is_error();
    $t->delete_column(-1) for 1..($width-$neededWidth);
  }

  my ($prevY, $prevM, $prevD);
  my $rowNumber = 0;
  my $rowPointer = \$rowNumber;

  foreach my $ymd (@$dates) {
    my $day = $days->{$ymd};
    my ($y, $m, $d) = $ymd =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/;
    #Check if the month changes, so we reorient the pointer
    if (not($prevM) || $m ne $prevM) {
      _startMonth($t, $rowPointer, $y, $m, $d, $rowsPerMonth);
    }
    _writeDay($t, $rowPointer, $ymd, $day);

    ($prevY, $prevM, $prevD) = ($y, $m, $d);
    $$rowPointer++;
  }

  $doc->save(target => $self->{file});
  $doc->forget();
  return $self->{file};
}

sub _checksAndVerifications {
  my ($t) = @_;

  $l->fatal("'date' is not a known ODF datatype") unless is_odf_datatype('date');
  $l->fatal("'time' is not a known ODF datatype") unless is_odf_datatype('time');
  $l->fatal("'boolean' is not a known ODF datatype") unless is_odf_datatype('boolean');
  $l->fatal("'string' is not a known ODF datatype") unless is_odf_datatype('string');
}

sub _startMonth {
  my ($t, $rowPointer, $y, $m, $d, $rowsPerMonth) = @_;

  #Calculate from where the next month begins
  my $rowsUsedDuringPrevMonth = $$rowPointer % $rowsPerMonth;
  my $neededToNextMonthStart = $rowsPerMonth - $rowsUsedDuringPrevMonth;
  $l->debug("Starting a new month '$y-$m-$d' on row '$$rowPointer'. Rows preserved for month '$rowsPerMonth'. Rows used during the last month '$rowsUsedDuringPrevMonth'. Skipping '$neededToNextMonthStart' rows forward to start a new month.") if $l->is_debug;
  $$rowPointer += $neededToNextMonthStart if $rowsUsedDuringPrevMonth;

  my $c;
  #            row,       col, value, formatter
  $c = $t->get_cell($$rowPointer, 0);$c->set_type('string');$c->set_value('day');
  $c = $t->get_cell($$rowPointer, 1);$c->set_type('string');$c->set_value('strt');
  $c = $t->get_cell($$rowPointer, 2);$c->set_type('string');$c->set_value('end');
  $c = $t->get_cell($$rowPointer, 3);$c->set_type('string');$c->set_value('brk');
  $c = $t->get_cell($$rowPointer, 4);$c->set_type('string');$c->set_value('+/-');
  $c = $t->get_cell($$rowPointer, 5);$c->set_type('string');$c->set_value('dur');
  $c = $t->get_cell($$rowPointer, 6);$c->set_type('string');$c->set_value('cum');
  $c = $t->get_cell($$rowPointer, 7);$c->set_type('string');$c->set_value('rmt?');
  $c = $t->get_cell($$rowPointer, 8);$c->set_type('string');$c->set_value('bnft?');
  $$rowPointer++;
}
my $lastKnownOverworkAccumulation;
sub _writeDay {
  my ($t, $rowPointer, $ymd, $day) = @_;
  $lastKnownOverworkAccumulation = $day->overworkAccumulation if $day && $day->overworkAccumulation;

  my ($c, $v);
  #1 - day
  $c = $t->get_cell($$rowPointer, 0);$c->set_type('date');$c->set_value($ymd);
  #2 - start
  $c = $t->get_cell($$rowPointer, 1);$c->set_type('time');$c->set_value(  $day ? $dtF_hms->format_datetime($day->start) : 'PT00H00M00S'  );
  #3 - end
  $c = $t->get_cell($$rowPointer, 2);$c->set_type('time');$c->set_value(  $day ? $dtF_hms->format_datetime($day->end) : 'PT00H00M00S'  );
  #4 - break
  $c = $t->get_cell($$rowPointer, 3);$c->set_type('time');$c->set_value(  $day ? $ddF_hms->format_duration($day->breaks) : 'PT00H00M00S'  );
  #5 - +/-
  $c = $t->get_cell($$rowPointer, 4);$c->set_type('time');$c->set_value(  $day ? $ddF_hms->format_duration($day->overwork) : 'PT00H00M00S'  );
  #6 - duration
  $c = $t->get_cell($$rowPointer, 5);$c->set_type('time');$c->set_value(  $day ? $ddF_hms->format_duration($day->duration) : 'PT00H00M00S'  );
  #7 - overworkAccumulation
  $c = $t->get_cell($$rowPointer, 6);$c->set_type('time');$c->set_value(  $day ? $ddF_hms->format_duration($day->overworkAccumulation) : $ddF_hms->format_duration($lastKnownOverworkAccumulation)  );
  #8 - remote?
  $c = $t->get_cell($$rowPointer, 7);$c->set_type('boolean');$c->set_value(  odf_boolean($day ? $day->remote : undef)  );
  #9 - benefits?
  $c = $t->get_cell($$rowPointer, 8);$c->set_type('boolean');$c->set_value(  odf_boolean($day ? $day->benefits : undef)  );

  $l->debug("$$rowPointer: $ymd - ".($day ? $day : 'undef')) if $l->is_debug();
}
=head
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
    $v = $day ? $day->remote : undef;
    $doc->updateCell($c, $v);
    #9
    $c = $doc->getCell(0, $i, 8);
    $doc->cellType($c, 'float');
    $doc->cellStyle($c, 'ce9');
    $v = $day ? $day->benefits : undef;
    $doc->updateCell($c, $v);

    $l->debug("$i: $ymd - ".($day ? $day : 'undef')) if $l->is_debug();
    $i++;
  }

  $doc->normalizeSheet(0, 'full');
  $doc->save(target => $self->{file});
  $doc->forget();
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
