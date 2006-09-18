package Lltag::MP3 ;

use strict ;

require Lltag::Tags ;
require Lltag::Misc ;

use vars qw(@EXPORT) ;

@EXPORT = qw (
	      read_tags
	      tagging_system_args
	  ) ;

sub read_tags {
    my $self = shift ;
    my $file = shift ;
    my ($status, @output) = Lltag::Misc::system_with_output
	("mp3info", "-p", "ARTIST=%a\nALBUM=%l\nTITLE=%t\nNUMBER=%n\nGENRE=%g\nDATE=%y\nCOMMENT=%c\n", $file) ;
    return ($status)
	if $status ;
    return ($status, @output) ;
}

sub tagging_system_args {
    my $self = shift ;
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

    map {
	Lltag::Misc::print_warning ("    ", "Cannot set $_ in mp3 tags") ;
    } (Lltag::Tags::get_values_non_regular_keys ($self, $values)) ;

    return ( @mp3_tagging_cmd ,
	     # clear all tags
	     @mp3_tagging_clear_option ,
	     # apply new tags
	     ( map {
		 # only one tag is allowed, use the first one
		 ( "-".$field_name_mp3info_option{$_} , (Lltag::Tags::get_tag_unique_value ($self, $values, $_)) )
		 } ( grep { defined $values->{$_} } @{$self->{field_names}} )
	       ),
	     ) ;
}

1 ;
