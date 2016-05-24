#!/usr/bin/perl

use Modern::Perl;

use Getopt::Long qw(:config no_ignore_case);

use RMS::Worklogs;

my $help;
my $user_id;
my $filePath;
GetOptions(
    'h|help'      => \$help,
    'u|user_id:i' => \$user_id,
    'f|file:s'    => \$filePath,
);

my $usage = <<USAGE;

Extract work logs in a nicely formatted daily .csv-file
Perfect for importing to LibreOffice and friends!

  -h --help     This nice help

  -u --user_id  User id of the Redmine user whose worklogs you want to export.

  -f --file     Where to write the .csv?

EXAMPLES:

perl scripts/getWorkTime.pl -u 1 -f ~/workLogs.csv

USAGE


if ($help) {
    print $usage;
    exit 0;
}
unless ($user_id && $filePath) {
    print $usage.
          "You must define atleast --user_id\n";
    exit 0;
}



RMS::Worklogs->new({user_id => $user_id})->asCsv($filePath);

