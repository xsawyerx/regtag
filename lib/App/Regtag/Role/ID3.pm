package App::Regtag::Role::ID3;
# ABSTRACT: A basic role for ID3 tags

use Moo::Role;
use MP3::Mplib;
use Term::ANSIColor;
use IO::Prompt::Tiny 'prompt';

#has tags => (
#    is       => 'ro',
#    required => 1,
#);
#
#has tag_alias => (
#    is      => 'ro',
#    default => sub { {} },
#);

requires 'show_tags';

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

sub apply_changes {
    my $self = shift;
    my $data = shift;

    foreach my $file ( keys %{$data} ) {
        print colored( '* ', 'green' ), "$file ... ";

        my $mp3 = MP3::Mplib->new($file);

        # we always strip what we do
        $mp3->del_v1tag;
        $mp3->del_v2tag;

        my ($version) = __PACKAGE__ =~ /^App::Regtag::ID3v(1|2)$/;
        my $method    = "set_v${version}tag";
        my $tag_data  = $data->{$file};
        if ( $mp3->$method($tag_data) ) {
            print '[', colored( 'OK', 'green' ), "]\n";
        } else {
            print '[', colored( 'FAIL', 'red' ), "]\n";
        }
    }
}

1;

