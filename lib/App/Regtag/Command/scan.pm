package App::Regtag::Command::scan;
# ABSTRACT: Directory scanning command for Regtag

use strict;
use warnings;

use App::Regtag -command;
use MP3::Mplib;
use File::Find;
use Term::ANSIColor;

sub execute {
    my ( $self, $opt, $args ) = @_;

    my @dirs = @{$args} ? @{$args} : ('.');
    find( sub {
        -f or return;

        my $file = $_;
        my $mp3  = MP3::Mplib->new($file);
        my %v1   = %{ $mp3->get_v1tag };
        my %v2   = %{ $mp3->get_v2tag };
        my $ext  = sprintf '%s%s',
            ( keys %v1 ) ? '(v1) ' : '',
            ( keys %v2 ) ? '(v2)'  : '';

        $ext and print color 'blue';
        print "* $file $ext\n";
        print color 'reset';

        # more details
        if ( $self->app->global_options->{'verbose'} ) {
            # v1
            ( keys %v1 ) and print "  (IDv1)\n";
            foreach my $key ( keys %v1 ) {
                print "  ", ucfirst lc $key, ": ", $v1{$key}, "\n";
            }
            ( keys %v1 ) and print "\n";

            # v2
            ( keys %v2 ) and print "  (IDv2)\n";
            foreach my $key ( keys %v2 ) {
                print "  ", ucfirst lc $key, ": ", $v2{$key}, "\n";
            }
            ( keys %v2 ) and print "\n";
        }
    }, @dirs );
}

1;

