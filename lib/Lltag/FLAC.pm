package Lltag::FLAC ;

use strict ;

require Lltag::Tags ;
require Lltag::Misc ;

sub read_tags {
    my $self = shift ;
    my $file = shift ;
    my ($status, @output) = Lltag::Misc::system_with_output
	("metaflac", "--list", "--block-type=VORBIS_COMMENT", $file) ;
    return ($status)
	if $status ;
    @output = map {
	my $line = $_ ;
	$line =~ s/^\s*comment\[\d+\]\s*:\s*(.*)/$1/ ;
	$line =~ s/^TRACKNUMBER=/NUMBER=/ ;
	$line
	} ( grep { /comment\[\d+\]/ } @output ) ;
    return ($status, @output) ;
}

sub tagging_system_args {
    my $self = shift ;
    my $values = shift ;
    my %field_name_flac_translations =
	(
	 'NUMBER'  => 'TRACKNUMBER',
	 ) ;
    my @flac_tagging_cmd = ( 'metaflac' ) ;
    my @flac_tagging_clear_option = ( '--remove-all-tags' ) ;

    return ( @flac_tagging_cmd ,
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
	     ) ;
}

sub register_backend {
    # FIXME: check metaflac
    return {
       name => "Flac (using metaflac)",
       type => "flac",
       extension => "flac",
       read_tags => \&read_tags,
       tagging_system_args => \&tagging_system_args,
    } ;
}

1 ;
