package Lltag::Misc ;

use strict ;

use vars qw(@EXPORT) ;

@EXPORT = qw (
	      system_with_output
	  ) ;

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

1 ;
