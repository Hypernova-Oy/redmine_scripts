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

use RMS::Worklogs::Day;
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

my $defaultTime = 'PT00H00M00S' || '';

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
  my $days = $self->fillMissingDays( $self->{worklogDays} );
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
  my ($neededHeight, $neededWidth) = ($rowsPerMonth*12, 21);
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
  $c = $t->get_cell($$rowPointer,  0);$c->set_type('string');$c->set_value('day');
  $c = $t->get_cell($$rowPointer,  1);$c->set_type('string');$c->set_value('start');
  $c = $t->get_cell($$rowPointer,  2);$c->set_type('string');$c->set_value('end');
  $c = $t->get_cell($$rowPointer,  3);$c->set_type('string');$c->set_value('break');
  $c = $t->get_cell($$rowPointer,  4);$c->set_type('string');$c->set_value('+/-');
  $c = $t->get_cell($$rowPointer,  5);$c->set_type('string');$c->set_value('duration');
  $c = $t->get_cell($$rowPointer,  6);$c->set_type('string');$c->set_value('accumulation');
  $c = $t->get_cell($$rowPointer,  7);$c->set_type('string');$c->set_value('remote?');
  $c = $t->get_cell($$rowPointer,  8);$c->set_type('string');$c->set_value('benefits?');
  $c = $t->get_cell($$rowPointer,  9);$c->set_type('string');$c->set_value('vacation');
  $c = $t->get_cell($$rowPointer, 10);$c->set_type('string');$c->set_value('paid-leave');
  $c = $t->get_cell($$rowPointer, 11);$c->set_type('string');$c->set_value('non-paid-leave');
  $c = $t->get_cell($$rowPointer, 12);$c->set_type('string');$c->set_value('sick-leave');
  $c = $t->get_cell($$rowPointer, 13);$c->set_type('string');$c->set_value('care-leave');
  $c = $t->get_cell($$rowPointer, 14);$c->set_type('string');$c->set_value('training');
  $c = $t->get_cell($$rowPointer, 15);$c->set_type('string');$c->set_value('eveningWork');
  $c = $t->get_cell($$rowPointer, 16);$c->set_type('string');$c->set_value('dailyOverwork1');
  $c = $t->get_cell($$rowPointer, 17);$c->set_type('string');$c->set_value('dailyOverwork2');
  $c = $t->get_cell($$rowPointer, 18);$c->set_type('string');$c->set_value('saturday?');
  $c = $t->get_cell($$rowPointer, 19);$c->set_type('string');$c->set_value('sunday?');
  $c = $t->get_cell($$rowPointer, 20);$c->set_type('string');$c->set_value('comments');
  $$rowPointer++;
}
my $lastKnownOverworkAccumulation;
sub _writeDay {
  my ($t, $rowPointer, $ymd, $day) = @_;
  $lastKnownOverworkAccumulation = $day->overworkAccumulation if $day && $day->overworkAccumulation;

  my ($c, $v);
  #0 - day
  $c = $t->get_cell($$rowPointer,  0);$c->set_type('date');$c->set_value($ymd);
  #1 - start
  $c = $t->get_cell($$rowPointer,  1);$c->set_type('time');$c->set_value(  $day->start ? $dtF_hms->format_datetime($day->start) : $defaultTime  );
  #2 - end
  $c = $t->get_cell($$rowPointer,  2);$c->set_type('time');$c->set_value(  $day->end ? $dtF_hms->format_datetime($day->end) : $defaultTime  );
  #3 - break
  $c = $t->get_cell($$rowPointer,  3);$c->set_type('time');$c->set_value(  $day->breaks ? $ddF_hms->format_duration($day->breaks) : $defaultTime  );
  #4 - +/-
  $c = $t->get_cell($$rowPointer,  4);$c->set_type('time');$c->set_value(  $day->overwork ? $ddF_hms->format_duration($day->overwork) : $defaultTime  );
  #5 - duration
  $c = $t->get_cell($$rowPointer,  5);$c->set_type('time');$c->set_value(  $day->duration ? $ddF_hms->format_duration($day->duration) : $defaultTime  );
  #6 - overworkAccumulation
  $c = $t->get_cell($$rowPointer,  6);$c->set_type('time');$c->set_value(  $ddF_hms->format_duration($day->overworkAccumulation)  );
  #7 - remote?
  $c = $t->get_cell($$rowPointer,  7);$c->set_type('boolean');$c->set_value(  odf_boolean($day->remote)  );
  #8 - benefits?
  $c = $t->get_cell($$rowPointer,  8);$c->set_type('boolean');$c->set_value(  odf_boolean($day->benefits)  );
  #9 - vacation
  $c = $t->get_cell($$rowPointer,  9);$c->set_type('time');$c->set_value(  $day->vacation ? $ddF_hms->format_duration($day->vacation) : $defaultTime  );
  #10 - Paid leave
  $c = $t->get_cell($$rowPointer, 10);$c->set_type('time');$c->set_value(  $day->paidLeave ? $ddF_hms->format_duration($day->paidLeave) : $defaultTime  );
  #11 - Non-paid leave
  $c = $t->get_cell($$rowPointer, 11);$c->set_type('time');$c->set_value(  $day->nonPaidLeave ? $ddF_hms->format_duration($day->nonPaidLeave) : $defaultTime  );
  #12 - sick leave
  $c = $t->get_cell($$rowPointer, 12);$c->set_type('time');$c->set_value(  $day->sickLeave ? $ddF_hms->format_duration($day->sickLeave) : $defaultTime  );
  #13 - care-leave
  $c = $t->get_cell($$rowPointer, 13);$c->set_type('time');$c->set_value(  $day->careLeave ? $ddF_hms->format_duration($day->careLeave) : $defaultTime  );
  #14 - training
  $c = $t->get_cell($$rowPointer, 14);$c->set_type('time');$c->set_value(  $day->learning ? $ddF_hms->format_duration($day->learning) : $defaultTime  );
  #15 - eveningWork
  $c = $t->get_cell($$rowPointer, 15);$c->set_type('time');$c->set_value(  $day->eveningWork ? $ddF_hms->format_duration($day->eveningWork) : $defaultTime  );
  #16 - daily overwork 1
  $c = $t->get_cell($$rowPointer, 16);$c->set_type('time');$c->set_value(  $day->dailyOverwork1 ? $ddF_hms->format_duration($day->dailyOverwork1) : $defaultTime  );
  #17 - daily overwork 2
  $c = $t->get_cell($$rowPointer, 17);$c->set_type('time');$c->set_value(  $day->dailyOverwork2 ? $ddF_hms->format_duration($day->dailyOverwork2) : $defaultTime  );
  #18 - saturday?
  $c = $t->get_cell($$rowPointer, 18);$c->set_type('boolean');$c->set_value(  odf_boolean($day ? $day->isSaturday : undef)  );
  #19 - sunday?
  $c = $t->get_cell($$rowPointer, 19);$c->set_type('boolean');$c->set_value(  odf_boolean($day ? $day->isSunday : undef)  );
  #20 - comments
  $c = $t->get_cell($$rowPointer, 20);$c->set_type('string');$c->set_value(  $day->comments  );

  $l->debug("$$rowPointer: $ymd - ".($day ? $day : 'undef')) if $l->is_debug();
}


