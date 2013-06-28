package App::Regtag::Tagger;
# Handling ID3 tagging

use Moo;
use MP3::Mplib;
use Term::ANSIColor;
use IO::Prompt::Tiny 'prompt';

has 'tags' => (
    is      => 'ro',
    default => sub { {
        # ID3v1    # ID3v2
        artist  => 'TPE1',
        title   => 'TIT2',
        album   => 'TALB',
        year    => 'TYER',
        track   => 'TRCK',
        type    => 'TCON',
        comment => 'COMM',
    } },
);

sub show_tags {
    my $self  = shift;

    print << '_TAGS';
The following ID3v tags are supported:

Name         ID3v1      ID3v2    Meaning
----         -----      -----    -------
?<title>     title      TIT2     Title
?<artist>    artist     TPE1     Artist
?<album>     album      TALB     Album/movie/show
?<track>     track      TRCK     Number/Position in set
?<year>      year       TYER     Year
?<type>      type       TCON     Genre
?<comment>   comment    COMM     Comments
_TAGS

}

sub run {
    my $self = shift;
    my $opt  = shift;
    my $data = shift;

    $self->ask_for_confirmation($data);
    $self->apply_changes( $opt, $data );
}

sub ask_for_confirmation {
    my $self = shift;
    my $data = shift;
    my @tags = keys %{ $self->tags };

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
    my $opt  = shift;
    my $data = shift;

    foreach my $file ( keys %{$data} ) {
        print colored( '* ', 'green' ), "$file ... ";

        my $mp3 = MP3::Mplib->new($file);

        # we always strip what we do
        $mp3->del_v1tag;
        $mp3->del_v2tag;

        my $tag_data  = $data->{$file};

        print '[';
        my @out = ();
        if ( $opt->{'v1'} ) {
            my $out = colored( 'v1', 'blue' ) . ':';
            if ( $mp3->set_v1tag($tag_data) ) {
                $out .= colored( 'OK', 'green' );
            } else {
                $out .= colored( 'FAIL', 'red' );
            }
            push @out, $out;
        }

        if ( $opt->{'v2'} ) {
            # use v2 tags
            my %data = map {
                $self->tags->{$_} => $tag_data->{ uc $_ }
            } grep { exists $tag_data->{ uc $_ } } keys %{ $self->tags };

            my $out = colored( 'v2', 'blue' ) . ':';
            if ( $mp3->set_v2tag(\%data) ) {
                $out .= colored( 'OK', 'green' );
            } else {
                $out .= colored( 'FAIL', 'red' );
            }
            push @out, $out;
        }

        print join( ',', @out ), "]\n";
    }
}

1;

