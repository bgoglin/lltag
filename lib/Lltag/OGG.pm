package Lltag::OGG ;

use strict ;

require Lltag::Tags ;
require Lltag::Misc ;

#use Exporter ;
use vars qw(@EXPORT) ;

@EXPORT = qw (
	      read_tags
	      tagging_system_args
	  ) ;

sub read_tags {
    my $self = shift ;
    my $file = shift ;
    my ($status, @output) = Lltag::Misc::system_with_output
	("vorbiscomment", "-l", $file) ;
    return ($status)
	if $status ;
    @output = map {
	my $line = $_ ;
	$line =~ s/^TRACKNUMBER=/NUMBER=/ ;
	$line
	} @output ;
    return ($status, @output) ;
}

sub tagging_system_args {
    my $self = shift ;
    my $values = shift ;
    my %field_name_ogg_translations =
	(
	 'NUMBER'  => 'TRACKNUMBER',
	 ) ;
    my @ogg_tagging_cmd = ( 'vorbiscomment', '-q' ) ;
    my @ogg_tagging_clear_option = ( '-w' ) ;

    return ( @ogg_tagging_cmd ,
	     # clear all tags
	     @ogg_tagging_clear_option ,
	     # apply new tags
	     ( map {
		 my $oggname = $_ ;
		 $oggname = $field_name_ogg_translations{$_} if defined $field_name_ogg_translations{$_} ;
		 my @tags = (Lltag::Tags::get_tag_value_array $self, $values, $_) ;
		 map { ( "-t" , $oggname."=".$_ ) } @tags
		 } @{$self->{field_names}}
	       ),
	     # apply non-regular tags
	     ( map {
		 my $oggname = $_ ;
		 my @tags = (Lltag::Tags::get_tag_value_array $self, $values, $_) ;
		 map { ( "-t" , $oggname."=".$_ ) } @tags
		 } Lltag::Tags::get_values_non_regular_keys ($self, $values)
	       ),
	     ) ;
}

1 ;
