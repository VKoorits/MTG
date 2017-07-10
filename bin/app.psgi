#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";


# use this block if you don't need middleware, and only have a single target Dancer app to run here
use MTGapp;

MTGapp->to_app;

use Plack::Builder;

builder {
    enable 'Deflater';
    MTGapp->to_app;
}



=begin comment
# use this block if you want to include middleware such as Plack::Middleware::Deflater

use MTGapp;
use Plack::Builder;

builder {
    enable 'Deflater';
    MTGapp->to_app;
}

=end comment

=cut

=begin comment
# use this block if you want to include middleware such as Plack::Middleware::Deflater

use MTGapp;
use MTGapp_admin;

builder {
    mount '/'      => MTGapp->to_app;
    mount '/admin'      => MTGapp_admin->to_app;
}

=end comment

=cut

