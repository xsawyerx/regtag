package App::Regtag::ID3v1;
# ABSTRACT: Write ID3v1 tags

use Moo;
use MP3::Mplib;
use Term::ANSIColor;
use IO::Prompt::Tiny 'prompt';

use DDP;

has tags => (
    is      => 'ro',
    default => sub { [ qw<artist title album year track type comment> ] },
);

has tag_alias => (
    is      => 'ro',
    default => sub { {
        name   => 'title',
        genre  => 'type',
        number => 'track',
    } },
);

sub run {
    my $self = shift;
    my $data = shift;

    $self->ask_for_confirmation($data);
    $self->apply_changes($data);
}

sub ask_for_confirmation {
    my $self = shift;
    my $data = shift;
    my @tags = @{ $self->tags };

    foreach my $file ( keys %{$data} ) {
        print colored( '* ', 'green' ), "$file:\n";

        foreach my $tag (@tags) {
            my $tag_content = $data->{$file}{ uc $tag };
            defined $tag_content or next;

            printf "  %-7s %s\n",
                  ( ucfirst $tag ) . ':',
                  colored( $tag_content, 'blue' );
        }
    }

    my $answer = prompt(
        colored( 'Would you like to apply these tags [y/N]?', 'yellow' )
    );

    if ( $answer ne 'y' && $answer ne 'Y' ) {
        print "No changes made.\n";
        exit;
    }
}

sub show_tags {
    my $self  = shift;
    my $table = Text::SimpleTable->new(
        [ 15, 'Capture Name(s)' ],
        [ 6,  'Alias'           ],
        [ 22, 'Meaning'         ],
        [ 9,  'ID3 Frame'       ],
    );

    $table->row( '?<title>',   'name',   'Title',                  'TIT2' );
    $table->row( '?<artist>',  '',       'Artist',                 'TPE1' );
    $table->row( '?<album>',   '',       'Album/movie/show',       'TALB' );
    $table->row( '?<track>',   'number', 'Number/Position in set', 'TRCK' );
    $table->row( '?<year>',    '',       'Year',                   'TYER' );
    $table->row( '?<type>',    'genre',  'Genre',                  'TCON' );
    $table->row( '?<comment>', '',       'Comments',               'COMM' );

    # TODO: doublecheck?
    print $table->draw, "\n",
          "When both name and alias are provided, the name take precedence.\n";
}

sub apply_changes {
    my $self = shift;
    my $data = shift;

    foreach my $file ( keys %{$data} ) {
        print colored( '* ', 'green' ), "$file ... ";

        my $mp3 = MP3::Mplib->new($file);

        # we always strip what we do
        $mp3->del_v1tag;
        $mp3->del_v2tag;

        my $tag_data = $data->{$file};
        if ( $mp3->set_v1tag($tag_data) ) {
            print '[', colored( 'OK', 'green' ), "]\n";
        } else {
            print '[', colored( 'FAIL', 'red' ), "]\n";
        }
    }
}

1;

