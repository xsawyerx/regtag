package App::Regtag::ID3v2;
# ABSTRACT: Write ID3v2 tags

use Moo;

has 'tags' => (
    is => 'ro',
    default => sub { [ qw<> ] },
);

has 'tag_alias' => (
    is => 'ro',
    default => sub { {} },
);

sub show_tags {
    my $self  = shift;

    print << '_TAGS';
The following ID3v2 tags are supported by name and alias(es):

Capture Name(s)    Alias     Meaning                   ID3 Frame
---------------    -----     -------                   ---------

When both name and alias are provided, the name takes precedence.
_TAGS

}

1;

