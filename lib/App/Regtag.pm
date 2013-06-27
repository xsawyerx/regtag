package App::Regtag;
# ABSTRACT: Tag MP3s using regular expression awesomesaucehoodness

use App::Cmd::Setup -app;
use App::Regtag::ID3v1;
use App::Regtag::ID3v2;

sub _build_writer {
    my $self   = shift;
    my $opt    = shift;
    my $writer = $opt->{'id'} eq 'v1'    ?
                 App::Regtag::ID3v1->new :
                 App::Regtag::ID3v2->new;

    return $writer;
}

sub global_opt_spec {
    return (
        [ 'id=s'       => 'ID3 tag version: v1 (default) or v2' ],
        [ 'verbose|v+' => 'verbose mode'                        ],
    );
}

1;

