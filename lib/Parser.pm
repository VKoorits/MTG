package Parser;
use strict;
use warnings;
use Exporter qw/import/;
use HTML::Parser;
use LWP;
use DDP;

our @EXPORT_OK = qw/parse/;

#TODO передавать как аргументы, избавиться от глобальных переменных
my $read_card = 0; #находимся ли мы в процессе считывания карты, или это поиск
my $get_text = 0;
my @cards;
sub start {
	# из всех таблиц на стрнице аттрибут style есть только у тех, которые содержат карту
	if ($_[0] eq 'table' and exists $_[1]->{style}) {
		push @cards, {};
		$read_card = 2;#начинаем считывать адрес изображения
	}elsif( $read_card == 2 and $_[0] eq 'img' ){
		$cards[-1]->{'link'} = $_[1]->{src};
		$read_card = 1; #теперь нужно найти оригинальное название карты
	}elsif( $read_card == 1 and $_[0] eq 'a') {
		$get_text = 1;
		$read_card = 0; #карта считана, можно переходить к следующей
	}
	
}
sub text{
	if( $get_text == 1 ) {
		$cards[-1]->{card_name} = $_[0];
		$get_text = 0;
	}
}
###################
sub parse{
	my $query = shift;
	$read_card = 0;
	$get_text = 0;
	@cards = ();
	
	#TODO нормальная сборка ссылки
	my $url = "http://magiccards.info/query?q=$query&v=card&s=cname";
	#TODO обработка ошибок скачивания
	my $page = LWP::UserAgent->new()->get($url)->{_content};
	
	my $p = HTML::Parser->new( api_version => 3,
		start_h => [\&start, "tagname, attr"],
		text_h => [ \&text, "dtext" ],
		marked_sections => 1,
	);
	$p->parse($page);

	return \@cards
}



1;
