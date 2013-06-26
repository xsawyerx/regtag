package App::Regtag;
# ABSTRACT: Tag MP3s using regular expression awesomesaucehoodness

use v5.10;
use Moo;
use PerlX::Maybe;

use File::Spec;
use File::Basename 'basename';
use Term::ANSIColor;
use Text::SimpleTable;
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
        [ 'dry-run'       => 'do no harm'                          ], # TODO
        [],
        [ 'tags'          => 'show supported ID3 tags and aliases' ],
        [ 'verbose|v+'    => 'verbose mode'                        ],
        [ 'help|h'        => 'print usage message and exit'        ],
    );

    if ( @ARGV == 0 && ! $opt->tags ) {
        print $usage->text;
        exit 0;
    }

    # if it's 0, we just print help
    # if it's 1, it can only be --tags
    # if it's 2, we already have the minimum
    if ( @ARGV > 0 && @ARGV < 2 && ! $opt->tags ) {
        $usage->die( {
            pre_text => "Error: must provide regex and files or directories\n\n"
        } );
    }

    if ( $opt->help ) {
        print $usage->text;
        exit 0;
    }

    return $class->new(
        maybe idtag_version => $opt->id,
        maybe expanded      => $opt->expanded,
        maybe ignore_case   => $opt->ignore_case,
        maybe quiet         => $opt->quiet,
        maybe dry_run       => $opt->dry_run,
        maybe show_tags     => $opt->tags,
        maybe verbose       => $opt->verbose,
        maybe help          => $opt->help,

        regex_string        => shift @ARGV,
        nodes               => \@ARGV,
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

    my %data = ();
    foreach my $node ( @{ $self->nodes } ) {
        $self->analyze_node( \%data, $node );
    }

    $writer->run(\%data);

    return 1;
}

sub analyze_node {
    my $self   = shift;
    my $data   = shift;
    my $node   = shift;
    my $writer = $self->writer;

    if ( -d $node ) {
        chdir $node;

        opendir my $dh, '.' or die "Error: can't opendir '$node': $!\n";
        # ignoring dotfiles, take only mp3s
        my @innernodes = grep { $_ !~ /^\./ } readdir $dh;
        closedir $dh or die "Error: can't closedir '$node': $!\n";

        foreach my $inner (@innernodes) {
            $self->analyze_node( $data, $inner );
        }

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

    if ( $name !~ $self->regex ) {
        print colored( 'x ', 'red' ), "$name\n";
        return;
    }

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

1;

