package App::Regtag::ID3v1;
# ABSTRACT: Write ID3v1 tags

use Moo;
use MP3::Mplib;
use Text::SimpleTable;

use DDP;

has tags => (
    is      => 'ro',
    default => sub { [ qw<title artist album track year type comment> ] },
);

has tag_alias => (
    is      => 'ro',
    default => sub { {
        name   => 'title',
        genre  => 'type',
        number => 'track',
    } },
);

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

sub add_id3 {
    my $self                    = shift;
    my ( $strip, $file, %data ) = @_;

    my $mp3 = MP3::Mplib->new($file);

    # we always strip what we do
    if ($strip) {
        $mp3->del_v1tag;
        $mp3->del_v2tag;
    }

    print STDERR "Adding the following to $file\n";

    p %data;
    if ( ! $mp3->set_v1tag( { %data } ) ) {
        print 'Error with: ', ( join ', ', keys %data ), "\n";
    }
}

1;

