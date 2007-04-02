package Lltag::Parse ;

use strict ;
no strict "refs" ; # for ${$i}

# ignoring fields during parsing
use constant IGNORE_LETTER => 'i' ;
use constant IGNORE_NAME => 'IGNORE' ;

# subregexp
my $match_path = '(?:[^/]*\/)*' ;
my $match_any = '((?:[^ /]+ +)*[^ /]+)' ;
my $match_num = '([0-9]+)' ;
my $match_space = ' ';
my $match_spaces = ' *' ;
my $match_limit = '' ;

# the parser that the user wants to always use
my $preferred_parser = undef ;

# confirmation behavior
my $current_parse_ask_opt ;
my $current_parse_yes_opt ;

#######################################################
# Parsing return values
use constant PARSE_SUCCESS_PREFERRED => 1 ;
use constant PARSE_SUCCESS => 0 ;
use constant PARSE_ABORT => -1 ;
use constant PARSE_SKIP_PARSER => -2 ;
use constant PARSE_SKIP_PATH_PARSER => -3 ;
use constant PARSE_NO_MATCH => -4 ;

# Parsing acceptable behavior
use constant PARSE_MAY_SKIP_PARSER => 1 ;
use constant PARSE_MAY_SKIP_PATH_PARSER => 2 ;
use constant PARSE_MAY_PREFER => 4 ;

#######################################################
# initialization

my $confirm_parser_usage_forced ;

sub init_parsing {
    my $self = shift ;

    # default confirmation behavior
    $current_parse_ask_opt = $self->{ask_opt} ;
    $current_parse_yes_opt = $self->{yes_opt} ;

    # spaces_opt changes matching regexps
    $match_limit = $match_space = $match_spaces if $self->{spaces_opt} ;

    # need to show menu usage once ?
    $confirm_parser_usage_forced = $self->{menu_usage_once_opt} ;
}

#######################################################
# parsing format specific usage

sub parsing_format_usage {
    my $self = shift ;
    print "  %".IGNORE_LETTER." means that the text has to be ignored\n" ;
    print "  %% means %\n" ;
}

#######################################################
# parsing confirmation

sub confirm_parser_letters {
    my $behaviors = shift ;
    my $string = "[y" ;
    $string .= "u" if $behaviors & PARSE_MAY_PREFER ;
    $string .= "a" ;
    $string .= "n" if $behaviors & PARSE_MAY_SKIP_PARSER ;
    $string .= "p" if $behaviors & PARSE_MAY_SKIP_PATH_PARSER ;
    $string .= "q]" ;
    return $string ;
}

sub confirm_parser_usage {
    my $behaviors = shift ;
    Lltag::Misc::print_usage_header ("  ", "Parsing filenames") ;
    print "    y => Yes, use this matching (default)\n" ;
    print "    u => Use this format for all files until one does not match\n"
	if $behaviors & PARSE_MAY_PREFER ;
    print "    a => Always yes, stop asking for a confirmation\n" ;
    print "    n => No, try the next matching format\n"
	if $behaviors & PARSE_MAY_SKIP_PARSER ;
    print "    p => No, try the next path matching format\n"
	if $behaviors & PARSE_MAY_SKIP_PATH_PARSER ;
    print "    q => Quit parsing, stop trying to parse this filename\n" ;
    print "    h => Show this help\n" ;

    $confirm_parser_usage_forced = 0 ;
}

