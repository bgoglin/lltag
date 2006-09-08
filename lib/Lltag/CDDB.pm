package Lltag::CDDB ;

use strict ;

use IO::Socket ;

use Lltag::Misc ;

use vars qw(@EXPORT) ;

@EXPORT = qw (
	      get_cddb_tags
	      ) ;

my $TAG_SUCCESS = 0 ;
my $TAG_NO_MATCH = -4 ;

my $server_host = "www.freedb.org" ;
my $server_port = 80 ;

sub cddb_query_cd_by_keywords {
    my $keywords = shift ;
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
    my $socket = IO::Socket::INET->new(PeerAddr => $server_host,
				       PeerPort => $server_port,
				       Proto    => "tcp",
				       Type     => SOCK_STREAM)
	or die "cannot connect to cddb db: $server_host:$server_port ($!)\n" ;

    print $socket "GET http://www.freedb.org/freedb_search_fmt.php?cat=${cat}&id=${id}\n" ;

    my $cd ;

    # TODO: are we sure no artist or album may contain " / " ?
    $name =~ m@^(.*) / (.*)$@ ;
    $cd->{ARTIST} = $1 ;
    $cd->{ALBUM} = $2 ;

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
	}
    }
    # TODO: check number and indexes of tracks ?

    close $socket ;

    return $cd ;
}

my $previous_cdids = undef ;
my $previous_cd = undef ;

sub get_cddb_tags {
    my $reply ;
    my $cdids ;
    my $cd ;

    # FIXME: check additional parameter to start from scratch
    if (defined $previous_cd) {
	$cdids = $previous_cdids ;
	$cd = $previous_cd ;
	goto CD_RESULTS ;
    }
    if (defined $previous_cdids) {
	$cdids = $previous_cdids ;
	goto KEYWORDS_RESULTS ;
    }

    # enter keywords for a query
  KEYWORDS:
    my $keywords = Lltag::Misc::readline ("", "Enter CDDB query (e to exit CDDB)", "", 1) ;
    chomp $keywords ;
    goto KEYWORDS unless length $keywords ;
    return ($TAG_NO_MATCH, undef) if $keywords eq 'e' ;

    # do the actual query for CD id with keywords
    $keywords =~ s/ /+/g ;
    $cdids = cddb_query_cd_by_keywords $keywords ;
    $previous_cdids = $cdids ;
    $previous_cd = undef ;
    goto KEYWORDS unless @{$cdids} ;

  KEYWORDS_RESULTS:
    # print the resulting CDs
    my $cdid_format = "  %0".(length (scalar @{$cdids}))."d: %s (cat=%s, id=%s)\n" ;
    for(my $i=0; $i < @{$cdids}; $i++) {
	my $cdid = $cdids->[$i] ;
	printf ($cdid_format, $i+1, $cdid->{NAME}, $cdid->{CAT}, $cdid->{ID}) ;
    }

    # choose a CD id
  CD:
    $reply = Lltag::Misc::readline ("", "Enter CD index (v to view the list, q to query again, e to exit CDDB)", "", 1) ;
    chomp $reply ;
    goto CD unless length $reply ;
    goto KEYWORDS if $reply eq 'q' ;
    goto KEYWORDS_RESULTS if $reply eq 'v' ;
    return ($TAG_NO_MATCH, undef) if $reply eq 'e' ;
    goto CD unless $reply =~ /^\d+$/ ;
    goto CD unless $reply >= 1 and $reply <= @{$cdids} ;

    # do the actual query for CD contents
    my $cdid = $cdids->[$reply-1] ;
    $cd = cddb_query_tracks_by_id ($cdid->{CAT}, $cdid->{ID}, $cdid->{NAME}) ;
    $previous_cd = $cd ;

    if (!$cd->{TRACKS}) {
	print "  There is no tracks in this CD.\n" ;
	goto CD ;
    }

  CD_RESULTS:
    # print the CD contents
    map {
	print "  $_: $cd->{$_}\n" ;
    } grep { $_ !~ /^\d+$/ } (keys %{$cd}) ;
    my $track_format = "  Track %0".(length $cd->{TRACKS})."d: %s (%s)\n" ;
    for(my $i=0; $i < $cd->{TRACKS}; $i++) {
	my $track = $cd->{$i+1} ;
	printf ($track_format, $i+1, $track->{TITLE}, $track->{TIME}) ;
    }

    # choose a track
  TRACK:
    $reply = Lltag::Misc::readline ("", "Enter track index (v to view the list, q to query again, c to change CD index, e to exit CDDB)", "", 1) ;
    chomp $reply ;
    goto TRACK unless length $reply ;
    goto KEYWORDS if $reply eq 'q' ;
    goto KEYWORDS_RESULTS if $reply eq 'c' ;
    goto CD_RESULTS if $reply eq 'v' ;
    return ($TAG_NO_MATCH, undef) if $reply eq 'e' ;
    goto TRACK unless $reply =~ /^\d+$/ ;
    goto TRACK unless $reply >= 1 and $reply <= $cd->{TRACKS} ;

    # print the track tags
    my $track = $cd->{$reply-1} ;
    my %values ;
    $values{ARTIST} = $cd->{ARTIST} ;
    $values{TITLE} = $track->{TITLE} ;
    $values{ALBUM} = $cd->{ALBUM} ;
    $values{NUMBER} = $reply ;
    $values{GENRE} = $cd->{GENRE} if defined $cd->{GENRE} ;
    $values{DATE} = $cd->{YEAR} if defined $cd->{YEAR} ;

    map {
       print "  $_: $values{$_}\n"
    } (keys %values) ;

    return ($TAG_SUCCESS, \%values) ;
}

1 ;
