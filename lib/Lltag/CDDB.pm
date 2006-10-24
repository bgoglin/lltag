package Lltag::CDDB ;

use strict ;

use LWP ;

use Lltag::Misc ;

# return values that are passed to lltag
use constant CDDB_SUCCESS => 0 ;
use constant CDDB_ABORT => -1 ;

# local return values
use constant CDDB_ABORT_TO_KEYWORDS => -10 ;
use constant CDDB_ABORT_TO_CDIDS => -11 ;

# keep track of where we were during the previous CDDB access
my $previous_cdids = undef ;
my $previous_cd = undef ;
my $previous_track = undef ;

# confirmation behavior
# FIXME: find a way to enable it
my $current_cddb_yes_opt = undef ;

# HTTP browser
my $browser ;

#########################################
# init

sub init_cddb {
    my $self = shift ;

    # default confirmation behavior
    $current_cddb_yes_opt = $self->{yes_opt} ;

    # HTTP browser
    $browser = LWP::UserAgent->new;
    # use HTTP_PROXY environment variable
    $browser->env_proxy ;
}

#########################################
# low level CDDB http requests

sub cddb_response {
    my $self = shift ;
    my $path = shift ;

    print "      Sending CDDB request...\n" ;

    my $response = $browser->get(
	"http://"
        . $self->{cddb_server_name}
        . ($self->{cddb_server_port} != 80 ? $self->{cddb_server_port} : "")
        . $path
        . "\n"
	) ;

    if (!$response->is_success) {
	Lltag::Misc::print_error ("  ",
		"HTTP request to CDDB server ("
		. $self->{cddb_server_name} .":". $self->{cddb_server_port}
		. ") failed.") ;
	return undef ;
    }
    if ($response->content_type ne 'text/html') {
	Lltag::Misc::print_error ("  ",
		"Weird CDDB response (type ".$response->content_type.") from server "
		. $self->{cddb_server_name} .":". $self->{cddb_server_port}
		. ".") ;
	return undef ;
    }

    return $response->content ;
}

