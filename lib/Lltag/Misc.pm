package Lltag::Misc ;

use strict ;

use Term::ReadLine;
use Term::ANSIColor ;

use vars qw(@EXPORT) ;

@EXPORT = qw (
	      system_with_output
	      init_readline
	      exit_readline
	      readline
	      print_question
	  ) ;

###################################################################
# rewrite of system which returns a descriptor of a stream
# containing both stdout and stderr
sub system_with_output {
    pipe (my $pipe_out, my $pipe_in) ;
    my $pid = fork() ;
    if ($pid < 0) {
	# in the father, when fork failed
	close $pipe_in ;
	close $pipe_out ;
	return (-1, "Failed to fork to execute command line: ". join (" ", @_) ."\n") ;
    } elsif ($pid > 0) {
	# in the father, when fork done
	close $pipe_in ;
	waitpid($pid, 0);
	my $status = $? >> 8 ;
	$status = -1
	    if $status == 255 ;
	my @lines = <$pipe_out> ;
	close $pipe_out ;
	return ( $status , @lines ) ;
    } else {
	# in the child
	close $pipe_out ;
	open STDERR, ">&", $pipe_in ;
	open STDOUT, ">&", $pipe_in ;
	{ exec @_ } ;
	print $pipe_in "Failed to execute command line: ". join (" ", @_) ."\n" ;
	print $pipe_in "Please install $_[0] properly (see README).\n"
	    if $!{ENOENT} or $!{EPERM} ;
	close $pipe_in ;
	exit -1 ;
    }
}

###################################################################
# print a question in bold

sub print_question {
    print color 'bold' ;
    print shift ;
    print color 'reset' ;
}

###################################################################
# configure readline depending on the features provided by the installation
my $term ;
my $attribs ;
my $readline_firsttime ;
my $myreadline ;
my $history_dir ;
my $history_file ;

# dumb readline replacement
sub dummy_readline {
    my $indent = shift ;
    my $prompt = shift ;
    my $preput = shift ;
    my $clear_allowed = shift ;
    $preput = "" if not defined $preput ;
    print $indent."The current value is given in parenthesis, <ENTER> to keep it"
	. ($clear_allowed ? ", <CLEAR> to clear it" : "")
	. ".\n"
	if $readline_firsttime ;
    $readline_firsttime = 0 ;
  ASK:
    my $val = $term->readline ("$indent$prompt ($preput) ? ") ;
    return $preput if !$val ;
    $val = "" if $val eq "CLEAR" or $val eq "<CLEAR>" ;
    if (!$val and !$clear_allowed) {
	print "$indent  Clearing is not allowed here.\n" ;
	goto ASK ;
    }
    return $val ;
}

# true readline wrapper
sub real_readline {
  my $indent = shift ;
  my $prompt = shift ;
  my $preput = shift ;
  my $clear_allowed = shift ;
  $preput = "" if not defined $preput ;
 ASK:
  my $val = $term->readline ("$indent$prompt ? ", $preput) ;
  if (!$val and !$clear_allowed) {
      print "$indent  Clearing is not allowed here.\n" ;
      goto ASK ;
  }
  return $val ;
}

# the actual wrapper
sub readline {
    return &$myreadline (@_) ;
}

# initialization
sub init_readline {
    $history_dir = shift ;
    $history_file = shift ;

    $term = Term::ReadLine->new('lltag editor') ;
    $attribs = $term->Attribs ;
    $term->ornaments('md,me,,') ;
    $readline_firsttime = 1 ;

    # read the history file
    eval {
	if (-f $history_dir."/".$history_file) {
	    $term->ReadHistory ($history_dir."/".$history_file)
		or warn "Failed to open history file $history_dir/$history_file: $!\n" ;
	}
    } unless $term->Features->{ReadHistory} ;

    if ($term->Features->{preput}) {
	$myreadline = \&real_readline ;
    } else {
	$myreadline = \&dummy_readline ;
    }
}

# exit, saves readline history if supported by the installation
sub exit_readline {

    # only keep the last 100 entries
    eval {
	$term->StifleHistory (100);
    } unless $term->Features->{StifleHistory} ;

    # save the history file
    eval {
	if (!-d $history_dir."/") {
	    mkdir $history_dir
		or warn "Failed to create $history_dir directory to store the history file: $!.\n" ;
    }
	$term->WriteHistory ($history_dir."/".$history_file)
	    or warn "Failed to write history file $history_dir/$history_file: $!.\n" ;
    } unless $term->Features->{WriteHistory} ;
}

1 ;
