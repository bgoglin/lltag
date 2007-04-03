package Lltag::OGG ;

use strict ;

require Lltag::Tags ;
require Lltag::Misc ;

sub test_vorbiscomment {
    my $self = shift ;
    my ($status, @output) = Lltag::Misc::system_with_output ("vorbiscomment", "-h") ;
    print "vorbiscomment does not seem to work, disabling 'OGG' backend.\n"
	if $status and $self->{verbose_opt} ;
    return $status ;
}

sub read_tags {
    my $self = shift ;
    my $file = shift ;
    my ($status, @output) = Lltag::Misc::system_with_output
	("vorbiscomment", "-l", $file) ;
    return undef
	if $status ;
    @output = map {
	my $line = $_ ;
	$line =~ s/^TRACKNUMBER=/NUMBER=/ ;
	$line
	} @output ;
    return Lltag::Tags::convert_tag_stream_to_values ($self, @output) ;
}

sub set_tags {
    my $self = shift ;
    my $file = shift ;
    my $values = shift ;

    my %field_name_ogg_translations =
	(
	 'NUMBER'  => 'TRACKNUMBER',
	 ) ;
    my @ogg_tagging_cmd = ( 'vorbiscomment', '-q' ) ;
    my @ogg_tagging_clear_option = ( '-w' ) ;

    # apply regular tags
    my @regular_tags_args =
	    ( map {
		my $oggname = $_ ;
		$oggname = $field_name_ogg_translations{$_} if defined $field_name_ogg_translations{$_} ;
		my @tags = (Lltag::Tags::get_tag_value_array $self, $values, $_) ;
		map { ( "-t" , $oggname."=".$_ ) } @tags
		} @{$self->{field_names}}
	      ) ;
    # apply non-regular tags
    my @non_regular_tags_args =
	    ( map {
		my $oggname = $_ ;
		my @tags = (Lltag::Tags::get_tag_value_array $self, $values, $_) ;
		map { ( "-t" , $oggname."=".$_ ) } @tags
		} Lltag::Tags::get_values_non_regular_keys ($self, $values)
	      ) ;
    # work-around vorbiscomment which does not like when tags is passed
    my @workaround_args = (scalar @regular_tags_args + @non_regular_tags_args) ? () : ("-c", "/dev/null") ;

    my @system_args
	= ( @ogg_tagging_cmd ,
	    # clear all tags
	    @ogg_tagging_clear_option ,
	    @regular_tags_args ,
	    @non_regular_tags_args ,
	    @workaround_args ,	    
	    $file ) ;

    Lltag::Tags::set_tags_with_external_prog ($self, @system_args) ;
}

sub new {
    my $self = shift ;

    return undef
	if test_vorbiscomment $self ;

    return {
	name => "OGG (using vorbiscomment)",
	type => "ogg",
	extension => "ogg",
	read_tags => \&read_tags,
	set_tags => \&set_tags,
    } ;
}

1 ;
