package Lltag::MP3 ;

use strict ;

require Lltag::Tags ;
require Lltag::Misc ;

sub test_mp3info {
    my $self = shift ;
    my ($status, @output) = Lltag::Misc::system_with_output ("mp3info", "-h") ;
    print "mp3info does not seem to work, disabling 'MP3' backend.\n"
	if $status and $self->{verbose_opt} ;
    return $status ;
}

#######################################################

# valid ID3v1 genres in mp3info
my @mp3info_genres = ("", # 0
	      "Blues", "Classic Rock", "Country", "Dance", "Disco", # 5
	      "Funk", "Grunge", "Hip-Hop", "Jazz", "Metal", # 10
	      "New Age", "Oldies", "Other", "Pop", "R&B", # 15
	      "Rap", "Reggae", "Rock", "Techno", "Industrial", # 20
	      "Alternative", "Ska", "Death Metal", "Pranks", "Soundtrack", # 25
	      "Euro-Techno", "Ambient", "Trip-Hop", "Vocal", "Jazz+Funk", # 30
	      "Fusion", "Trance", "Classical", "Instrumental", "Acid", # 35
	      "House", "Game", "Sound Clip", "Gospel", "Noise", # 40
	      "AlternRock", "Bass", "Soul", "Punk", "Space", # 45
	      "Meditative", "Instrumental Pop", "Instrumental Rock", "Ethnic", "Gothic", # 50
	      "Darkwave", "Techno-Industrial", "Electronic", "Pop-Folk", "Eurodance", # 55
	      "Dream", "Southern Rock", "Comedy", "Cult", "Gangsta Rap", # 60
	      "Top 40", "Christian Rap", "Pop/Funk", "Jungle", "Native American", # 65
	      "Cabaret", "New Wave", "Psychedelic", "Rave", "Showtunes", # 70
	      "Trailer", "Lo-Fi", "Tribal", "Acid Punk", "Acid Jazz", # 75
	      "Polka", "Retro", "Musical", "Rock & Roll", "Hard Rock", # 80
	      "Folk", "Folk/Rock", "National Folk", "Swing", "Fast-Fusion", # 85
	      "Bebob", "Latin", "Revival", "Celtic", "Bluegrass", # 90
	      "Avantgarde", "Gothic Rock", "Progressive Rock", "Psychedelic Rock", "Symphonic Rock", # 95
	      "Slow Rock", "Big Band", "Chorus", "Easy Listening", "Acoustic", # 100
	      "Humour", "Speech", "Chanson", "Opera", "Chamber Music", # 105
	      "Sonata", "Symphony", "Booty Bass", "Primus", "Porn Groove", # 110
	      "Satire", "Slow Jam", "Club", "Tango", "Samba", # 115
	      "Folklore", "Ballad", "Power Ballad", "Rhythmic Soul", "Freestyle", # 120
	      "Duet", "Punk Rock", "Drum Solo", "A Cappella", "Euro-House", # 125
	      "Dance Hall", "Goa", "Drum & Bass", "Club-House", "Hardcore", # 130
	      "Terror", "Indie", "BritPop", "Negerpunk", "Polsk Punk", # 135
	      "Beat", "Christian Gangsta Rap", "Heavy Metal", "Black Metal", "Crossover", # 140
	      "Contemporary Christian", "Christian Rock", "Merengue", "Salsa", "Thrash Metal", # 145
	      "Anime", "JPop", "Synthpop",
	      ) ;

sub check_mp3info_genre {
    my $genre = shift ;
    return scalar ( grep { lc($genre) eq lc($_) } @mp3info_genres ) ;
}

sub check_id3v1_tracknumber {
    my $number = shift ;
    return ( $number =~ m/^\d+$/ and $number <= 255 ) ;
}

sub fix_values_for_mp3info {
    my $self = shift ;
    my $values = shift ;

    # only regular fields are supported
    foreach my $field (Lltag::Tags::get_values_non_regular_keys ($self, $values)) {
	Lltag::Misc::print_warning ("    ", "Cannot set $field in MP3 ID3v1 tags") ;
	delete $values->{$field} ;
    }

    # remove unsupported genres and keep a single value
    my @genres = Lltag::Tags::get_tag_value_array ($self, $values, 'GENRE') ;
    delete $values->{GENRE} ;
    my @supported_genres = map {
	my $genre = $_ ;
	if (check_mp3info_genre $genre) {
	    $genre ;
	} else {
	    Lltag::Misc::print_warning ("    ", "Genre $genre is not supported") ;
	    () ;
	}
    } (@genres) ;
    if (@supported_genres) {
	$values->{GENRE} = $supported_genres[0] ;
    }

    # remove unsupported tracknumbers and keep a single value
    my @numbers = Lltag::Tags::get_tag_value_array ($self, $values, 'NUMBER') ;
    delete $values->{NUMBER} ;
    my @supported_numbers = map {
	my $number = $_ ;
	if (check_id3v1_tracknumber $number) {
	    $number ;
	} else {
	    Lltag::Misc::print_warning ("    ", "Track number $number is not supported") ;
	    () ;
	}
    } (@numbers) ;
    if (@supported_numbers) {
	$values->{NUMBER} = $supported_numbers[0] ;
    }

    # keep a single value
    foreach my $field (keys %{$values}) {
	my $val = Lltag::Tags::get_tag_unique_value ($self, $values, $field) ;
	delete $values->{$field} ;
	$values->{$field} = $val ;
    }
}

#######################################################

sub read_tags {
    my $self = shift ;
    my $file = shift ;
    my ($status, @output) = Lltag::Misc::system_with_output
	("mp3info", "-p", "ARTIST=%a\nALBUM=%l\nTITLE=%t\nNUMBER=%n\nGENRE=%g\nDATE=%y\nCOMMENT=%c\n", $file) ;
    return undef
	if $status ;
    return Lltag::Tags::convert_tag_stream_to_values ($self, @output) ;
}

sub set_tags {
    my $self = shift ;
    my $file = shift ;
    my $values = shift ;
    my %field_name_mp3info_option =
	(
	 'ARTIST'  => 'a',
	 'TITLE'   => 't',
	 'ALBUM'   => 'l',
	 'NUMBER'  => 'n',
	 'GENRE'   => 'g',
	 'DATE'    => 'y',
	 'COMMENT' => 'c'
	 ) ;
    my @mp3_tagging_cmd = ( 'mp3info' ) ;
    my @mp3_tagging_clear_option = map { ( "-$_" , "" ) } (values %field_name_mp3info_option) ;

    fix_values_for_mp3info $self, $values ;

    my @system_args
	= ( @mp3_tagging_cmd ,
	    # clear all tags
	    @mp3_tagging_clear_option ,
	    # apply new tags
	    ( map {
		( "-".$field_name_mp3info_option{$_} , $values->{$_} )
		} (keys %{$values})
	      ),
	    $file ) ;

    Lltag::Tags::set_tags_with_external_prog ($self, @system_args) ;
}

sub new {
    my $self = shift ;

    return undef
	if test_mp3info $self ;

    return {
	name => "MP3 (using mp3info)",
	type => "mp3",
	extension => "mp3",
	read_tags => \&read_tags,
	set_tags => \&set_tags,
    } ;
}

1 ;
