package Regtag;
# ABSTRACT: Tag MP3s using regular expression awesomesaucehoodness

use v5.10;
use Moo;
use PerlX::Maybe;

use File::Basename 'basename';
use Getopt::Long::Descriptive;

use Regtag::ID3v1;
use DDP;

# options
has idtag_version => (
    is      => 'ro',
    default => 'v1',
);

has expanded => (
    is      => 'ro',
    default => sub {0},
);

has strip => (
    is      => 'ro',
    default => sub {0},
);

has ignore_case => (
    is      => 'ro',
    default => sub {0},
);

has quiet => (
    is      => 'ro',
    default => sub {0},
);

has show_tags => (
    is      => 'ro',
    default => sub {0},
);

has verbose => (
    is      => 'ro',
    default => sub {0},
);

# requirements
has regex_string => (
    is       => 'ro',
    required => 1,
);

has nodes => (
    is       => 'ro',
    required => 1,
);

# variables
has tags => (
    is      => 'ro',
    default => sub { [ qw<title artist album track year type comment> ] },
);

# TODO: reverse these to allow multiple aliases?
has tag_alias => (
    is      => 'ro',
    default => sub { {
        name   => 'title',
        genre  => 'type',
        number => 'track',
    } },
);

has regex => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_regex',
);

has writer => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_writer',
);

sub BUILDARGS {
    my $class = shift;
    my ( $opt, $usage ) = describe_options(
        "%c %o <regex> <file|directory> [files...|directories...]",

        [ 'id'            => 'ID3 tag version: v1 (default) or v2' ],
        [ 'expanded|x'    => 'expanded regular expression'         ],
        [ 'ignore-case|i' => 'case insensitive in the filename'    ],
        [ 'strip-all|s'   => 'strip previously existing ID3 tags'  ], # TODO
        [ 'quiet|q'       => 'less talk, more rock'                ], # TODO
        [ 'dry-run'       => 'do no harm'                          ], # TODO
        [],
        [ 'tags'          => 'show supported ID3 tags and aliases' ],
        [ 'verbose|v+'    => 'verbose mode'                        ],
        [ 'help|h'        => 'print usage message and exit'        ],
    );

    if ( @ARGV == 0 ) {
        print $usage->text;
        exit 0;
    }

    # if it's 0, we just print help
    # if it's 2, we already have the minimum
    if ( @ARGV > 0 && @ARGV < 2 ) {
        $usage->die( {
            pre_text => "Error: must provide regex and files or directories\n\n"
        } );
    }

    if ( $opt->help ) {
        print $usage->text;
        exit 0;
    }

    return {
        maybe idtag_version => $opt->id,
        maybe expanded      => $opt->expanded,
        maybe ignore_case   => $opt->ignore_case,
        maybe strip         => $opt->strip_all,
        maybe quiet         => $opt->quiet,
        maybe dry_run       => $opt->dry_run,
        maybe show_tags     => $opt->tags,
        maybe verbose       => $opt->verbose,
        maybe help          => $opt->help,

        regex_string        => shift @ARGV,
        nodes               => \@ARGV,
    };
}

sub _build_regex {
    my $self      = shift;
    my $regex_str = $self->regex_string;
    my $mods;

    $self->expanded    and $mods .= 'x';
    $self->ignore_case and $mods .= 'i';

    my $regex = $mods ? qr/(?^$mods:)$regex_str/ : qr/$regex_str/;
    return $regex;
}

sub _build_writer {
    my $self = shift;

    my $writer;
    if ( $self->idtag_version eq 'v1' ) {
        $writer = Regtag::ID3v1->new;
    } elsif ( $self->idtag_version eq 'v2' ) {
        $writer = Regtag::ID3v2->new;
    } else {
        die "Unknown ID3 tag version: " . $self->idtag_version . "\n";
    }

    return $writer;
}

sub run {
    my $self   = shift;
    my $writer = $self->writer;

    if ( $self->show_tags ) {
        $writer->show_tags;
        exit 0;
    }

    my $regex = $self->_build_regex;

    foreach my $node ( @{ $self->nodes } ) {
        $self->work_node($node);
    }
}

sub work_node {
    my $self = shift;
    my $node = shift;

    if ( -d $node ) {
        $self->verbose && print ">> Recursing into $node\n";
        chdir $node;

        opendir my $dh, '.' or die "Error: can't opendir '$node': $!\n";
        # ignoring dotfiles, take only mp3s
        my @innernodes = grep { $_ !~ /^\./ } readdir $dh;
        closedir $dh or die "Error: can't closedir '$node': $!\n";

        foreach my $inner (@innernodes) {
            $self->work_node($inner);
        }

        $self->verbose && print "<< Leaving $node\n";
        chdir '..';

        # no more directory work
        return;
    }

    # ignore non-mp3 files
    $node =~ /\.mp3$/i or return;

    if ( ! -e $node ) {
        warn "!! File '$node' does not exist, ignoring.\n";
        next;
    }

    # this should be writable
    # but only if it's not in dry-run
    if ( ! -r $node ) {
        warn "!! File '$node' is not writable, ignoring.\n";
    }

    # if user provides a full path we strip it to get the basename
    my $name = basename($node);
    $self->verbose && print "++ Parsing $name\n";

    if ( $name =~ $self->regex ) {
        if ( $self->verbose && $self->verbose >= 2 ) {
            print "> $node:\n> {\n";
            foreach my $key ( keys %+ ) {
                my $value = $+{$key};
                print ">   '$key': '$value'\n";
            }
            print "> }\n";
        }

        my %tag_alias = %{ $self->tag_alias };
        # check if matched contradictory aliased keys
        foreach my $alias ( keys %tag_alias ) {
            my $tag = $tag_alias{$alias};
            if ( exists $+{$alias} && exists $+{$tag} ) {
                warn "!! Provided and found both '$alias' and '$tag', ",
                     "using $tag instead\n";
            }
        }

        my %data = ();
        # aliases go first, actual tag names get priority after
        foreach my $alias ( keys %tag_alias ) {
            exists $+{$alias} and $data{ uc $tag_alias{$alias} } = $+{$alias};
        }

        foreach my $tag ( @{ $self->tags } ) {
            exists $+{$tag} and $data{ uc $tag } = $+{$tag};
        }

        $self->writer->add_id3( $self->strip, $node, %data );
    }
}

1;

