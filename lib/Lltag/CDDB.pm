package Lltag::CDDB ;

use strict ;

use IO::Socket ;

use Lltag::Misc ;

use vars qw(@EXPORT) ;

@EXPORT = qw (
	      get_cddb_tags
	      CDDB_SUCCESS
	      CDDB_ABORT
	      ) ;

# return values that are passed to lltag
use constant CDDB_SUCCESS => 0 ;
use constant CDDB_ABORT => -1 ;

# local return values
use constant CDDB_ABORT_TO_KEYWORDS => -10 ;
use constant CDDB_ABORT_TO_CDIDS => -11 ;

my $server_host = "www.freedb.org" ;
my $server_port = 80 ;

my $previous_cdids = undef ;
my $previous_cd = undef ;

#########################################3
# low level CDDB http requests

sub cddb_query_cd_by_keywords {
    my $keywords = shift ;

    print "      Sending CDDB request...\n" ;

    my $socket = IO::Socket::INET->new(PeerAddr => $server_host,
				       PeerPort => $server_port,
				       Proto    => "tcp",
				       Type     => SOCK_STREAM)
	or die "cannot connect to cddb db: $server_host:$server_port ($!)\n" ;

    print $socket "GET http://${server_host}/freedb_search.php?words=${keywords}&allfields=NO&fields=artist&fields=title&allcats=YES&grouping=none&x=0&y=0\n" ;

    my @cdids = () ;
    my $samename = undef ;
    my $same = 0 ;

    while (my $line = <$socket>) {
	next if $line !~ /<a href=\"/ ;
	if ($line =~ /<tr>/) {
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

    close $socket ;

    return \@cdids ;
}

sub cddb_query_tracks_by_id {
    my $cat = shift ;
    my $id = shift ;
    my $name = shift ;

    print "      Sending CDDB request...\n" ;

    my $socket = IO::Socket::INET->new(PeerAddr => $server_host,
				       PeerPort => $server_port,
				       Proto    => "tcp",
				       Type     => SOCK_STREAM)
	or die "cannot connect to cddb db: $server_host:$server_port ($!)\n" ;

    print $socket "GET http://www.freedb.org/freedb_search_fmt.php?cat=${cat}&id=${id}\n" ;

    my $cd ;

    while (my $line = <$socket>) {
	if ($line =~ /tracks: (\d+)/i) {
	    $cd->{TRACKS} = $1 ;
	} elsif ($line =~ /total time: ([\d:]+)/i) {
	    $cd->{"TOTAL TIME"} = $1 ;
	} elsif ($line =~ /genre: (\w+)/i) {
	    $cd->{GENRE} = $1 ;
	} elsif ($line =~ /id3g: (\d+)/i) {
	    $cd->{ID3G} = $1 ;
	} elsif ($line =~ /year: (\d+)/i) {
	    $cd->{YEAR} = $1 ;
	} elsif ($line =~ m@ *(\d+)\.</td><td valign=top> *(-?[\d:]+)</td><td><b>(.*)</b>@) {
	    # '-?' because there are some buggy entries...
	    my %track = ( TITLE => $3, TIME => $2 ) ;
	    $cd->{$1} = \%track ;
	} elsif ($line =~ m@<h2>(.+ / .+)</h2>@) {
	    if (defined $name) {
		if ($name ne $1) {
		    print "      WARNING: Found CD name '$1' instead of '$name', this entry might be corrupted.\n" ;
		}
	    } else {
		$name = $1 ;
	    }
	}
    }

    close $socket ;

    return undef unless defined $name ;

    # TODO: are we sure no artist or album may contain " / " ?
    $name =~ m@^(.+) / (.+)$@ ;
    $cd->{ARTIST} = $1 ;
    $cd->{ALBUM} = $2 ;

    # TODO: check number and indexes of tracks ?

    return $cd ;
}

######################################################
# interactive menu to browse CDDB, tracks in a CD

sub cddb_track_usage {
  print "    <index> => Choose a track of the current CD\n" ;
  print "    v => View the list of CD matching the keywords\n" ;
  print "    c => Change the CD chosen in keywords query results list\n" ;
  print "    k => Start again CDDB query with different keywords\n" ;
  print "    q => Quit CDDB query\n" ;
  print "    h => Show this help\n" ;
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
    my $cd = shift ;

    print_cd $cd ;

    while (1) {
	Lltag::Misc::print_question "  Enter track index (<index>,vckqh) ? " ;
	my $reply = <> ;
	chomp $reply ;
	next if $reply eq '' ;

	return (CDDB_ABORT, undef) if $reply eq 'q' ;
	return (CDDB_ABORT_TO_KEYWORDS, undef) if $reply eq 'k' ;
	return (CDDB_ABORT_TO_CDIDS, undef) if $reply eq 'c' ;

	if ($reply eq 'v') {
	    print_cd $cd ;
	    next ;
	} ;

	if ($reply =~ /^\d+$/ and $reply >= 1 and $reply <= $cd->{TRACKS}) {
	    # get the track tags
	    my $track = $cd->{$reply} ;
	    my %values ;
	    $values{ARTIST} = $cd->{ARTIST} ;
	    $values{TITLE} = $track->{TITLE} ;
	    $values{ALBUM} = $cd->{ALBUM} ;
	    $values{NUMBER} = $reply ;
	    $values{GENRE} = $cd->{GENRE} if defined $cd->{GENRE} ;
	    $values{DATE} = $cd->{YEAR} if defined $cd->{YEAR} ;
	    return (CDDB_SUCCESS, \%values) ;
	}

	cddb_track_usage () ;
    }
}

##########################################################
# interactive menu to browse CDDB, CDs in a query results

sub cddb_cd_usage {
  print "    <index> => Choose a CD in the current keywords query results list\n" ;
  print "    v => View the list of CD matching the keywords\n" ;
  print "    k => Start again CDDB query with different keywords\n" ;
  print "    q => Quit CDDB query\n" ;
  print "    h => Show this help\n" ;
}

sub print_cdids {
    my $cdids = shift ;

    my $cdid_format = "    %0".(length (scalar @{$cdids}))."d: %s (cat=%s, id=%s)\n" ;
    for(my $i=0; $i < @{$cdids}; $i++) {
	my $cdid = $cdids->[$i] ;
	printf ($cdid_format, $i+1, $cdid->{NAME}, $cdid->{CAT}, $cdid->{ID}) ;
    }
}

sub get_cddb_tags_from_cdid {
    my $cdid = shift ;
    my $cd = cddb_query_tracks_by_id ($cdid->{CAT}, $cdid->{ID}, $cdid->{NAME}) ;

    if (!$cd or !$cd->{TRACKS}) {
	print "    There is no tracks in this CD.\n" ;
	goto AGAIN ;
    }

    $previous_cd = $cd ;

    return get_cddb_tags_from_tracks $cd ;
}

sub get_cddb_tags_from_cdids {
    my $cdids = shift ;

  AGAIN:
    print_cdids $cdids ;
    while (1) {
	Lltag::Misc::print_question "  Enter CD index (<index>,vkqh) ? " ;
	my $reply = <> ;
	chomp $reply ;
	next if $reply eq '' ;

	return (CDDB_ABORT, undef) if $reply eq 'q' ;
	return (CDDB_ABORT_TO_KEYWORDS, undef) if $reply eq 'k' ;
	goto AGAIN if $reply eq 'v' ;

	if ($reply =~ /^\d+$/ and $reply >= 1 and $reply <= @{$cdids}) {
	    # do the actual query for CD contents
	    my ($res, $values) = get_cddb_tags_from_cdid $cdids->[$reply-1] ;
	    goto AGAIN if $res == CDDB_ABORT_TO_CDIDS ;
	    return ($res, $values) ;
	}

	cddb_cd_usage () ;
    }
}

##########################################################
# interactive menu to browse CDDB, keywords query

sub cddb_keywords_usage {
  print "    <category>/<hexadecinal id> => CDDB query for CD matching category and id\n" ;
  print "    <space-seperated keywords> => CDDB query for CD matching the keywords\n" ;
  print "    q => Quit CDDB query\n" ;
  print "    h => Show this help\n" ;
}

sub get_cddb_tags {

    # FIXME: check an additional parameter to start from scratch

    if (defined $previous_cd) {
	bless $previous_cd ;
	my ($res, $values) = get_cddb_tags_from_tracks $previous_cd ;
	return ($res, $values) if $res == CDDB_SUCCESS or $res == CDDB_ABORT ;
	if ($res == CDDB_ABORT_TO_CDIDS) {
	    bless $previous_cdids ;
	    my ($res, $values) = get_cddb_tags_from_cdids $previous_cdids ;
	    return ($res, $values) if $res == CDDB_SUCCESS or $res == CDDB_ABORT ;
	}
    }

    while (1) {
	my $keywords = Lltag::Misc::readline ("  ", "Enter CDDB query (<query>,qh)", "", -1) ;
	chomp $keywords ;
	next if $keywords eq '' ;

	return (CDDB_ABORT, undef) if $keywords eq 'q' ;

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
	    my ($res, $values) = get_cddb_tags_from_cdid $cdid ;
	    return ($res, $values) if $res == CDDB_SUCCESS or $res == CDDB_ABORT ;
	    next ;
	}

	# do the actual query for CD id with keywords
	$keywords =~ s/ /+/g ;
	my $cdids = cddb_query_cd_by_keywords $keywords ;
	$previous_cdids = $cdids ;
	$previous_cd = undef ;

	my ($res, $values) = get_cddb_tags_from_cdids $cdids ;
	next if $res == CDDB_ABORT_TO_KEYWORDS ;
	return ($res, $values) ;
    }
}

1 ;
