use warnings;
use strict;
use DBI;
use DBD::SQLite;

my $dbh = DBI->connect("DBI:SQLite:dbname=MTG.db", "", "", { RaiseError => 1 }) or die "can not connect: ".$DBI::errstr;

# таблица пользователей
my $stmt = <<END;
CREATE TABLE users
             (user_id INTEGER PRIMARY KEY     AUTOINCREMENT,
              name VARCHAR NOT NULL,
              pass VARCHAR NOT NULL,
              balance INTEGER
             )
END
$dbh->do($stmt);

#т.к. регистрация не предусмотрена, то здесь добавляется три пользователя
my @users = (
	{login => 'Nikola', pass => 'kvas'},
	{login => 'Petr', pass => 'first'},
	{login => 'login', pass => 'pass'},
);
my $sth = $dbh->prepare("INSERT INTO users (name, pass, balance) VALUES (?,?,?)");
for my $user ( @users ) {
	$sth->execute(
			$user->{login},
			crypt($user->{pass}, $user->{login}),
			1000 #TODO завести константу
	);
}

# уже известные ссылки на изображения, для избежания повторного парсинга
$stmt = <<END;
CREATE TABLE pictures
             (card_id INTEGER PRIMARY KEY     AUTOINCREMENT,
              card_name      VARCHAR    NOT NULL,
              link VARCHAR NOT NULL
             )
END
$dbh->do($stmt);

# список доступных пользователям карт
$stmt = <<END;
CREATE TABLE available_cards	
             (user_id INTEGER NOT NULL,
              card_id INTEGER NOT NULL
             )
END
$dbh->do($stmt);

# список совершенных запросов
$stmt = <<END;
CREATE TABLE requests	
             (req_id INTEGER PRIMARY KEY     AUTOINCREMENT,
              req VARCHAR NOT NULL
             )
END
$dbh->do($stmt);


# ответы, полученные на запросы
$stmt = <<END;
CREATE TABLE answers	
             (req_id INTEGER NOT NULL,
              card_id INTEGER NOT NULL
             )
END
$dbh->do($stmt);


$dbh->disconnect();
