#!/usr/bin/perl

## Omnipresent pragma setter
use Modern::Perl;
use utf8;
use Carp;
use autodie;
$Carp::Verbose = 'true'; #die with stack trace
## Pragmas set

$ENV{MOJO_LOG_LEVEL} = 'DEBUG';

use Mojolicious::Lite;

get '/worklogs/:username' => sub {
  my $c = shift;
  RMS::Worklogs->new({user => $c->param('username')})->asOdt('/tmp/workTime.odt');
  $c->reply->static("/tmp/workTime.odt");
};

