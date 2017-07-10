package MTGapp;
use Dancer2;
use Dancer2::Plugin::CSRF;
use DBI;
use DBD::SQLite;
use YAML::Tiny;

our $VERSION = '0.1';


sub connect_db {
	my $dbh;
	return $dbh if(defined $dbh);
	my $config = YAML::Tiny->read('etc/config_file.yaml');
	$config = $config->[0];
	
		# define database name and driver
	my $driver = $config->{'db_param'}->{'driver'};
	my $db_name = $config->{'db_param'}->{'db_name'};
	my $username = $config->{'db_param'}->{'username'};
	my $password = $config->{'db_param'}->{'password'};
	

	my $dbd = "DBI:$driver:dbname=$db_name";
	$dbh = DBI->connect($dbd, $username, $password, { RaiseError => 1 })
		                  or die "can not connect: ".$DBI::errstr;
	
	return $dbh;
}	

hook 'before' => sub {
		set session => 'simple';

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


get '/' => sub {
    template 'my_card';
};

post '/login' => sub {
   my $user = params->{username};
   my $password = params->{password};
   if(defined $user and defined $password) {
        
		my $dbh = connect_db();

		my $sth = $dbh->prepare("SELECT user_id FROM users WHERE name = ? AND pass = ?");
		#TODO сделать невозможным ввод русских букв, иначе crypt падает
		$sth->execute($user, crypt($password, $user) );
		my $answer = $sth->fetchrow_arrayref();
		
		
		if( not defined $answer) {
			template 'login';	
		}		
		session user_id => $answer->[0];
		redirect '/';
	}else{
		template 'login';
	}
};
any ["get", "head"] => '/login' => sub { template 'login', { csrf_token => get_csrf_token() } };


true;
