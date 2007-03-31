package Lltag::Tags ;

use strict ;
no strict "refs" ;

#######################################################
# init

my $edit_values_usage_forced ;

sub init_tagging {
    my $self = shift ;

    # need to show menu usage once ?
    $edit_values_usage_forced = $self->{menu_usage_once_opt} ;
}

#######################################################
# display tag values

sub display_one_tag_value {
    my $self = shift ;
    my $values = shift ;
    my $field = shift ;
    my $prefix = shift ;

    if (ref($values->{$field}) ne 'ARRAY') {
	print $prefix.ucfirst($field).": "
	    . ($values->{$field} eq "" ? "<CLEAR>" : $values->{$field}) ."\n"
    } else {
	my @vals = @{$values->{$field}} ;
	for(my $i = 0; $i < @vals; $i++) {
	    print $prefix.ucfirst($field)." #".($i+1).": ".$vals[$i]."\n"
	}
    }
}

sub display_tag_values {
    my $self = shift ;
    my $values = shift ;
    my $prefix = shift ;

    # display regular tags first
    foreach my $field (@{$self->{field_names}}) {
	next unless defined $values->{$field} ;
	display_one_tag_value $self, $values, $field, $prefix ;
    }

    # display misc tags later
    foreach my $field (keys %{$values}) {
	next if grep { $field eq $_ } @{$self->{field_names}} ;
	display_one_tag_value $self, $values, $field, $prefix ;
    }
}

#######################################################
# various tag management routines

# add a value to a field, creating an array if required
sub append_tag_value {
    my $self = shift ;
    my $values = shift ;
    my $field = shift ;
    my $value = shift ;
    if (not defined $values->{$field}) {
	$values->{$field} = $value ;
    } elsif (ref($values->{$field}) ne 'ARRAY') {
	# create an array (except if we already have this value)
	my $tmp = $values->{$field} ;
	if ($tmp ne $value) {
	    # need to delete the hash ref before changing its type
	    delete $values->{$field} ;
	    @{$values->{$field}} = ($tmp, $value) ;
	}
    } else {
	# append to the array (except if we already have this value)
	push @{$values->{$field}}, $value
	    unless grep { $value eq $_ } @{$values->{$field}} ;
    }
}

# add a value or an array of values to a tag
sub append_tag_multiple_value {
    my $self = shift ;
    my $values = shift ;
    my $field = shift ;
    my $multiple_value = shift ;

    if (ref($multiple_value) ne 'ARRAY') {
	append_tag_value $self, $values, $field, $multiple_value ;
    } else {
	map {
	    append_tag_value $self, $values, $field, $_ ;
	} @{$multiple_value} ;
    }
}

# append a hash of values (either unique or arrays) into another hash
sub append_tag_values {
    my $self = shift ;
    my $old_values = shift ;
    my $new_values = shift ;

    foreach my $field (keys %{$new_values}) {
	append_tag_multiple_value $self, $old_values, $field, $new_values->{$field} ;
    }
}

# add a set of unique values into another hash, depending of clear/append options
sub merge_new_tag_values {
    my $self = shift ;
    my $old_values = shift ;
    my $new_values = shift ;

    if ($self->{clear_opt}) {
	$old_values = {} ;
    }

    foreach my $field (keys %{$new_values}) {
	$old_values->{$field} = undef
	    if defined $old_values->{$field} and !$self->{append_opt} ;
	append_tag_multiple_value $self, $old_values, $field, $new_values->{$field} ;
    }

    return $old_values ;
}

# return values for a field as an array
sub get_tag_value_array {
    my $self = shift ;
    my $values = shift ;
    my $field = shift ;
    if (not defined $values->{$field}) {
	return () ;
    } elsif (ref ($values->{$field}) ne 'ARRAY') {
	return ($values->{$field}) ;
    } else {
	return @{$values->{$field}} ;
    }
}

# return a unique value for a field
sub get_tag_unique_value {
    my $self = shift ;
    my $values = shift ;
    my $field = shift ;
    my @array = get_tag_value_array $self, $values, $field ;
    die "Trying to return a unique tag value on an empty array.\n"
	if ! @array ;
    return $array[0] ;
}

# return non-regular keys whose value is defined
sub get_values_non_regular_keys {
    my $self = shift ;
    my $values = shift ;
    return grep {
	my $key = $_ ;
	!(grep { $_ eq $key } @{$self->{field_names}})
    } (keys %{$values}) ;
}

# handle additional tags
sub process_additional_tag_value {
    my $self = shift ;
    my $string = shift ;
    if ($string =~ m/^([^=]+)=(.*)$/) {
	append_tag_value $self, $self->{additional_values}, $1, $2 ;
    } else {
	die "Additional tags must be given as 'TAG=value'.\n" ;
    }
}

#######################################################
# extract tags from the stream
# helper to be used by backends who get the tags as the stream output of another program

sub convert_tag_stream_to_values {
    my $self = shift ;
    my $values = {} ;

    while (my $line = shift @_) {
	chomp $line ;
	my ($field, $value) = ($line =~ m/^(.*)=(.*)$/) ;
	next if !$value ;
	Lltag::Tags::append_tag_value ($self, $values, $field, $value) ;
    }

    return $values ;
}

#######################################################
# get tagging command line, display it if required, execute it if required
# output the errors, ...
# helper to be used by backends who set the tags with another program