sub confirm_parser {
    my $self = shift ;
    my $file = shift ;
    my $confirm = shift ;
    my $behaviors = shift ;
    my $values = shift ;

    # prefer this type of tagging ?
    my $preferred = 0 ;

    # confirm if required
    if ($current_parse_ask_opt or ($confirm and !$current_parse_yes_opt)) {

	confirm_parser_usage $behaviors
	    if $confirm_parser_usage_forced ;

	while (1) {
	    my $reply = Lltag::Misc::readline ("  ", "Use this matching ".(confirm_parser_letters ($behaviors))." (default is yes, h for help)", "", -1) ;

	    # if ctrl-d, stop trying to parse
	    $reply = 'q' unless defined $reply ;

	    if ($reply eq "" or $reply =~ m/^y/) {
		last ;

	    } elsif ($reply =~ m/^a/) {
		$current_parse_ask_opt = 0 ; $current_parse_yes_opt = 1 ;
		last ;

	    } elsif ($behaviors & PARSE_MAY_PREFER and $reply =~ m/^u/) {
		$preferred = 1 ;
		$current_parse_ask_opt = 0 ; $current_parse_yes_opt = 1 ;
		last ;

	    } elsif ($behaviors & PARSE_MAY_SKIP_PARSER and $reply =~ m/^n/) {
		return (PARSE_SKIP_PARSER, undef) ;

	    } elsif ($behaviors & PARSE_MAY_SKIP_PATH_PARSER and $reply =~ m/^p/) {
		return (PARSE_SKIP_PATH_PARSER, undef) ;

	    } elsif ($reply =~ m/^q/) {
		return (PARSE_ABORT, undef) ;

	    } else {
		confirm_parser_usage $behaviors ;
	    }
	}
    }

    if ($preferred) {
	return (PARSE_SUCCESS_PREFERRED, $values) ;
    } else {
	return (PARSE_SUCCESS, $values) ;
    }
}

#######################################################
# actual parsing

sub apply_parser {
    my $self = shift ;
    my $file = shift ;
    my $parsename = shift ;
    my $parser = shift ;
    my $confirm = shift ;
    my $behaviors = shift ;

    my @matches ;

    # protect against bad regexp, just in case (we should have found problems during initialization)
    eval {
	@matches = ($parsename =~ m/^$parser->{regexp}$/) ;
	1 ; # be sure to return success when the regexp does not match
    } or
	Lltag::Misc::die_error ("Failed to apply parser '$parser->{title}', regexp '$parser->{regexp}' is invalid?") ;

    # we ensure earlier that there is at least one field to match, so an error will return ()
    return (PARSE_SKIP_PARSER, undef) unless @matches ;

    print "    '$parser->{title}' matches this file...\n" ;

    my @field_table = @{$parser->{field_table}} ;

    # check the number of matches
    Lltag::Misc::die_error ("Matched ".(scalar @matches)." fields instead of ".(scalar @field_table).", parser invalid?")
	unless @matches == @field_table ;

    my $values = {} ;

    # traverse matches
    for(my $i=0; $i<@field_table; $i++) {

	my $field = $field_table[$i] ;
	if ($field ne IGNORE_NAME) {
	    my $val = $matches[$i] ;

	    # apply maj, sep and regexp to the value
	    $val =~ s/\b(.)/uc $1/eg if $self->{maj_opt} ;
	    $val =~ s/($self->{sep_opt})/ /g if defined $self->{sep_opt} ;
	    map { $val = Lltag::Tags::apply_regexp_to_tag ($val, $_, $field) } @{$self->{regexp_opts}} ;

	    # check whether it's already defined.
	    # TODO: append ?
	    if (defined $values->{$field}) {
		Lltag::Misc::print_warning ("      ", ucfirst($field)." already set to '".$values->{$field}
					    ."', skipping new value '$val'")
		    if $values->{$field} ne $val ;
	        next ;
	    }

	    # ok
	    $values->{$field} = $val ;
	    if ($self->{verbose_opt} or $confirm or $current_parse_ask_opt) {
		print "      ". ucfirst($field)
		    .$self->{field_name_trailing_spaces}{$field}  .": ". $val ."\n" ;
	    }
	}
    }

    return confirm_parser ($self, $file, $confirm, $behaviors, $values) ;
}

#######################################################
# internal parsers

my @internal_basename_parsers = () ;
my @internal_path_parsers = () ;

