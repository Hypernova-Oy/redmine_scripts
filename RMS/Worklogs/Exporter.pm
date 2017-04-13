package RMS::Worklogs::Exporter;

## Omnipresent pragma setter
use 5.18.2;
use utf8;
use Carp;
use autodie;
$Carp::Verbose = 'true'; #die with stack trace
use Try::Tiny;
use Scalar::Util qw(blessed);
## Pragmas set

use DateTime::Format::Duration;
use DateTime::Format::Strptime;
use ODF::lpOD;

use RMS::Dates;
use RMS::Worklogs::Day;
use RMS::Logger;
my $l = bless({}, 'RMS::Logger');

=head2 new

@PARAM1 {
          worklogDays => RMS::Worklogs->asDays(),
          file => '/tmp/workdays',                      #suffix is appended based on the exported type
          year => 2017,
        }

=cut

my $dtF_hms = DateTime::Format::Strptime->new(
    pattern   => 'PT%HH%MM%SS',
);

my $defaultTime = 'PT00H00M00S' || '';

sub new {
  my ($class, $params) = @_;

  my $self = {
    worklogDays => $params->{worklogDays},
    file => $params->{file},
    baseOds => 'base4.ods',
    year => $params->{year},
  };

  bless($self, $class);
  return $self;
}

##List the order of exported columns, and instructions on how to export them
my @exportColumnsList = (
  {header => 'day',                   type => 'date',    attr => 'ymd'},
  {header => 'start',                 type => 'time',    attr => 'start'},
  {header => 'end',                   type => 'time',    attr => 'end'},
  {header => 'breaks',                type => 'time',    attr => 'breaks'},
  {header => '+/-',                   type => 'time',    attr => 'overwork'},
  {header => 'duration',              type => 'time',    attr => 'duration'},
  {header => 'work accumulation',     type => 'time',    attr => 'overworkAccumulation'},
  {header => 'vacation accumulation', type => 'time',    attr => 'vacationAccumulation'},
  {header => 'remote',                type => 'time',    attr => 'remote'},
  {header => 'benefits',              type => 'boolean', attr => 'benefits'},
  {header => 'vacation',              type => 'time',    attr => 'vacation'},
  {header => 'paid leave',            type => 'time',    attr => 'paidLeave'},
  {header => 'non-paid leave',        type => 'time',    attr => 'nonPaidLeave'},
  {header => 'sick leave',            type => 'time',    attr => 'sickLeave'},
  {header => 'care leave',            type => 'time',    attr => 'careLeave'},
  {header => 'training',              type => 'time',    attr => 'learning'},
  {header => 'evening work',          type => 'time',    attr => 'eveningWork'},
  {header => 'daily overwork 1',      type => 'time',    attr => 'dailyOverwork1'},
  {header => 'daily overwork 2',      type => 'time',    attr => 'dailyOverwork2'},
  {header => 'saturday?',             type => 'boolean', attr => 'isSaturday'},
  {header => 'sunday?',               type => 'boolean', attr => 'isSunday'},
  {header => 'comments',              type => 'string',  attr => 'comments'},
);

sub asOds {
  my ($self) = @_;
  my $file = $self->{file}.'.ods';
  my $days = $self->{worklogDays};
  my @dates = sort keys %{$days};

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
  my ($neededHeight, $neededWidth) = ($rowsPerMonth*12, 22);
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

  foreach my $ymd (@dates) {
    my $day = $days->{$ymd};
    my ($y, $m, $d) = $ymd =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/;
    if ($self->{year} && $y != $self->{year}) {
      $l->debug("Day '$ymd' not in year '".$self->{year}."'") if $l->is_debug();
      next;
    }
    $l->info("Exporting day '$ymd'") if $l->is_info();
    #Check if the month changes, so we reorient the pointer
    if (not($prevM) || $m ne $prevM) {
      _startMonth($t, $rowPointer, $y, $m, $d, $rowsPerMonth);
    }
    _writeDay($t, $rowPointer, $ymd, $day);

    ($prevY, $prevM, $prevD) = ($y, $m, $d);
    $$rowPointer++;
  }

  $l->info("Saving to '$file'") if $l->is_info();
  $doc->save(target => $file);
  $doc->forget();
  return $file;
}

sub _checksAndVerifications {
  my ($t) = @_;

  $l->fatal("'date' is not a known ODF datatype") unless is_odf_datatype('date');
  $l->fatal("'time' is not a known ODF datatype") unless is_odf_datatype('time');
  $l->fatal("'boolean' is not a known ODF datatype") unless is_odf_datatype('boolean');
  $l->fatal("'string' is not a known ODF datatype") unless is_odf_datatype('string');
}

=head2 _startMonth

