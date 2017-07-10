package MTGapp;
use Dancer2;
use Dancer2::Plugin::CSRF;
use DBI;
use DBD::SQLite;
use YAML::Tiny;
use AnyEvent::HTTP;
use Parser 'parse';

use DDP;

our $VERSION = '0.1';

my $db_handler = undef;
sub connect_db {
	return $db_handler if(defined $db_handler);
	my $config = YAML::Tiny->read('etc/config_file.yaml');
	$config = $config->[0];
	
		# define database name and driver
	my $driver = $config->{'db_param'}->{'driver'};
	my $db_name = $config->{'db_param'}->{'db_name'};
	my $username = $config->{'db_param'}->{'username'};
	my $password = $config->{'db_param'}->{'password'};
	

	my $dbd = "DBI:$driver:dbname=$db_name";
	$db_handler = DBI->connect($dbd, $username, $password, { RaiseError => 1 })
		                  or die "can not connect: ".$DBI::errstr;
	
	return $db_handler;
}	



sub get_magic_cards {
	my $query = shift;
	if(!$query) {
		return []
	}
	
	my @cards = @{ parse( $query ) };
	
	
	
	return \@cards;
}


hook 'before' => sub {
		set session => 'simple';
		session user_id => 1;
		session balance => 1000;
		if (request->path_info !~ m{^/login} &&
			request->path_info !~ m{^/CSRF} &&
		 	!session('user_id')) {
		    			redirect 'login';
		}
		if ( request->is_post() ) {
			my $csrf_token = params->{'csrf_token'};
			if ( !$csrf_token || !validate_csrf_token($csrf_token) ) {
				redirect '/CSRF';
			}
		}

		
    };


any '/' => sub {
	my $dbh = connect_db();
	my $user_id = session('user_id') ;
	my $query = <<END;
		SELECT img.card_name, img.link 
		FROM pictures as img
		WHERE img.card_id IN (
			SELECT ac.card_id 
			FROM available_cards as ac
			WHERE ac.user_id=$user_id
		)
END
	my $cards = $dbh->selectall_arrayref($query, {Slice => {}});
    template 'my_card', { cards => $cards };
};


post '/get_card' => sub {
	my $query = params->{query};
	my $cards = get_magic_cards($query);


	redirect '/get_card';
};
any ["get", "head"] => '/get_card' => sub { template 'get_card', { csrf_token => get_csrf_token() } };


post '/login' => sub {
   my $user = params->{username};
   my $password = params->{password};
   if(defined $user and defined $password) {
        
		my $dbh = connect_db();

		my $sth = $dbh->prepare("SELECT user_id, balance FROM users WHERE name = ? AND pass = ?");
		#TODO сделать невозможным ввод русских букв, иначе crypt падает
		$sth->execute($user, crypt($password, $user) );
		my $answer = $sth->fetchrow_arrayref();
		p $answer;
		
		if( not defined $answer) {
			template 'login';	
		}		
		#TODO переделать в хеш, избавиться от цифр
		session user_id => $answer->[0];
		session balance => $answer->[1];
		redirect '/';
	}else{
		template 'login';
	}
};
any ["get", "head"] => '/login' => sub { template 'login', { csrf_token => get_csrf_token() } };

any '/balance' => sub { template 'balance', {balance => 1000} };

true;