sub add_internal_parser {
    my $self = shift ;
    my $file = shift ;
    my $startline  = shift ;
    my $type = shift ;
    my $title = shift ;
    my $regexp = shift ;
    my $regexp_size = shift ;
    my $field_table = shift ;

    if ($type and $title and $regexp and @{$field_table}) {
	my $parser ;
	$parser->{title} = $title ;
	$parser->{regexp} = $regexp ;
	@{$parser->{field_table}} = @{$field_table} ;

	# check whether there are the same number of fields in the regexp and in the field_table
	Lltag::Misc::die_error ("  Parser '$title' at line $startline in file '$file' needs same number of matching fields in regexp ($regexp_size) and indices (".(scalar@{$field_table} ).").")
	    unless $regexp_size == scalar @{$field_table} ;

	# check whether the regexp is applicable
	eval {
	    my $dummy = ("dummy" =~ m@^$regexp/[^/]+$@) ;
	    # be sure to return success even if not matched
	    1 ;
	} or
	    # print the parser and its formats file (not the line since we may be way later already
	    Lltag::Misc::die_error ("  Parser '$title' regexp '$regexp' looks invalid at line $startline in file '$file'.") ;

	# add the parser
	if ($type eq "basename" or $type eq "filename") {
	    # TODO: drop filename support on september 20 2006
	    print "  Got basename format '$title' (regexp '$regexp')\n" if $self->{verbose_opt} ;
	    push (@internal_basename_parsers, $parser) ;
	} elsif ($type eq "path") {
	    print "  Got path format '$title' (regexp '$regexp')\n" if $self->{verbose_opt} ;
	    push (@internal_path_parsers, $parser) ;
	}
    } elsif ($type or $title or $regexp or @{$field_table}) {
	Lltag::Misc::die_error ("Incomplete format at line $startline in file '$file'.") ;
    }
}

sub read_internal_parsers {
    my $self = shift ;

    # get parsers from configuration files
    my $file ;
    if (open FORMAT, "$self->{user_lltag_dir}/$self->{lltag_format_filename}") {
	$file = "$self->{user_lltag_dir}/$self->{lltag_format_filename}" ;
    } elsif (open FORMAT, "$self->{common_lltag_dir}/$self->{lltag_format_filename}") {
	$file = "$self->{common_lltag_dir}/$self->{lltag_format_filename}" ;
    } else {
	print "Did not find any format file.\n" ;
	goto NO_FORMATS_FILE_FOUND;
    }
    print "Reading format file '$file'...\n" if $self->{verbose_opt} ;

    my $startline = undef ;
    my $type = undef ;
    my $title = undef ;
    my $regexp = undef ;
    my $regexp_size = undef ;
    my @field_table = () ;

    while (<FORMAT>) {
	chomp $_ ;
	next if /^#/ ;
	next if /^$/ ;

	if (/^\[(.*)\]$/) {
	    add_internal_parser $self, $file, $startline, $type, $title, $regexp, $regexp_size, \@field_table ;
	    $startline = $. ;
	    $type = undef ;
	    $regexp = undef ;
	    $regexp_size = undef ;
	    @field_table = () ;
	    $title = $1 ;
	    # stocker la ligne ?

	} elsif (/^type = (.*)$/) {
	    Lltag::Misc::die_error ("Unsupported format type '$1' at line $. in file '$file'.")
		if $1 ne "basename" and $1 ne "filename" and $1 ne "path" ;
	    # TODO: drop filename support on september 20 2006
	    $type = $1 ;

	} elsif (/^regexp = (.*)$/) {
	    $regexp = $1 ;
	    # escape special characters
	    # FIXME: add *+$^ ?
	    $regexp =~ s/\./\\./g ;
	    $regexp =~ s/\(/\\\(/g ;
	    $regexp =~ s/\)/\\\)/g ;
	    $regexp =~ s/\[/\\\[/g ;
	    $regexp =~ s/\]/\\\]/g ;
	    $regexp =~ s@/@\\/@g ;
	    $regexp_size = 0 ;

	    # do the replacement progressively so that %% and %x and not mixed
	    while ($regexp =~ m/(%(?:P|L|S|N|A|%))/) {
		if ($1 eq '%P') {
		    $regexp =~ s/%P/$match_path/ ;
		} elsif ($1 eq '%L') {
		    $regexp =~ s/%L/$match_limit/ ;
		} elsif ($1 eq '%S') {
		    $regexp =~ s/%S/$match_space/ ;
		} elsif ($1 eq '%N') {
		    $regexp =~ s/%N/$match_num/ ;
		    $regexp_size++;
		} elsif ($1 eq '%A') {
		    $regexp =~ s/%A/$match_any/ ;
		    $regexp_size++;
		} elsif ($1 eq '%%') {
		    $regexp =~ s/%%/%/ ;
		}
	    }

	    Lltag::Misc::die_error ("Parser '$title' at line $startline in file '$file' needs at least one matching %A or %N in its regexp.")
		unless $regexp_size ;

	} elsif (/^indices = (.*)$/) {
	    my @name_table = split (/,/, $1) ;
	    Lltag::Misc::die_error ("Parser '$title' at line $startline in file '$file' needs at least one indice.")
		unless @name_table ;
	    @field_table = map {
		my $field ;
		if (defined $self->{field_name_letter}{$_} or $_ eq IGNORE_NAME) {
		    # full field name, keep as it is
		    $field = $_
		} elsif (defined $self->{field_letter_name}{$_}) {
		    # field letter
		    $field = $self->{field_letter_name}{$_} ;
		} elsif ($_ eq IGNORE_LETTER) {
		    # ignore letter
		    $field = IGNORE_NAME ;
		} else {
		    Lltag::Misc::die_error ("Unrecognized field '$_' on line $. in file '$file'.") ;
		}
		$field } @name_table ;

	} else {
	    Lltag::Misc::die_error ("Unrecognized line $. in file '$file': '$_'.") ;
	}
    }
    close FORMAT ;

    # save the last format
    add_internal_parser $self, $file, $startline, $type, $title, $regexp, $regexp_size, \@field_table ;

  NO_FORMATS_FILE_FOUND:
}

