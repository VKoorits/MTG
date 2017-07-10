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
my $ONE_CARD_PRICE = 0;


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


sub deal {	
	my $dbh = connect_db();
	
	my $id_stmt = "SELECT card_id FROM pictures WHERE card_name=\"$_[0]->{card_name}\"";
	my $card_id = $dbh->selectall_arrayref($id_stmt);
	
	if(not defined $card_id->[0]) {
		my $stmt = "INSERT INTO pictures (card_name, link) VALUES (\"$_[0]->{card_name}\", \"$_[0]->{link}\")";
		$dbh->do($stmt);
		
		$card_id = $dbh->selectall_arrayref($id_stmt);
	}
	#проверка: у пользователя уже может быть эта карта
	my $has_card = $dbh->selectall_arrayref(
		"SELECT COUNT(*) FROM available_cards "
		."WHERE user_id="
		.session('user_id')
		." and card_id="
		.$card_id->[0]->[0]
	);
	print "\n\ncount_this_card => ".$has_card->[0]->[0]."\n\n";
	if( $has_card->[0]->[0] <= 0) {	
		$dbh->do("INSERT INTO available_cards (user_id, card_id) VALUES (".session('user_id').",".$card_id->[0]->[0].") ");
		$dbh->do( "UPDATE users SET balance="
				  .(session('balance')-$ONE_CARD_PRICE)
				  ." WHERE user_id="
				  .session('user_id')
				);
		session balance => session('balance')-$ONE_CARD_PRICE;
		redirect '/';
	} else {
		template 'get_card', {csrf_token => get_csrf_token(), ok => 1, message => "У вас уже есть такакя карта. Попробуйте ещё раз"};
	}
	
}

##############################

hook 'before' => sub {
		set session => 'simple';
		#session user_id => 1;
		#session balance => 1000;
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
	my @cards = @{ get_magic_cards($query) };
	
	my $dbh = connect_db();
	for my $card (@cards) {
		my $id_stmt = "SELECT card_id FROM pictures WHERE card_name=\"$card->{card_name}\"";
		p $id_stmt;
		my $card_id = $dbh->selectall_arrayref($id_stmt);
		if(not defined $card_id->[0]) {
			my $stmt = "INSERT INTO pictures (card_name, link) VALUES (\"$card->{card_name}\", \"$card->{link}\")";
			$dbh->do($stmt);
		}
	}
	
	
	if( @cards == 0) {
		template 'get_card', {csrf_token => get_csrf_token(), ok => 1, message => "По вашему запросу не найдено карт :( попробуйте ещё раз"}
	} elsif( @cards == 1 ) {
		deal($cards[0]);
	} else {
		print "\nbuy_card\n";
		template 'select_card', { cards => \@cards, csrf_token => get_csrf_token()};
	}
};
any ["get", "head"] => '/get_card' => sub {
	my $ok = 1;
	$ok = 0 if( session('balance') < $ONE_CARD_PRICE );
	print "\nok => $ok\n";
	template 'get_card', { csrf_token => get_csrf_token(), ok => $ok, message =>"" } };


post '/proof' => sub {
	my $card_name = params->{card_name};
	my $link = params->{'link'};
	template 'proof', {card => $card_name, link => $link, csrf_token => get_csrf_token() };
};
post '/deal' => sub {
	my $card_name = params->{card_name};
	my $link = params->{'link'};
	deal( { card_name => $card_name, link => $link } );
	print "card_name => ".$card_name."\n";
	print "link => ".$link."\n";
	redirect '/';
};

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

		session user_id => $answer->[0];
		session balance => $answer->[1];
		redirect '/';
	}else{
		template 'login';
	}
};
any ["get", "head"] => '/login' => sub { template 'login', { csrf_token => get_csrf_token() } };

any '/balance' => sub { template 'balance', {balance => session('balance'), price => $ONE_CARD_PRICE} };

true;
