package App::Regtag::ID3v1;
# ABSTRACT: Write ID3v1 tags

use Moo;

with 'App::Regtag::Role::ID3';

has 'tags' => (
    is => 'ro',
    default => sub { [ qw<artist title album year track type comment> ] },
);

has 'tag_alias' => (
    is => 'ro',
    default => sub { {
        name   => 'title',
        genre  => 'type',
        number => 'track',
    } },
);

sub show_tags {
    my $self  = shift;

    print << '_TAGS';
The following ID3v1 tags are supported by name and alias(es):

Capture Name(s)    Alias     Meaning                   ID3 Frame
---------------    -----     -------                   ---------
?<title>           name      Title                     TIT2
?<artist>                    Artist                    TPE1
?<album>                     Album/movie/show          TALB
?<track>           number    Number/Position in set    TRCK
?<year>                      Year                      TYER
?<type>            genre     Genre                     TCON
?<comment>                   Comments                  COMM

When both name and alias are provided, the name takes precedence.
_TAGS

}

1;