sub list_internal_parsers {
    foreach my $path_parser (@internal_path_parsers) {
	foreach my $basename_parser (@internal_basename_parsers) {
	    print "  $path_parser->{title}/$basename_parser->{title}\n" ;
	}
    }
}

sub merge_internal_parsers {
    my $path_parser = shift ;
    my $basename_parser = shift ;
    my $parser ;
    $parser->{title} = "$path_parser->{title}/$basename_parser->{title}" ;
    $parser->{regexp} = "$path_parser->{regexp}/$basename_parser->{regexp}" ;
    @{$parser->{field_table}} = (@{$path_parser->{field_table}}, @{$basename_parser->{field_table}}) ;
    return $parser ;
}

sub apply_internal_basename_parsers {
    my $self = shift ;
    my $file = shift ;
    my $parsename = shift ;

    # no path, only try each basename parser
    foreach my $basename_parser (@internal_basename_parsers) {
	# try to tag, with confirmation
	my ($res, $values) = apply_parser $self, $file, $parsename, $basename_parser, 1, PARSE_MAY_PREFER|PARSE_MAY_SKIP_PARSER ;
	if ($res == PARSE_SUCCESS || $res == PARSE_SUCCESS_PREFERRED || $res == PARSE_ABORT) {
	    if ($res == PARSE_SUCCESS_PREFERRED) {
		$preferred_parser = $basename_parser ;
	    }
	    return ($res, $values) ;
	}
	# try next parser
	die "Unknown tag return value: $res.\n" # this is a bug
	    if $res != PARSE_SKIP_PARSER ;
    }
    return (PARSE_NO_MATCH, undef) ;
}

