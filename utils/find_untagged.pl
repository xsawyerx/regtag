#!/usr/bin/perl
use strict;
use warnings;

use DDP;
use Term::ANSIColor;
use MP3::Mplib;

my $file = $ARGV[0] or die "$0 <file.mp3>\n";
my $mp3  = MP3::Mplib->new($file);

my $v1 = $mp3->get_v1tag;
my $v2 = $mp3->get_v2tag;
my $ex = '';

if ( keys(%{$v1}) ) {
    $ex .= '(v1) ';
}

if ( keys(%{$v2}) ) {
    $ex .= '(v2)';
}

$ex and print color 'blue';

print $file . ($ex?" $ex":'') . "\n";

print color 'reset';

