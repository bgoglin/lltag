package Lltag::Rename ;

use strict ;

sub rename_usage {
    my $self = shift ;
    print " Renaming options:\n" ;
    print "  --rename <format>      Rename file according to format\n" ;
    print "  --rename-min           Lowcase tags before renaming\n" ;
    print "  --rename-sep <s>       Replace space with s in tags before renaming\n" ;
    print "  --rename-regexp <reg>  Apply a replace regexp to tags before renaming\n" ;
    print "  --rename-ext           Assume the rename format provides an extension\n" ;
}

sub rename_confirm_usage {
    my $behaviors = shift ;
    print "      y => Yes, rename this file (default)\n" ;
    print "      a => Always rename without asking\n" ;
    print "      e => Edit the filename before tagging\n" ;
    print "      n => No, don't rename this file\n" ;
    print "      h => Show this help\n" ;
}

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
	map { $val = apply_regexp_to_tag ($val, $_, $field) } @{$self->{rename_regexp_opts}} ;
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
	if ($char =~ /$self->{field_letters_union}/) {
	    my $field = $self->{field_letter_name}{$char} ;
	    my $val = $rename_values->{$field} ;
	    # rename does not contain an array anymore
	    if (not defined $val) {
		$undefined++ ;
		print "    WARNING: Undefined field '".$field."'.\n" ;
		$val = "" ;
	    }
	    if ($char eq 'n') {
		# initialize track number to 0 if empty
		$val = "0" if !$val ;
		# make it at least 2 digits
		$val = '0'.$val if $val < 10 and length $val < 2 ;
	    }
	    $array[$i] = $val ;
	} else {
	    $array[$i] = "%".$char ;
	}
    }

    my $new_name = join ("", @array) ;

    $new_name .= ".". $extension
	unless $self->{rename_ext_opt} ;

    print "    New filename is '$new_name'\n" ;

    # confirm if required or if any field undefined
    if ($undefined or !$self->{current_rename_yes_opt}) {
      ASK_CONFIRM:
	Lltag::Misc::print_question ("    Really rename the file [<y>aen,(h)elp] ? ") ;
	my $reply = <> ;
	chomp $reply ;
        if ($reply eq "" or $reply =~ /^y/i) {
            goto RENAME_IT ;
	} elsif ($reply =~ /^a/i) {
	    $self->{current_rename_yes_opt} = 1 ;
            goto RENAME_IT ;
	} elsif ($reply =~ /^n/i) {
	    return ;
	} elsif ($reply =~ /^e/i) {
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
    while ($remain =~ /^([^\/]*\/+)(.*)$/) {
        $path .= $1 ;
	$remain = $2 ;
	if (!-d $path) {
	    print "      Creating directory '$path'\n" ;
	    if (!mkdir $path) {
		print "      ERROR: Failed to create directory ($!)\n" ;
		return ;
	    }
	}
    }

    print "    Renaming.\n" ;
    rename $file, $new_name
	or print "    ERROR: Failed to rename ($!)\n" ;
}

1 ;