sub apply_internal_path_basename_parsers {
    my $self = shift ;
    my $file = shift ;
    my $parsename = shift ;

    # try each path parser and each basename parser
    foreach my $path_parser (@internal_path_parsers) {
	# match the path only first, to reduce number of (path,basename) parsers to try,
	# and to check that there are no '/' afterwards

	# protect against bad regexp, just in case (we should have found problems during initialization)
	my $res ;
	eval {
	    $res = ($parsename =~ m@^$path_parser->{regexp}/[^/]+$@) ;
	    1 ; # be sure to return success when the regexp does not match
	} or
	    Lltag::Misc::die_error ("Failed to apply parser '$path_parser->{title}', regexp '$path_parser->{regexp}' is invalid?") ;

	if ($res) {
	    foreach my $basename_parser (@internal_basename_parsers) {
		my $whole_parser = merge_internal_parsers ($path_parser, $basename_parser) ;
		# try to tag, with confirmation
		my ($res, $values) = apply_parser $self, $file, $parsename, $whole_parser, 1, PARSE_MAY_PREFER|PARSE_MAY_SKIP_PARSER|PARSE_MAY_SKIP_PATH_PARSER ;
		if ($res == PARSE_SUCCESS || $res == PARSE_SUCCESS_PREFERRED || $res == PARSE_ABORT) {
		    if ($res == PARSE_SUCCESS_PREFERRED) {
			$preferred_parser = $whole_parser ;
		    }
		    return ($res, $values) ;
		}
		# try next path parser if asked
		goto NEXT_PATH_PARSER
		    if $res == PARSE_SKIP_PATH_PARSER ;

		# try next parser
		die "Unknown tag return value: $res.\n" # this is a bug
		    if $res != PARSE_SKIP_PARSER ;
	    }
	}
      NEXT_PATH_PARSER:
    }
    return (PARSE_NO_MATCH, undef) ;
}

#######################################################
# user parsers

# list of user-provided parsers
my @user_parsers ;

