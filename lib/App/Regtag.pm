package App::Regtag;
# ABSTRACT: Tag MP3s using regular expression awesomesaucehoodness

use App::Cmd::Setup -app;
use App::Regtag::ID3v1;
use App::Regtag::ID3v2;

sub _build_writer {
    my $self = shift;
    my $id   = defined $self->global_options->{'id'} ?
                       $self->global_options->{'id'} :
                       'v1';

    my $writer;
    if ( $id eq 'v1' ) {
        $writer = App::Regtag::ID3v1->new;
    } elsif ( $id eq 'v2' ) {
        $writer = App::Regtag::ID3v2->new;
    } else {
        $self->usage_error('Unrecognized ID3 version');
    }

    return $writer;
}

sub global_opt_spec {
    return (
        [ 'id=s'       => 'ID3 tag version: v1 (default) or v2' ],
        [ 'verbose|v+' => 'verbose mode'                        ],
    );
}

1;

