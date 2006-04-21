package Lltag::Tags ;

use strict ;
no strict "refs" ;

use vars qw(@EXPORT) ;

@EXPORT = qw (
	      append_tag_value
	      get_tag_value_array
	      get_values_non_regular_keys
	      get_values_non_regular_keys
	      get_additional_tag_values
	      ) ;

# add a value to a field, creating an array if required
sub append_tag_value {
    my $self = shift ;
    my $values = shift ;
    my $field = shift ;
    my $value = shift ;
    if (not defined $values->{$field}) {
	$values->{$field} = $value ;
    } elsif (ref($values->{$field}) ne 'ARRAY') {
	@{$values->{$field}} = ($values->{$field}, $value) ;
    } else {
	push @{$values->{$field}}, $value ;
    }
}

# append a set of unique values into and old hashes, depending of clear/append options
sub append_tag_values {
    my $self = shift ;
    my $old_values = shift ;
    my $new_values = shift ;

    if ($self->{clear_opt}) {
	$old_values = () ;
    }

    foreach my $field (keys %{$new_values}) {
	$old_values->{$field} = undef
	    if defined $old_values->{$field} and !$self->{append_opt} ;
	append_tag_value $self, $old_values, $field, $new_values->{$field} ;
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
    } elsif (ref ($values->{$field}) eq 'ARRAY') {
	return @{$values->{$field}} ;
    } else {
	return ($values->{$field}) ;
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
sub get_additional_tag_values {
    my $self = shift ;
    foreach my $string (@{$self->{additional_tags}}) {
	if ($string =~ /^([^=]+)=(.*)$/) {
	    append_tag_value $self, $self->{additional_values}, $1, $2 ;
	} else {
	    die "Additional tags must be given as 'TAG=value'.\n" ;
	}
    }
}

1 ;