sub cddb_query_cd_by_keywords {
    my $self = shift ;
    my $keywords = shift ;
    my @fields = split /\+/, shift ;
    my @cats = split /\+/, shift ;

    my $query_fields = (grep { $_ eq "all" } @fields) ? "allfields=YES" : "allfields=NO".(join ("", map { "&fields=$_" } @fields)) ;
    my $query_cats = (grep { $_ eq "all" } @cats) ? "allcats=YES" : "allcats=NO".(join ("", map { "&cats=$_" } @cats)) ;

    my $response = cddb_response $self, "/freedb_search.php?words=${keywords}&${query_fields}&${query_cats}&grouping=none&x=0&y=0" ;
    return (CDDB_ABORT, undef) unless defined $response ;

    my @cdids = () ;
    my $samename = undef ;
    my $same = 0 ;

    foreach my $line (split /\n/, $response) {
	next if $line !~ /<a href=\"/ ;
	if ($line =~ m/<tr>/) {
	    $same = 0 ;
	    $samename = undef ;
	} else {
	    $same = 1;
	}
	my @links = split (/<a href=\"/, $line) ;
	shift @links ;
	while (my $link = shift @links) {
	    if ($link =~ m@http://www\.freedb\.org/freedb_search_fmt\.php\?cat=([a-z]+)\&id=([0-9a-f]+)\">(.*)</a>@) {
		my %cdid = ( CAT => $1, ID => $2, NAME => $same ? $samename : $3 ) ;
		push @cdids, \%cdid ;
		$samename = $cdid{NAME} unless $same ;
		$same = 1;
	    }
	}
    }

    return (CDDB_SUCCESS, \@cdids) ;
}

sub cddb_query_tracks_by_id {
    my $self = shift ;
    my $cat = shift ;
    my $id = shift ;
    my $name = shift ;

    my $response = cddb_response $self, "/freedb_search_fmt.php?cat=${cat}&id=${id}\n" ;
    return (CDDB_ABORT, undef) unless defined $response ;

    my $cd ;
    $cd->{CAT} = $cat ;
    $cd->{ID} = $id ;

    foreach my $line (split /\n/, $response) {
	if ($line =~ m/tracks: (\d+)/i) {
	    $cd->{TRACKS} = $1 ;
	} elsif ($line =~ m/total time: ([\d:]+)/i) {
	    $cd->{"TOTAL TIME"} = $1 ;
	} elsif ($line =~ m/genre: (\w+)/i) {
	    $cd->{GENRE} = $1 ;
	} elsif ($line =~ m/id3g: (\d+)/i) {
	    $cd->{ID3G} = $1 ;
	} elsif ($line =~ m/year: (\d+)/i) {
	    $cd->{DATE} = $1 ;
	} elsif ($line =~ m@ *(\d+)\.</td><td valign=top> *(-?[\d:]+)</td><td><b>(.*)</b>@) {
	    # '-?' because there are some buggy entries...
	    my %track = ( TITLE => $3, TIME => $2 ) ;
	    $cd->{$1} = \%track ;
	} elsif ($line =~ m@<h2>(.+ / .+)</h2>@) {
	    if (defined $name) {
		if ($name ne $1) {
		    Lltag::Misc::print_warning ("      ", "Found CD name '$1' instead of '$name', this entry might be corrupted") ;
		}
	    } else {
		$name = $1 ;
	    }
	}
    }

    return (CDDB_SUCCESS, undef)
	unless defined $name ;

    # FIXME: are we sure no artist or album may contain " / " ?
    $name =~ m@^(.+) / (.+)$@ ;
    $cd->{ARTIST} = $1 ;
    $cd->{ALBUM} = $2 ;

    # FIXME: check number and indexes of tracks ?

    return (CDDB_SUCCESS, $cd) ;
}

######################################################
# interactive menu to browse CDDB, tracks in a CD

my $cddb_track_usage_forced = 1 ;

sub cddb_track_usage {
    Lltag::Misc::print_usage_header ("    ", "Choose Track in CDDB CD") ;
    print "      <index> => Choose a track of the current CD (current default is Track $previous_track)\n" ;
    print "      <index> a => Choose a track and do not ask for confirmation anymore\n" ;
    print "      a => Use default track and do not ask for confirmation anymore\n" ;
    print "      E => Edit current CD common tags\n" ;
    print "      v => View the list of CD matching the keywords\n" ;
    print "      c => Change the CD chosen in keywords query results list\n" ;
    print "      k => Start again CDDB query with different keywords\n" ;
    print "      q => Quit CDDB query\n" ;
    print "      h => Show this help\n" ;

    $cddb_track_usage_forced = 0 ;
}

sub print_cd {
    my $cd = shift ;
    map {
	print "    $_: $cd->{$_}\n" ;
    } grep { $_ !~ /^\d+$/ } (keys %{$cd}) ;
    my $track_format = "    Track %0".(length $cd->{TRACKS})."d: %s (%s)\n" ;
    for(my $i=0; $i < $cd->{TRACKS}; $i++) {
	my $track = $cd->{$i+1} ;
	printf ($track_format, $i+1, $track->{TITLE}, $track->{TIME}) ;
    }
}

sub get_cddb_tags_from_tracks {
    my $self = shift ;
    my $cd = shift ;
    my $tracknumber = undef ;

    # update previous_track to 1 or ++
    $previous_track = 0
	unless defined $previous_track ;
    $previous_track++ ;

    # if automatic mode and still in the CD, let's go
    if ($current_cddb_yes_opt and $previous_track <= $cd->{TRACKS}) {
	$tracknumber = $previous_track ;
	Lltag::Misc::print_notice ("    ", "Automatically choosing next CDDB track, #$tracknumber...") ;
	goto FOUND ;
    }

    # either in non-automatic or reached the end of the CD, dump the contents
    print_cd $cd ;

    # reached the end of CD, reset to the beginning
    if ($previous_track == $cd->{TRACKS} + 1) {
	$previous_track = 1;
	if ($current_cddb_yes_opt) {
	    Lltag::Misc::print_notice ("  ", "Reached the end of the CD, returning to interactive mode") ;
	    # return to previous confirmation behavior
	    $current_cddb_yes_opt = $self->{yes_opt} ;
	}
    }

    cddb_track_usage
	if $cddb_track_usage_forced ;

    while (1) {
	Lltag::Misc::print_question "  Enter track index [<index>aEvckq]".
	    " (default is Track $previous_track, h for help) ? " ;
	my $reply = <> ;
	chomp $reply ;

	$reply = $previous_track
	    if $reply eq '' ;

	return (CDDB_ABORT, undef)
	    if $reply =~ m/^q/ ;

	return (CDDB_ABORT_TO_KEYWORDS, undef)
	    if $reply =~ m/^k/ ;

	return (CDDB_ABORT_TO_CDIDS, undef)
	    if $reply =~ m/^c/ ;

	if ($reply =~ m/^E/) {
	    my @field_names = grep { $_ ne 'TITLE' and $_ ne 'NUMBER' } @{$self->{field_names}} ;
	    $cd = Lltag::Tags::edit_values ($self, $cd, \@field_names) ;
	    next ;
	}

	if ($reply =~ m/^v/) {
	    print_cd $cd ;
	    next ;
	} ;

	if ($reply =~ m/^a/) {
	    $reply = $previous_track ;
	    $current_cddb_yes_opt = 1 ;
	}
	if ($reply =~ m/^(\d+) *a/) {
	    $current_cddb_yes_opt = 1 ;
	    $reply = $1 ;
	}

	if ($reply =~ m/^\d+$/ and $reply >= 1 and $reply <= $cd->{TRACKS}) {
	    $tracknumber = $reply ;
	    last ;
	}

	cddb_track_usage () ;
    }

   FOUND:
    my $track = $cd->{$tracknumber} ;
    # get the track tags
    my %values ;
    $values{ARTIST} = $cd->{ARTIST} ;
    $values{TITLE} = $track->{TITLE} ;
    $values{ALBUM} = $cd->{ALBUM} ;
    $values{NUMBER} = $tracknumber ;
    $values{GENRE} = $cd->{GENRE} if defined $cd->{GENRE} ;
    $values{DATE} = $cd->{DATE} if defined $cd->{DATE} ;

    # save the previous track number
    $previous_track = $tracknumber ;

    return (CDDB_SUCCESS, \%values) ;
}

##########################################################
# interactive menu to browse CDDB, CDs in a query results

my $cddb_cd_usage_forced = 1 ;

sub cddb_cd_usage {
    Lltag::Misc::print_usage_header ("    ", "Choose CD in CDDB Query Results") ;
    print "      <index> => Choose a CD in the current keywords query results list\n" ;
    print "      v => View the list of CD matching the keywords\n" ;
    print "      k => Start again CDDB query with different keywords\n" ;
    print "      q => Quit CDDB query\n" ;
    print "      h => Show this help\n" ;

    $cddb_cd_usage_forced = 0 ;
}

sub print_cdids {
    my $cdids = shift ;

    my $cdid_format = "    %0".(length (scalar @{$cdids}))."d: %s (cat=%s, id=%s)\n" ;
    for(my $i=0; $i < @{$cdids}; $i++) {
	my $cdid = $cdids->[$i] ;
	printf ($cdid_format, $i+1, $cdid->{NAME}, $cdid->{CAT}, $cdid->{ID}) ;
    }
}

# returns (SUCCESS, undef) if CDDB returned an bad/empty CD
sub get_cddb_tags_from_cdid {
    my $self = shift ;
    my $cdid = shift ;
    my ($res, $cd) = cddb_query_tracks_by_id ($self, $cdid->{CAT}, $cdid->{ID}, $cdid->{NAME}) ;
    return (CDDB_ABORT, undef) if $res == CDDB_ABORT ;

    if (!$cd or !$cd->{TRACKS}) {
	print "    There is no tracks in this CD.\n" ;
	return (CDDB_SUCCESS, undef) ;
    }

    $previous_cd = $cd ;
    undef $previous_track ;

    return get_cddb_tags_from_tracks $self, $cd ;
}

sub get_cddb_tags_from_cdids {
    my $self = shift ;
    my $cdids = shift ;

  AGAIN:
    print_cdids $cdids ;

    cddb_cd_usage
	if $cddb_cd_usage_forced ;

    while (1) {
	Lltag::Misc::print_question "  Enter CD index [<index>vkq] (no default, h for help) ? " ;
	my $reply = <> ;
	chomp $reply ;

	next if $reply eq '' ;

	return (CDDB_ABORT, undef)
	    if $reply =~ m/^q/ ;

	return (CDDB_ABORT_TO_KEYWORDS, undef)
	    if $reply =~ m/^k/ ;

	goto AGAIN
	    if $reply =~ m/^v/ ;

	if ($reply =~ m/^\d+$/ and $reply >= 1 and $reply <= @{$cdids}) {
	    # do the actual query for CD contents
	    my ($res, $values) = get_cddb_tags_from_cdid $self, $cdids->[$reply-1] ;
	    goto AGAIN if $res == CDDB_ABORT_TO_CDIDS or ($res == CDDB_SUCCESS and not defined $values) ;
	    return ($res, $values) ;
	}

	cddb_cd_usage () ;
    }
}

##########################################################
# interactive menu to browse CDDB, keywords query

my $cddb_keywords_usage_forced = 1 ;

sub cddb_keywords_usage {
    Lltag::Misc::print_usage_header ("    ", "CDDB Query by Keywords") ;
    print "      <space-separated keywords> => CDDB query for CD matching the keywords\n" ;
    print "        Search in all CD categories within fields 'artist' and 'title' by default\n" ;
    print "          cats=foo+bar   => Search in CD categories 'foo' and 'bar' only\n" ;
    print "          fields=all     => Search keywords in all fields\n" ;
    print "          fields=foo+bar => Search keywords in fields 'foo' and 'bar'\n" ;
    print "      <category>/<hexadecinal id> => CDDB query for CD matching category and id\n" ;
    print "      q => Quit CDDB query\n" ;
    print "      h => Show this help\n" ;

    $cddb_keywords_usage_forced = 0 ;
}

sub get_cddb_tags {
    my $self = shift ;
    my ($res, $values) ;

    if (defined $previous_cd) {
	bless $previous_cd ;
	print "  Going back to previous CD cat=$previous_cd->{CAT} id=$previous_cd->{ID}\n" ;
	($res, $values) = get_cddb_tags_from_tracks $self, $previous_cd ;
	if ($res == CDDB_ABORT_TO_CDIDS) {
	    bless $previous_cdids ;
	    ($res, $values) = get_cddb_tags_from_cdids $self, $previous_cdids ;
	}
	goto OUT if $res == CDDB_SUCCESS ;
	goto ABORT if $res == CDDB_ABORT ;
    }

    cddb_keywords_usage
	if $cddb_keywords_usage_forced ;

    while (1) {
	my $keywords ;
	if (defined $self->{requested_cddb_query}) {
	    $keywords = $self->{requested_cddb_query} ;
	    print "  Using command-line given keywords '$self->{requested_cddb_query}'...\n" ;
	    undef $self->{requested_cddb_query} ;
	    # FIXME: either put it in the history, or preput it next time
        } else {
	    $keywords = Lltag::Misc::readline ("  ", "Enter CDDB query [<query>q] (no default, h for help)", "", -1) ;
	    chomp $keywords ;
	}

	next if $keywords eq '' ;

	# be careful to match the whole reply, not only the first char
	# since multiple chars are valid keyword queries

	goto ABORT
	    if $keywords eq 'q' ;

	if ($keywords eq 'h') {
	    cddb_keywords_usage () ;
	    next ;
	}

	# it this a category/id ?
	if ($keywords =~ m@^\s*(\w+)/([\da-f]+)\s*$@) {
	    my $cdid ;
	    $cdid->{CAT} = $1 ;
	    $cdid->{ID} = $2 ;
	    # FIXME: do not show 'c' for goto to CD list in there
	    ($res, $values) = get_cddb_tags_from_cdid $self, $cdid ;
	    goto OUT if $res == CDDB_SUCCESS and defined $values ;
	    goto ABORT if $res == CDDB_ABORT ;
	    next ;
	}

	# do the actual query for CD id with keywords
	my $cats = "all" ;
	my $fields = "artist+title" ;

	# extract fields and cat from the keywords
	my @keywords_list = map {
	    my $val = $_ ;
	    if ($val =~ m/^fields=(.+)$/) {
		$fields = $1 ; () ;
	    } elsif ($val =~ m/^cats=(.+)$/) {
		$cats = $1 ; () ;
	    } else {
		$_ ;
	    }
	} (split / +/, $keywords) ;
	# assemble remaining keywords with "+"
	$keywords = join "+", @keywords_list ;

	my $cdids ;
	($res, $cdids) = cddb_query_cd_by_keywords $self, $keywords, $fields, $cats ;
	goto ABORT if $res == CDDB_ABORT ;

	if (!@{$cdids}) {
	    print "    No CD found.\n" ;
	    next ;
	}

	$previous_cdids = $cdids ;
	$previous_cd = undef ;

	($res, $values) = get_cddb_tags_from_cdids $self, $cdids ;
	next if $res == CDDB_ABORT_TO_KEYWORDS ;
	goto OUT ;
    }

 OUT:
    goto ABORT if $res == CDDB_ABORT ;
    return ($res, $values) ;

 ABORT:
    $previous_cdids = undef ;
    $previous_cd = undef ;
    $previous_track = undef ;
    return (CDDB_ABORT, undef);
}

1 ;
