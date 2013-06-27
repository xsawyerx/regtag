package App::Regtag;
# ABSTRACT: Tag MP3s using regular expression awesomesaucehoodness

use v5.10;
use Moo;
use PerlX::Maybe;

use File::Find;
use File::Spec;
use File::Basename 'basename';
use Term::ANSIColor;
use Getopt::Long::Descriptive;

use App::Regtag::ID3v1;
use DDP;

# options
has idtag_version => (
    is      => 'ro',
    default => sub {'v1'},
);

has expanded => (
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

has list => (
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

sub new_with_options {
    my $class = shift;

    my ( $opt, $usage ) = describe_options(
        "%c %o <regex> <file|directory> [files...|directories...]",

        [ 'id'            => 'ID3 tag version: v1 (default) or v2' ],
        [ 'expanded|x'    => 'expanded regular expression'         ],
        [ 'ignore-case|i' => 'case insensitive in the filename'    ],
        [ 'quiet|q'       => 'less talk, more rock'                ], # TODO
        [],
        [ 'tags'          => 'show supported ID3 tags and aliases' ],
        [ 'list'          => 'list files and if they\'re tagged'   ],
        [ 'verbose|v+'    => 'verbose mode'                        ],
        [ 'help|h'        => 'print usage message and exit'        ],
    );

    if ( @ARGV == 0 && ! $opt->tags && ! $opt->list ) {
        print $usage->text;
        exit 0;
    }

    # if it's 0, we just print help
    # if it's 1, it can only be --tags or --list
    # if it's 2, we already have the minimum
    if ( @ARGV > 0 && @ARGV < 2 && ! $opt->tags && ! $opt->list ) {
        $usage->die( {
            pre_text => "Error: must provide regex and files or directories\n\n"
        } );
    }

    if ( $opt->help ) {
        print $usage->text;
        exit 0;
    }

    my ( $regex, @nodes );
    if ( ! $opt->tags && ! $opt->list ) {
        $regex = shift @ARGV;
        @nodes = @ARGV;
    }

    return $class->new(
        maybe idtag_version => $opt->id,
        maybe expanded      => $opt->expanded,
        maybe ignore_case   => $opt->ignore_case,
        maybe quiet         => $opt->quiet,
        maybe show_tags     => $opt->tags,
        maybe list          => $opt->list,
        maybe verbose       => $opt->verbose,
        maybe help          => $opt->help,

        regex_string        => $regex,
        nodes               => \@nodes,
    );
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
        $writer = App::Regtag::ID3v1->new;
    } elsif ( $self->idtag_version eq 'v2' ) {
        $writer = App::Regtag::ID3v2->new;
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

    if ( $self->list ) {
        $self->list_files( @ARGV ? @ARGV : ('.') );
        exit 0;
    }

    my %data = ();

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

        if ( $name !~ $self->regex ) {
            print colored( 'x ', 'red' ), "$name\n";
            return;
        }

        $self->analyze_node( \%data, $node );
    }, @{ $self->nodes } );

    $writer->run(\%data);

    return 1;
}

sub analyze_node {
    my $self   = shift;
    my $data   = shift;
    my $node   = shift;
    my $writer = $self->writer;

    # check if matched contradictory aliased keys
    my %tag_alias = %{ $writer->tag_alias };
    foreach my $alias ( keys %tag_alias ) {
        my $tag = $tag_alias{$alias};
        if ( exists $+{$alias} && exists $+{$tag} ) {
            warn "!! Provided and found both '$alias' and '$tag', ",
                 "using $tag instead\n";
        }
    }

    # aliases go first, actual tag names get priority after
    my $path = File::Spec->rel2abs($node);
    foreach my $alias ( keys %tag_alias ) {
        exists $+{$alias}
            and $data->{$path}{ uc $tag_alias{$alias} } = $+{$alias};
    }

    foreach my $tag ( @{ $writer->tags } ) {
        exists $+{$tag}
            and $data->{$path}{ uc $tag } = $+{$tag};
    }
}

sub list_files {
    my $self = shift;
    my @dirs = @_;

    find( sub {
        -f or return;

        my $file = $_;
        my $mp3  = MP3::Mplib->new($file);
        my $v1   = $mp3->get_v1tag;
        my $v2   = $mp3->get_v2tag;
        my $ext  = '';

        if ( keys %{$v1} ) {
            $ext .= '(v1) ';
        }

        if ( keys %{$v2} ) {
            $ext .= '(v2)';
        }

        $ext and print color 'blue';

        print $file, ( $ext ? " $ext" : '' ), "\n";

        print color 'reset';
    }, @dirs );
}

1;

