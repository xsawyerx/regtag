package App::Regtag::ID3v1;
# ABSTRACT: Write ID3v1 tags

use Moo;
use MP3::Mplib;

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
    print << '_TAGS';
The following tags are supported by name and alias(es):

Capture Name(s)    Alias     Meaning                   ID3 Frame
---------------    -----     -------                   ---------
?<title>           name      Title                     TIT2
?<artist>                    Artist                    TPE1
?<album>                     Album/movie/show          TALB
?<track>           number    Number/Position in set    TRCK
?<year>                      Year                      TYER
?<type>            genre     Genre                     TCON
?<comment>                   Comments                  COMM

When both capture name and alias are provided, the alias takes
precedence.
_TAGS
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