# change a format strings into usable infos
sub generate_user_parser {
    my $self = shift ;
    my $format_string = shift ;

    print "Generating parser for format '". $format_string ."'...\n" ;

    my $parser ;
    $parser->{title} = $format_string ;

    # merge spaces if --spaces was passed
    if ($self->{spaces_opt}) {
	$format_string =~ s/ +/ /g ;
    }

    # create the regexp and store indice fields
    my @array = split(//, $format_string) ;
    my @field_table = () ;
    for(my $i = 0; $i < @array - 1; $i++) {

	my $char = $array[$i] ;
	# normal characters
	if ($char ne "%") {

	    if ($char eq " ") {
		# replace spaces with general space matching regexp
		$array[$i] = $match_space ;

	    } elsif ($char eq "/") {
		# replace / with space flexible matching regexp
		$array[$i] = $match_limit."/".$match_limit ;

	    } elsif (index ("()[]", $char) != -1) {
		# escape regexp control characters
		$array[$i] = "\\".$char ;

	    }
	    # keep this character
	    next ;
	}

	# remove % and check next char
	splice (@array, $i, 1) ;
	# replace the char with the matching
	$char = $array[$i] ;
	next if $char eq "%" ;
	if ($char eq "n") {
	    $array[$i] = $match_num ;
	} elsif ($char =~ m/$self->{field_letters_union}/) {
	    $array[$i] = $match_any ;
	} elsif ($char eq IGNORE_LETTER) { # looks like constants do not work in regexp
	    $array[$i] = $match_any ;
	} else {
	    Lltag::Misc::die_error ("Format '". $format_string ."' contains unrecognized operator '%". $array[$i] ."'.") ;
	}
	# store the indice
	if ($char eq IGNORE_LETTER) {
	    push @field_table, IGNORE_NAME ;
	} else {
	    push @field_table, $self->{field_letter_name}{$char} ;
	}
    }
    @{$parser->{field_table}} = @field_table ;

    Lltag::Misc::die_error ("Format '$format_string' does not contain any matching field.")
	unless @field_table ;

    # done
    if ($self->{spaces_opt}) {
	$parser->{regexp} = $match_limit. join("", @array) .$match_limit ;
    } else {
	$parser->{regexp} = join("", @array) ;
    }

    # check insolvable regexp
    for(my $i = 0; $i < @array - 1; $i++) {
	my $char = $array[$i] ;
	my $nextchar = $array[$i+1] ;
	if ( $char eq $match_any and
	     ( $nextchar eq $match_any or $nextchar eq $match_num ) ) {
	    Lltag::Misc::print_warning ("  ", "Format '". $format_string
		."' leads to problematic subregexp '". $char.$nextchar
		."' that won't probably match as desired") ;
	}
    }

    if ($self->{verbose_opt}) {
	print "  Format string will parse with: ". $parser->{regexp} ."\n" ;
	print "    Fields are: ". (join ',', @field_table) ."\n" ;
    }

    return $parser ;
}

sub generate_user_parsers {
    my $self = shift ;
    @user_parsers = map ( generate_user_parser ($self, $_), @{$self->{user_format_strings}} ) ;
}

sub apply_user_parsers {
    my $self = shift ;
    my $file = shift ;
    my $parsename = shift ;

    # try each format until one works
    foreach my $parser (@user_parsers) {
	# try to tag, without confirmation
	my ($res, $values) = apply_parser $self, $file, $parsename, $parser, 0, PARSE_MAY_PREFER|PARSE_MAY_SKIP_PARSER ;
	if ($res == PARSE_SUCCESS || $res == PARSE_SUCCESS_PREFERRED || $res == PARSE_ABORT) {
	    if ($res == PARSE_SUCCESS_PREFERRED) {
		$preferred_parser = $parser ;
	    }
	    return ($res, $values) ;
	}
	print "    '". $parser->{title} ."' does not match.\n" ;
	# try next parser
	die "Unknown tag return value: $res.\n" # this is a bug
	    if $res != PARSE_SKIP_PARSER ;
    }
    return (PARSE_NO_MATCH, undef) ;
}

#######################################################
# high-level parsing routines

sub try_to_parse_with_preferred {
    my $self = shift ;
    my $file = shift ;
    my $parsename = shift ;

    my $values = undef ;
    my $res ;

    # try the preferred parser first
    return (PARSE_NO_MATCH, undef)
	unless defined $preferred_parser ;

    print "  Trying to parse filename with the previous matching parser...\n" ;

    # there can't be any confirmation here, SKIP is not possible
    ($res, $values) = apply_parser $self, $file, $parsename, $preferred_parser, 0, 0 ;
    if ($res != PARSE_SKIP_PARSER) {
	# only SUCCESS if possible
	die "Unknown tag return value: $res.\n" # this is a bug
	    if $res != PARSE_SUCCESS ;
	return ($res, $values) ;

    } else {
	Lltag::Misc::print_notice ("    ", "'$preferred_parser->{title}' does not match anymore, returning to original mode") ;
	$current_parse_ask_opt = $self->{ask_opt} ; $current_parse_yes_opt = $self->{yes_opt} ;
	$preferred_parser = undef ;
	return (PARSE_NO_MATCH, undef) ;
    }
}

my $user_parsers_initialized = 0 ;
my $internal_parsers_initialized = 0 ;

sub try_to_parse {
    my $self = shift ;
    my $file = shift ;
    my $parsename = shift ;
    my $try_internals = shift ;

    my $values = undef ;
    my $res ;

    # initialize user parsers once
    if (!$user_parsers_initialized) {
	generate_user_parsers ($self) ;
	$user_parsers_initialized = 1 ;
    }

    # try user provided parsers first
    if (@user_parsers) {
	print "  Trying to parse filename with user-provided formats...\n" ;
	($res, $values) = apply_user_parsers $self, $file, $parsename ;
	return ($res, $values)
	    if $res == PARSE_SUCCESS or $res == PARSE_SUCCESS_PREFERRED or $res == PARSE_ABORT ;
    }

    # try to guess my internal format database then
    if ($try_internals) {
	print "  Trying to parse filename with internal formats...\n" ;

	# initialize internal parsers once
	if (!$internal_parsers_initialized) {
	    read_internal_parsers ($self) ;
	    $internal_parsers_initialized = 1 ;
	}

	if ($self->{no_path_opt} or $parsename !~ m@/@) {
	    ($res, $values) = apply_internal_basename_parsers $self, $file, $parsename ;
	} else {
	    ($res, $values) = apply_internal_path_basename_parsers $self, $file, $parsename ;
	}
	return ($res, $values)
	    if $res == PARSE_SUCCESS or $res == PARSE_SUCCESS_PREFERRED or $res == PARSE_ABORT ;
    }

    if ($try_internals or @user_parsers) {
	print "  Didn't find any parser!\n" ;
    }

    return (PARSE_NO_MATCH, undef) ;
}

1 ;
