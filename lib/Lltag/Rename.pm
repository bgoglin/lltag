package Lltag::Rename ;

use strict ;

use Lltag::Misc ;

# constants for rename format specific letters
use constant DIRNAME_LETTER => "P" ;
use constant BASENAME_LETTER => "F" ;
use constant EXTENSION_LETTER => "E" ;

# confirmation behavior
my $current_rename_yes_opt ;

#######################################################
# rename specific usage

sub rename_usage {
    my $self = shift ;
    print " Renaming options:\n" ;
    print "  --rename <format>      Rename file according to format\n" ;
    print "  --rename-min           Lowcase tags before renaming\n" ;
    print "  --rename-sep <s>       Replace space with s in tags before renaming\n" ;
    print "  --rename-regexp <reg>  Apply a replace regexp to tags before renaming\n" ;
    print "  --rename-ext           Assume the rename format provides an extension\n" ;
}

#######################################################
# rename format specific usage

sub rename_format_usage {
    my $self = shift ;
    print "  %".BASENAME_LETTER." means the original basename of the file\n" ;
    print "  %".EXTENSION_LETTER." means the original extension of the file\n" ;
    print "  %".DIRNAME_LETTER." means the original path of the file\n" ;
}

#######################################################
# init

my $rename_confirm_usage_forced ;

sub init_renaming {
    my $self = shift ;

    # default confirmation behavior
    $current_rename_yes_opt = $self->{yes_opt} ;

    # need to show menu usage once ?
    $rename_confirm_usage_forced = $self->{menu_usage_once_opt} ;
}

#######################################################
# rename confirmation

sub rename_confirm_usage {
    Lltag::Misc::print_usage_header ("   ", "Renaming files") ;
    print "      y => Yes, rename this file (default)\n" ;
    print "      a => Always rename without asking\n" ;
    print "      e => Edit the filename before tagging\n" ;
    print "      n/q => No, don't rename this file\n" ;
    print "      h => Show this help\n" ;
    $rename_confirm_usage_forced = 0 ;
}

#######################################################
# main rename routine

sub rename_with_values {
    my $self = shift ;
    my $file = shift ;
    my $extension = shift ;
    my $values = shift ;

    my $rename_values = {} ;
    my $undefined = 0 ;

    print "  Renaming with format '$self->{rename_opt}'...\n" ;

    foreach my $field (keys %{$values}) {
	# use the first tag for renaming
	my $val = Lltag::Tags::get_tag_unique_value ($self, $values, $field) ;
	$val = lc ($val)
	    if $self->{rename_min_opt} ;
	$val =~ s/ /$self->{rename_sep_opt}/g
	    if $self->{rename_sep_opt} ;
	map { $val = Lltag::Tags::apply_regexp_to_tag ($val, $_, $field) } @{$self->{rename_regexp_opts}} ;
	$rename_values->{$field} = $val ;
    }

    my $format_string = $self->{rename_opt} ;
    my @array = split(//, $format_string) ;
    for(my $i = 0; $i < @array - 1; $i++) {

	# normal characters
	next if $array[$i] ne "%" ;

	# remove % and check next char
	splice (@array, $i, 1) ;
	# replace the char with the matching
	my $char = $array[$i] ;
	next if $char eq "%" ;
	if ($char =~ m/$self->{field_letters_union}/) {
	    my $field = $self->{field_letter_name}{$char} ;
	    my $val = $rename_values->{$field} ;
	    # rename does not contain an array anymore
	    if (not defined $val) {
		$undefined++ ;
		Lltag::Misc::print_warning ("    ", "Undefined field '".$field."'") ;
		$val = "" ;
	    }
	    if ($char eq 'n') {
		# initialize track number to 0 if empty
		$val = "0" if !$val ;
		# make it at least 2 digits
		$val = '0'.$val if $val < 10 and length $val < 2 ;
	    }
	    $array[$i] = $val ;

	} elsif ($char eq BASENAME_LETTER) {
	    my $basename ;
	    if ($file =~ m@([^/]+)\.[^./]+$@) {
		$basename = $1 ;
	    } elsif ($file =~ m@([^/]+)$@) {
		$basename = $1 ;
	    } else {
		$basename = $file ;
	    }
	    $array[$i] = $basename ;

	} elsif ($char eq EXTENSION_LETTER) {
	    my $extension ;
	    if ($file =~ m@\.([^./]+)$@) {
		$extension = $1 ;
	    } else {
		$extension = "" ;
	    }
	    $array[$i] = $extension ;

	} elsif ($char eq DIRNAME_LETTER) {
	    my $path ;
	    if ($file =~ m@^(.*/)[^/]+@) {
		$path = $1 ;
	    } else {
		$path = "" ;
	    }
	    $array[$i] = $1 ;

	} else {
	    $array[$i] = "%".$char ;
	}
    }

    my $new_name = join ("", @array) ;

    $new_name .= ".". $extension
	unless $self->{rename_ext_opt} ;

    print "    New filename is '$new_name'\n" ;

    # confirm if required or if any field undefined
    if ($undefined or !$current_rename_yes_opt) {

	rename_confirm_usage
	    if $rename_confirm_usage_forced ;

      ASK_CONFIRM:
	my $reply = Lltag::Misc::readline ("    ", "Really rename the file [yaeq] (default is yes, h for help)", "", -1) ;
	chomp $reply ;

        if ($reply eq "" or $reply =~ m/^y/i) {
            goto RENAME_IT ;

	} elsif ($reply =~ m/^a/) {
	    $current_rename_yes_opt = 1 ;
            goto RENAME_IT ;

	} elsif ($reply =~ m/^n/ or $reply =~ m/^q/) {
	    return ;

	} elsif ($reply =~ m/^e/) {
	    $new_name = Lltag::Misc::readline ("      ", "New filename", $new_name, 0) ;
	    goto ASK_CONFIRM ;

	} else {
	    rename_confirm_usage ;
	    goto ASK_CONFIRM ;
	}
    }

  RENAME_IT:
    if ($new_name eq $file) {
	print "    Filename would not change, not renaming\n" ;
	return ;
    }

    if (-e $new_name) {
	print "    File $new_name already exists, not renaming\n" ;
	return ;
    }

    return
	if $self->{dry_run_opt} ;

    my $remain = $new_name ;
    my $path = '' ;
    while ($remain =~ m@^([^/]*/+)(.*)$@) {
        $path .= $1 ;
	$remain = $2 ;
	if (!-d $path) {
	    print "      Creating directory '$path'\n" ;
	    if (!mkdir $path) {
		Lltag::Misc::print_error ("      ", "Failed to create directory ($!).") ;
		return ;
	    }
	}
    }

    print "    Renaming.\n" ;
    rename $file, $new_name
	or Lltag::Misc::print_error ("    ", "Failed to rename ($!).") ;
}

1 ;
