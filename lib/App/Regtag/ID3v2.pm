package App::Regtag::ID3v2;
# ABSTRACT: Write ID3v2 tags

use Moo;
use MP3::Mplib;
use Term::ANSIColor;
use IO::Prompt::Tiny 'prompt';

has tags => (
    is      => 'ro',
    default => sub { [ qw<> ] },
);

has tag_alias => (
    is      => 'ro',
    default => sub { {} },
);

sub run {
    my $self = shift;
    my $data = shift;

    # refactor
    #$self->ask_for_confirmation($data);
    $self->apply_changes($data);
}

sub show_tags {
    my $self  = shift;

    print << '_TAGS';
The following ID3v2 tags are supported by name and alias(es):

Capture Name(s)    Alias     Meaning                   ID3 Frame
---------------    -----     -------                   ---------

When both name and alias are provided, the name takes precedence.
_TAGS

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
        if ( $mp3->set_v2tag($tag_data) ) {
            print '[', colored( 'OK', 'green' ), "]\n";
        } else {
            print '[', colored( 'FAIL', 'red' ), "]\n";
        }
    }
}

1;