sub asCsv {
  my ($self) = @_;

  my $csv = Text::CSV->new or die "Cannot use CSV: ".Text::CSV->error_diag ();
  $csv->eol("\n");
  open my $fh, ">:encoding(utf8)", $self->{file} or die $self->{file}.": $!";

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

  close $fh or die $self->{file}.": $!";
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

=head2 $class->fillMissingDays

Just like _fillMissingYMDs, but receives a hash of RMS::Worklogs::Day-objects and fills the missing days
with empty RMS::Worklogs::Day-objects

@PARAM1 $class
@PARAM2 HashRef of RMS::Worklogs::Day-objects, with keys as YMDs
@RETURNS HashRef of RMS::Worklogs::Day-objects with empty days filled with empty defaults

=cut

sub fillMissingDays {
    my ($class, $days) = @_;
    die __PACKAGE__."::fillMissingDays():> \$days '".($days || 'undef')."' is not a HASHREF" unless(ref($days) eq 'HASH');

    my @dates = sort keys %$days;
    my %days;
    for (my $i=0 ; $i<scalar(@dates) ; $i++) {
        my $a = $dates[$i];
        my $b = $dates[$i+1] if $dates[$i+1];

        my $prevDay = $days->{$a};
        $l->trace("Entering date filling loop with date='$a', \$prevDay=".$prevDay) if $l->is_trace();
        do {
            my $curDay = $days->{$a};
            $l->trace("Fetch \$curDay=".($curDay || 'undef')) if $l->is_trace();
            $days{$a} = $curDay ? $curDay : RMS::Worklogs::Day->newEmpty($prevDay);
            $l->trace("Set \$curDay=".($days{$a} || 'undef')) if $l->is_trace();
            $prevDay = $days{$a};
            #Increment $a by one day
            $a = DateTime::Format::MySQL->parse_datetime( $a.' 00:00:00' )->add_duration( DateTime::Duration->new(days => 1) )->ymd();
            $l->trace("Date='$a' incremented") if $l->is_trace();
        } while ($b && $a lt $b);
    }
    return \%days;
}

1;