Calculates where the day entries of the new month are added, rewinds the row-iterator
and exports the monthly header row.

=cut

sub _startMonth {
  my ($t, $rowPointer, $y, $m, $d, $rowsPerMonth) = @_;

  #Calculate from where the next month begins
  if (1) { #Calculate the correct iterator position from the month requested.
    $$rowPointer = ($m-1) * $rowsPerMonth; #cell coordinates start from 0. Months start from 1.
    $l->debug("Starting a new month '$y-$m-$d' on row '$$rowPointer'. Rows preserved for month '$rowsPerMonth'. Calculating from month number") if $l->is_debug;
  } else { #Use iterator to move to the next available month slot.
    my $rowsUsedDuringPrevMonth = $$rowPointer % $rowsPerMonth;
    my $neededToNextMonthStart = $rowsPerMonth - $rowsUsedDuringPrevMonth;
    $l->debug("Starting a new month '$y-$m-$d' on row '$$rowPointer'. Rows preserved for month '$rowsPerMonth'. Rows used during the last month '$rowsUsedDuringPrevMonth'. Skipping '$neededToNextMonthStart' rows forward to start a new month.") if $l->is_debug;
    $$rowPointer += $neededToNextMonthStart if $rowsUsedDuringPrevMonth;
  }

  my $c; my $r=0;
  my $row = $t->get_row($$rowPointer);

  for (my $i=0 ; $i<scalar(@exportColumnsList) ; $i++) {
    my $colRule = $exportColumnsList[$i];

    $c = $row->get_cell($i);

    $l->trace("Printing header for \$colRule '".$colRule->{header}."', to cell '$i'") if $l->is_trace();

    $c->set_type('string');$c->set_value( $colRule->{header} );
  }
}

=head2 _writeDay

Exports a day to the row specified by the $rowPointer.
Reads instructions on how to handle each specific column from the @exportColumnsList

=cut

sub _writeDay {
  my ($t, $rowPointer, $ymd, $day) = @_;

  my $c; my $r=0;
  my $row = $t->get_row($$rowPointer);

  for (my $i=0 ; $i<scalar(@exportColumnsList) ; $i++) {
    my $colRule = $exportColumnsList[$i];
    my $attr = $colRule->{attr};
    my $val = $day->$attr();
    my $type = $colRule->{type};

    $c = $row->get_cell($i);

    $c->set_type( $type );

    if ($type eq 'date') {
      $c->set_value( $val );
    }
    elsif ($type eq 'time') {
      if (blessed($val) && $val->isa('DateTime')) {
        $c->set_value(  $val = $dtF_hms->format_datetime($val)  );
      }
      elsif (blessed($val) && $val->isa('DateTime::Duration')) {
        $c->set_value(  $val = RMS::Dates::formatDurationOdf($day->breaks)  );
      }
      else {
        $c->set_value(  $defaultTime  );
      }
    }
    elsif ($type eq 'boolean') {
      $c->set_value(  odf_boolean($val)  );
    }
    elsif ($type eq 'string') {
      $c->set_value(  $val  );
    }

    $l->trace("'$ymd' \$colRule '".$colRule->{header}."', to cell '$i', \$val='".($val // 'undef')."'") if $l->is_trace();
  }
}


sub asCsv {
  my ($self) = @_;
  my $file = $self->{file}.'.csv';

  my $csv = Text::CSV->new or die "Cannot use CSV: ".Text::CSV->error_diag ();
  $csv->eol("\n");
  $l->info("Writing to '$file'") if $l->is_info();
  open my $fh, ">:encoding(utf8)", $file or die "$file: $!";

  my $days = $self->{worklogDays};
  my @dates = sort keys %{$days};
  my $dates = $self->fillMissingYMDs(\@dates);

  foreach my $ymd (@$dates) {
    my $day = $days->{$ymd};
    my $row;
    if ($day) {
      $row = [
        $ymd,
        $day->start->hms,
        $day->end->hms,
        RMS::Dates::formatDurationPHMS($day->breaks),
        RMS::Dates::formatDurationPHMS($day->duration),
        RMS::Dates::formatDurationPHMS($day->overwork),
      ];
    }
    else {
      $days->{$ymd} = undef;
      $row = [
        $ymd,
        undef, undef, undef, undef, undef,
      ];
    }
    $csv->print($fh, $row);
  }

  close $fh or die "$file: $!";
  return $days;
}

=head2 $class->fillMissingYMDs

Given a list of YMDs, fill any missing YMD to make a continuous list of YMDs wihtout missing days.

@PARAM1 $class,
@PARAM2 Arrayref of String, YMDs
@RETURNS Arrayref of String, YMDs with missing days filled

=cut

sub fillMissingYMDs {
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
