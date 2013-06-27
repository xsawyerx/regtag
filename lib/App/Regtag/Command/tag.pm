package App::Regtag::Command::tag;
# ABSTRACT: Tagging command for Regtag

use strict;
use warnings;
use v5.10;

use App::Regtag -command;
use Try::Tiny;
use File::Find;
use File::Spec;
use File::Basename;
use Term::ANSIColor;

sub _build_regex {
    my $self      = shift;
    my $opt       = shift;
    my $regex_str = shift;
    my $mods;

    $opt->{'expanded'}    and $mods .= 'x';
    $opt->{'ignore_case'} and $mods .= 'i';

    my $regex = $mods ? qr/(?^$mods:)$regex_str/ : qr/$regex_str/;
    return $regex;
}

sub opt_spec {
    return (
        [ 'expanded|x'    => 'expanded regular expression'          ],
        [ 'ignore-case|i' => 'case insensitive in the filename'     ],
        [ 'define=s'      => 'define specific variables statically' ],
    );
}

sub validate_args {
    my ( $self, $opt, $args ) = @_;

    @{$args} == 2
        or $self->usage_error('Must provide regex and files/dirs');

    try {
        my $regex = $args->[0];
        qr{$regex};
    } catch {
        $self->usage_error("Bad regex: $_");
    };
}

sub execute {
    my ( $self, $opt, $args ) = @_;

    # compose regex
    my ( $regex_str, @nodes ) = @{$args};
    my $regex = $self->_build_regex( $opt, $regex_str );

    # add the additional variables
    my %defines = ();
    if ( my $define = $opt->{'define'} ) {
        foreach my $pair ( split ',', $define ) {
            my ( $key, $value ) = split '=', $pair;
            # remove quotations?
            $value =~ s/^['"](.+)['"]$/$1/;
            $defines{$key} = $value;
        }
    }

    my $writer = $self->app->_build_writer;
    my %data   = ();

    find( sub {
        -f       or return;
        /\.mp3$/ or return;

        my $node = $_;

        # this should be writable
        if ( ! -r $node ) {
            warn "!! File '$node' is not writable, ignoring.\n";
            return;
        }

        # if user provides a full path we strip it to get the basename
        my $name = basename($node);

        if ( $name !~ $regex ) {
            print colored( 'x ', 'red' ), "$name\n";
            return;
        }

        $self->analyze_node( $opt, \%data, $node );
    }, @nodes );

    $writer->run(\%data);
}

sub analyze_node {
    my $self   = shift;
    my $opt    = shift;
    my $data   = shift;
    my $node   = shift;
    my $writer = $self->app->_build_writer;

    # copy stuff to a rw hash so we can add stuff
    my %cap_tags = %+;

    # add possible definitions
    foreach my $key ( keys %{ $opt->{'defines'} } ) {
        my $value = $self->defines->{$key};
        $cap_tags{$key} = $value;
    }

    # check if matched contradictory aliased keys
    my %tag_alias = %{ $writer->tag_alias };
    foreach my $alias ( keys %tag_alias ) {
        my $tag = $tag_alias{$alias};
        if ( exists $cap_tags{$alias} && exists $cap_tags{$tag} ) {
            warn "!! Provided and found both '$alias' and '$tag', ",
                 "using $tag instead\n";
        }
    }

    # aliases go first, actual tag names get priority after
    my $path = File::Spec->rel2abs($node);
    foreach my $alias ( keys %tag_alias ) {
        exists $cap_tags{$alias}
            and $data->{$path}{ uc $tag_alias{$alias} } = $cap_tags{$alias};
    }

    # now the actual tag names
    foreach my $tag ( @{ $writer->tags } ) {
        exists $cap_tags{$tag}
            and $data->{$path}{ uc $tag } = $cap_tags{$tag};
    }
}

1;

