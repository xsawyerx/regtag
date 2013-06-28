package App::Regtag;
# ABSTRACT: Tag MP3s using regular expression awesomesaucehoodness

use App::Cmd::Setup -app;
use App::Regtag::Tagger;

sub _build_writer {
    return App::Regtag::Tagger->new;
}

sub global_opt_spec {
    return (
        [ 'id=s'       => 'ID3 tag version: v1 (default) or v2' ],
        [ 'verbose|v+' => 'verbose mode'                        ],
    );
}

1;

