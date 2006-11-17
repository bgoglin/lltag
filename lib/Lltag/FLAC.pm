package Lltag::FLAC ;

use strict ;

require Lltag::Tags ;
require Lltag::Misc ;

sub test_metaflac {
    my $self = shift ;
    # cannot test with "metaflac -h" since it returns 1
    my ($status, @output) = Lltag::Misc::system_with_output ("metaflac", "/dev/null") ;
    print "metaflac does not seem to work, disabling 'Flac' backend.\n"
	if $status and $self->{verbose_opt} ;
    return $status ;
}

sub read_tags {
    my $self = shift ;
    my $file = shift ;
    my ($status, @output) = Lltag::Misc::system_with_output
	("metaflac", "--list", "--block-type=VORBIS_COMMENT", $file) ;
    return undef
	if $status ;
    @output = map {
	my $line = $_ ;
	$line =~ s/^\s*comment\[\d+\]\s*:\s*(.*)/$1/ ;
	$line =~ s/^TRACKNUMBER=/NUMBER=/ ;
	$line
	} ( grep { /comment\[\d+\]/ } @output ) ;
    return Lltag::Tags::convert_tag_stream_to_values ($self, @output) ;
}

sub set_tags {
    my $self = shift ;
    my $file = shift ;
    my $values = shift ;

    my %field_name_flac_translations =
	(
	 'NUMBER'  => 'TRACKNUMBER',
	 ) ;
    my @flac_tagging_cmd = ( 'metaflac' ) ;
    my @flac_tagging_clear_option = ( '--remove-all-tags' ) ;

    my @system_args
	= ( @flac_tagging_cmd ,
	    # clear all tags
	    @flac_tagging_clear_option ,
	    # apply new tags
	    ( map {
		my $flacname = $_ ;
		$flacname = $field_name_flac_translations{$_} if defined $field_name_flac_translations{$_} ;
		my @tags = Lltag::Tags::get_tag_value_array ($self, $values, $_) ;
		map { ( "--set-tag", $flacname."=".$_ ) } @tags
		} @{$self->{field_names}}
	      ),
	    # apply non-regular tags
	    ( map {
		my $flacname = $_ ;
		my @tags = Lltag::Tags::get_tag_value_array ($self, $values, $_) ;
		map { ( "--set-tag", $flacname."=".$_ ) } @tags
		} Lltag::Tags::get_values_non_regular_keys ($self, $values)
	      ),
	    $file ) ;

    Lltag::Tags::set_tags_with_external_prog ($self, @system_args) ;
}

sub new {
    my $self = shift ;

    return undef
	if test_metaflac $self ;

    return {
	name => "Flac (using metaflac)",
	type => "flac",
	extension => "flac",
	read_tags => \&read_tags,
	set_tags => \&set_tags,
    } ;
}

1 ;
