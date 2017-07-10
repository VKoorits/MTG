use warnings;
use strict;
use DBI;
use DBD::SQLite;

my $dbh = DBI->connect("DBI:SQLite:dbname=MTG.db", "", "", { RaiseError => 1 }) or die "can not connect: ".$DBI::errstr;

# таблица пользователей
my $stmt = <<END;
CREATE TABLE users
             (user_id INTEGER PRIMARY KEY     AUTOINCREMENT,
              name      VARCHAR    NOT NULL,
              password VARCHAR NOT NULL,
              balance INTEGER
             )
END
$dbh->do($stmt);

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


$dbh->disconnect();
