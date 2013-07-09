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
use Eval::Closure;
use Term::ANSIColor;

sub _build_regex {
    my $self      = shift;
    my $opt       = shift;
    my $regex_str = shift;
    my $mods      = 'u'; # TODO: research this a bit

    $opt->{'expanded'}    and $mods .= 'x';
    $opt->{'ignore_case'} and $mods .= 'i';

    my $regex = qr/(?^$mods:$regex_str)/;
    return $regex;
}

sub opt_spec {
    return (
        [ 'v1'            => 'work on v1 (default)'                 ],
        [ 'v2'            => 'work on v2'                           ],
        [ 'expanded|x'    => 'expanded regular expression'          ],
        [ 'ignore-case|i' => 'case insensitive in the filename'     ],
        [ 'define=s'      => 'define specific variables statically' ],
        [ 'transform|t=s' => 'tranform captured chunks with code'   ],
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

    ( exists $opt->{'v1'} ) || ( exists $opt->{'v2'} )
        or $opt->{'v1'} = 1;
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
            $defines{$key} = $value;
        }
    }

    my $writer = $self->app->_build_writer;
    my %data   = ();

    find( sub {
        -f        or return;
        /\.mp3$/i or return;

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

        $self->analyze_node( $opt, \%data, \%defines, $node );
    }, @nodes );

    $writer->run( $opt, \%data );
}

sub analyze_node {
    my $self    = shift;
    my $opt     = shift;
    my $data    = shift;
    my $defines = shift;
    my $node    = shift;
    my $writer  = $self->app->_build_writer;

    # copy stuff to a rw hash so we can add stuff
    my %cap_tags = %+;

    # add possible definitions
    foreach my $key ( keys %{$defines} ) {
        my $value = $defines->{$key};
        $cap_tags{$key} = $value;
    }

    my $path = File::Spec->rel2abs($node);

    # now the actual tag names
    foreach my $tag ( keys %{ $writer->tags } ) {
        exists $cap_tags{$tag}
            and $data->{$path}{ uc $tag } = $cap_tags{$tag};
    }

    # transformations in code
    if ( my $sub = $opt->{'transform'} ) {
        my $source = "
package Regtag::Value {
    our \$AUTOLOAD;
    sub AUTOLOAD {
        my \$self = shift;
        my \$func = \$AUTOLOAD;
        \$func =~ s/.*:://;
        \$self->{val} = eval \"\$func q{\$self->{val}}\";
    }

    # just so it doesn't interfere with the AUTOLOAD
    sub DESTROY {0}
}

sub {
    local %_ = map {;
        \$_ => bless { val => \$c{\$_} }, q{Regtag::Value}
    } keys %c;
    $sub;
    return %_;
}";

        my $code = eval_closure(
            source      => $source,
            environment => {
                '%c' => {
                    map { $_ => $cap_tags{$_} } keys %cap_tags
                },
            }
        );

        my %res = $code->();

        foreach my $key ( keys %res ) {
            $data->{$path}{ uc $key } = $res{$key}{val};
        }
    }
}

1;

