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

    if ($field =~ / -> _/) {
	print $prefix.ucfirst($field).": <binary data>\n"
    } elsif (ref($values->{$field}) ne 'ARRAY') {
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

# clone tag values (to be able to modify without changing the original)
sub clone_tag_values {
    my $old_values = shift ;
    return undef unless defined $old_values ;

    # clone the hash
    my %new_values = %{$old_values} ;

    for my $field (keys %new_values) {
	if (ref($new_values{$field}) eq 'ARRAY') {
	    # clone the array pointed by the ref in the hash
	    @{$new_values{$field}} = @{$new_values{$field}} ;
	}
    }

    return \%new_values ;
}

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

# add a set of new values into an old hash, depending of clear/append options
sub merge_new_tag_values {
    my $self = shift ;
    my $old_values = shift ;
    my $new_values = shift ;

    if ($self->{clear_opt}) {
	$old_values = {} ;
    }

    foreach my $field (keys %{$new_values}) {
	delete $old_values->{$field}
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

# handle explicit tag values
sub process_explicit_tag_value {
    my $self = shift ;
    my $string = shift ;
    if ($string =~ m/^([^=]+)=(.*)$/) {
	append_tag_value $self, $self->{explicit_values}, $1, $2 ;
    } else {
	die "Explicit tags must be given as 'TAG=value'.\n" ;
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

	# remove the track total from the track number to avoid renaming problems with slashes or so
	if ($field eq "NUMBER") {
	    if ($value =~ /^(\d+)/) {
		$value = $1 ;
	    } else {
		return ;
	    }
	}

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

use constant EDIT_SUCCESS => 0 ;
use constant EDIT_CANCEL => -1;

sub edit_values_usage {
    my $self = shift ;
    my $values = shift ;

    Lltag::Misc::print_usage_header ("    ", "Editing") ;

    # print all fields, including the undefined ones
    foreach my $field (@{$self->{field_names}}) {
	print "      ".$self->{field_name_letter}{$field}
	." => Edit ".ucfirst($field).$self->{field_name_trailing_spaces}{$field}
	."\n" ;
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

# edit values in place
sub edit_values {
    my $self = shift ;
    my $values = shift ;

    edit_values_usage $self, $values
	if $edit_values_usage_forced ;

    print "      Current tag values are:\n" ;
    display_tag_values $self, $values, "        " ;

    while (1) {
	my $edit_reply = Lltag::Misc::readline ("    ", "Edit a field [". $self->{field_letters_string} ."Vyq] (no default, h for help)", "", -1) ;

	# if ctrl-d, cancel editing
	$edit_reply = 'q' unless defined $edit_reply ;

	if ($edit_reply =~ m/^tag (.+)/) {
	    edit_one_value $self, $values, $1 ;

	} elsif ($edit_reply =~ m/^($self->{field_letters_union})/) {
	    edit_one_value $self, $values, $self->{field_letter_name}{$1} ;

	} elsif ($edit_reply =~ m/^y/ or $edit_reply =~ m/^E/) {
	    return EDIT_SUCCESS ;

	} elsif ($edit_reply =~ m/^q/ or $edit_reply =~ m/^C/) {
	    return EDIT_CANCEL ;

	} elsif ($edit_reply =~ m/^V/) {
	    print "      Current tag values are:\n" ;
	    display_tag_values $self, $values, "        " ;

	} else {
	    edit_values_usage $self, $values ;
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

#######################################################
# clone tag values (to be able to modify without changing the original) and merge tags case-insensitively

sub clone_tag_values_uc {
    my $self = shift ;
    my $old_values = shift ;

    return undef unless defined $old_values ;

    # clone the hash
    my %new_values;

    # use upcase values first
    for my $field (keys %{$old_values}) {
	if ($field eq uc($field)) {
	    append_tag_multiple_value $self, \%new_values, uc($field), $old_values->{$field} ;
	}
    }
    # other values then
    for my $field (keys %{$old_values}) {
	if ($field ne uc($field)) {
	    append_tag_multiple_value $self, \%new_values, uc($field), $old_values->{$field} ;
	}
    }

    return \%new_values ;
}

1 ;
