package MTGapp;
use Dancer2;

our $VERSION = '0.1';

get '/login' => sub {
    template 'login';
};

true;
