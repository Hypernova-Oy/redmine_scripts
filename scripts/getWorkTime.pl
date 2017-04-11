#!/usr/bin/perl

use Modern::Perl;

use Getopt::Long qw(:config no_ignore_case);

use RMS::Worklogs;

my $help;
my $user;
my $filePath;
my @types;
my $year;
GetOptions(
    'h|help'      => \$help,
    'u|user:s'    => \$user,
    'f|file:s'    => \$filePath,
    't|type:s'    => \@types,
    'y|year:s'    => \$year,
);

my $usage = <<USAGE;

Extract work logs in a nicely formatted daily .csv-file
Perfect for importing to LibreOffice and friends!

  -h --help     This nice help

  -u --user     User id or the login name of the Redmine user whose worklogs you want to export.

  -f --file     Where to write the export? Path and filename Without the file suffix.

  -t --type     What export types are used?
                odt or/and csv
                This is automatically appended to the --file

  -y --year     Which year to extract, 2016, 2017, ...

EXAMPLES:

perl scripts/getWorkTime.pl -y 2017 -t csv -u 1 -f ~/workLogs.csv
perl scripts/getWorkTime.pl -y 2016 -t csv -t odt -u 1 -f ~/workLogs.csv

USAGE


if ($help) {
    print $usage;
    exit 0;
}
unless ($user) {
    print $usage.
          "You must define --user\n";
    exit 0;
}
unless ($filePath) {
    print $usage.
          "You must define --file\n";
    exit 0;
}
unless (@types) {
    print $usage.
          "You must define atleast one --type\n";
    exit 0;
}

my $wollel = RMS::Worklogs->new({user => $user, year => $year});
foreach my $type (@types) {
    if ($type eq 'ods') {
        $wollel->asOds($filePath);
    } elsif ($type eq 'csv') {
        $wollel->asCsv($filePath);
    }
}

1;