sub set_tags_with_external_prog {
    my $self = shift ;

    # show command line and really tag if asked
    if ($self->{dry_run_opt} or $self->{verbose_opt}) {
	print "  '". +(join "' '", @_) ."'\n" ;
    }
    if (!$self->{dry_run_opt}) {
	print "  Tagging.\n" ;
	my ($status, @output) = Lltag::Misc::system_with_output (@_) ;
	if ($status) {
	    print "    Tagging failed, command line was: '". join ("' '", @_) ."'.\n" ;
	    while (my $line = shift @output) {
		print "# $line" ;
	    }
	}
    }
}

#######################################################
# edit current tags

sub edit_values_usage {
    my $self = shift ;
    my $values = shift ;
    my $field_names_ref = shift ;

    my @field_names = @{$field_names_ref} ;

    Lltag::Misc::print_usage_header ("    ", "Editing") ;

    # print all fields, including the undefined ones
    foreach my $field (@field_names) {
	my $val = $values->{$field} ;
	if (not defined $val) {
	    $val = "<not defined>" ;
	} elsif (ref($val) eq 'ARRAY') {
	    $val = join(" ; ", @{$val}) ;
	} elsif ($val eq "") {
	    $val = "<CLEAR>" ;
	}
	print "      ".$self->{field_name_letter}{$field}
	." => Edit ".ucfirst($field).$self->{field_name_trailing_spaces}{$field}
	." (".$val.")\n" ;
    }
    print "      tag FOO => Edit tag FOO\n" ;
    print "      V => View current fields\n" ;
    print "      y/E => End edition\n" ;
    print "      q/C => Cancel edition\n" ;
    print "    During edition, enter <DELETE> to drop a value.\n" ;

    $edit_values_usage_forced = 0 ;
}

sub edit_one_value {
    my $self = shift ;
    my $values = shift ;
    my $field = shift ;

    if (ref($values->{$field}) eq 'ARRAY') {
	my @oldvals = @{$values->{$field}} ;
	my @newvals = () ;
	for(my $i=0; $i<@oldvals; $i++) {
	    my $value = Lltag::Misc::readline ("      ", ucfirst($field)." field #".($i+1), $oldvals[$i], 1) ;

	    if (defined $value) {
		push @newvals, $value
		    unless $value eq "" ;
	    } else {
		# if ctrl-d, reset to same value, without removing it if empty
		push @newvals, $oldvals[$i] ;
	    }
	}
	delete $values->{$field} ;
	if (@newvals == 1) {
	    $values->{$field} = $newvals[0] ;
	} elsif (@newvals) {
	    @{$values->{$field}} = @newvals ;
	} else {
	    $values->{$field} = "" ;
	}

    } else {
	my $value = Lltag::Misc::readline ("      ", ucfirst($field)." field", $values->{$field}, 1) ;

	# if ctrl-d, change nothing
	if (defined $value) {
	    if ($value eq "DELETE" or $value eq "<DELETE>") {
		delete $values->{$field} ;
	    } else {
		$values->{$field} = $value ;
	    }
	}
    }
}

sub edit_values {
    my $self = shift ;
    my $values = shift ;
    my $field_names_ref = shift ;

    my @field_names = @{$field_names_ref} ;
    my @letters = map { $self->{field_name_letter}{$_} } @field_names ;
    my $letters_union = join '|', @letters ;

    # save values
    my $old_values = () ;
    map { $old_values->{$_} = $values->{$_} } (keys %{$values}) ;

    edit_values_usage $self, $values, $field_names_ref
	if $edit_values_usage_forced ;

    while (1) {
	my $edit_reply = Lltag::Misc::readline ("    ", "Edit a field [". (join '', @letters) ."Vyq] (no default, h for help)", "", -1) ;

	# if ctrl-d, cancel editing
	$edit_reply = 'q' unless defined $edit_reply ;

	if ($edit_reply =~ m/^tag (.+)/) {
	    edit_one_value $self, $values, $1 ;

	} elsif ($edit_reply =~ m/^($letters_union)/) {
	    edit_one_value $self, $values, $self->{field_letter_name}{$1} ;

	} elsif ($edit_reply =~ m/^y/ or $edit_reply =~ m/^E/) {
	    return $values ;

	} elsif ($edit_reply =~ m/^q/ or $edit_reply =~ m/^C/) {
	    return $old_values ;

	} elsif ($edit_reply =~ m/^V/) {
	    print "      Current tag values are:\n" ;
	    display_tag_values $self, $values, "        " ;

	} else {
	    edit_values_usage $self, $values, $field_names_ref ;
	}
    }
}

#######################################################
# apply user-given regexp

sub apply_regexp_to_tag {
    my $val = shift ;
    my $regexp = shift ;
    my $tag = shift ;

    # parse the regexp
    if ($regexp =~ m@(?:([^:]+):)?s/([^/]+)/([^/]*)/$@) {
	my @tags = () ;
	@tags = split (/,/, $1) if $1;
	my $from = $2 ;
	my $to = $3 ;
	$val =~ s/$from/$to/g
	    if !@tags or grep { $tag eq $_ } @tags ;
    } else {
	die "Unrecognized user regexp '$regexp'.\n" ;
    }

    return $val ;
}

1 ;
