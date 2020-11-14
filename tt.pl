#!/usr/bin/perl -w

### Module Section ###

use strict;
use warnings;
use Carp;
use Getopt::Std;
use XML::LibXML;
use JSON;

### Global Variable Section ###

my $usage;
my $opts = {};
my $specialTasks;
my $ignoreTasks;
my $logDir;
my $taskFile;
my $logPrefix;

### Command Line Processing ###

$usage =<<"EOF";
Usage:
    tt -c CONFIG [-t TASK|-s LOGFILE|-l] [-h]
Arguments:
    -c CONFIG    XML config file.
    [-t TASK]    Track a new task.
    [-s LOGFILE] Sum up time for tasks in a log file.
    [-l]         List current task.
    -h           Print usage, and exit.
EOF
    
getopts ( 'hlc:t:s:', $opts );

if ( defined ( $opts->{h} ) ) {
    print $usage;
    exit ( 0 );
}

foreach my $op ( qw / c / ) {
    if ( !defined ( $opts->{$op} ) ) {
	warn "Missing required parameter: $op\n";
	confess $usage;
    }
}

# Cheasy solution for mutually exclusive inputs.
my $cheaseCount = 0;

if ( defined ( $opts->{t} ) ) {
    $cheaseCount++;
}

if ( defined ( $opts->{s} ) ) {
    $cheaseCount++;
}

if ( defined ( $opts->{l} ) ) {
    $cheaseCount++;
}

if ( $cheaseCount != 1 ) {
    warn "Options -t, -s, and -l are mutually exclusive...There can be only one!\n";
    confess $usage;
}

### Subroutine Section ###

# For bigger XML configs, I usually build a wrapper object, so the
# rest of the code does not need to know the details of the config
# file.
sub getSingleConfigTag {
    my $dom = shift;
    my $xpath = shift;

    my @foundList = $dom->findnodes ( $xpath );
    if ( $#foundList != 0 ) {
	confess "There can be only one...$xpath...\n";
    }

    my $foundNode = shift ( @foundList );
    my $rv = $foundNode->textContent ();

    return $rv;
}

sub parseConfig {
    
    my $dom = XML::LibXML->load_xml (
	location => $opts->{c} );
    
    # Get the logging dir.
    $logDir = getSingleConfigTag ( $dom, '//logging' );
    
    # Get taskFile.
    $taskFile = getSingleConfigTag ( $dom, '//taskFile' );

    # get logPrefix.
    $logPrefix = getSingleConfigTag ( $dom, '//logPrefix' );

    # Get the taskItem nodes.
    my @taskItemNodeList = $dom->findnodes ( '//specialTasks/taskItem' );
    
    $specialTasks = [];
    foreach my $taskNode ( @taskItemNodeList ) {
	my $task = $taskNode->textContent ();
	push ( @{$specialTasks}, $task );
    }

    # Get the ignoreItem nodes.
    my @ignoreItemNodeList = $dom->findnodes ( '//ignoreTasks/ignoreItem' );

    $ignoreTasks = [];
    foreach my $ignoreNode ( @ignoreItemNodeList ) {
	my $ignore = $ignoreNode->textContent ();
	push ( @{$ignoreTasks}, $ignore );
    }
}

sub modTime {
    my $diffTime = shift;
    my $divider = shift;

    my $remainder = $diffTime % $divider;
    my $diveTime = $diffTime - $remainder;
    my $retTime = $diveTime / $divider;

    return $retTime, $remainder;
}

sub timeBreakDown {
    my $diffTime = shift;

    my $days = 0;
    my $hours = 0;
    my $minutes = 0;
    my $seconds = 0;
    
    if ( $diffTime > 86400 ) {
	# We have been on this task for more than 24 hours...(Arg!)
	( $days, $diffTime ) = modTime ( $diffTime, 86400 );
    }

    if ( $diffTime > 3600 ) {
	# We have been working for more than an hour.
	( $hours, $diffTime ) = modTime ( $diffTime, 3600 );
    }

    if ( $diffTime > 60 ) {
	# We have been working for more than a minute.
	( $minutes, $diffTime ) = modTime ( $diffTime, 60 );
    }

    if ( $diffTime > 0 ) {
	$seconds = $diffTime;
    }

    return $days, $hours, $minutes, $seconds;
}

sub makeDateTime {
    my $inTime = shift;

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	localtime( $inTime );
    
    $mon++;
    $year += 1900;

    my $rv = sprintf
	"%04d-%02d-%02dT%02d:%02d:%02d", $year, $mon, $mday, $hour,
	$min, $sec;

    return $rv;
}
    
sub logTime {
    my $taskName = shift;
    my $taskTime = shift;

    # Task time is the time the task started.  We need to check the
    # current time and calculate the duration for the log from that.

    my $startStamp = makeDateTime ( $taskTime );
    my $endStamp = makeDateTime ( time () );
    
    my $diffTime = time () - $taskTime;

    my ( $days, $hours, $minutes, $seconds ) = timeBreakDown ( $diffTime );
    
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	localtime(time());
    
    $mon++;
    $year += 1900;

    my $logLine = sprintf
	"%s to %s\t%s\t%02d:%02d:%02d:%02d",
	$startStamp, $endStamp, $taskName, $days, $hours,
	$minutes, $seconds;

    print "\nLogging: $logLine\n\n";

    my $logFile = sprintf "%s/%s-%04d-%02d-%02d", $logDir, $logPrefix,
	$year, $mon, $mday;

    open ( my $WT, '>>', $logFile )
	or confess "Failed to open $logFile for append: $!\n";

    print {$WT} "$logLine\n";

    close ( $WT )
	or confess "Failed to close $logFile from append: $!\n";
}

sub printCurrentTask {

    if ( -f $taskFile ) {
	
	open ( my $RD, '<', $taskFile )
	    or confess "Failed to open $taskFile for read: $!\n";
	
	my $inJrec = '';
	while ( my $line = <$RD> ) {
	    $inJrec .= $line;
	}
	
	close ( $RD )
	    or confess "Failed to close $taskFile from read: $!\n";
	
	my $inRec = from_json ( $inJrec );

	my $diffTime = time () - $inRec->{taskTime};

	print "Currently working on:\n";
	printNormal ( $inRec->{taskName}, $diffTime );
	printSpecial ( $inRec->{taskName}, $diffTime );
	
    } else {
	confess "Nothing is currently being track, so no task on which to report.\n";
    }
}

sub trackTask {

    if ( -f $taskFile ) {
	# The task file already exists, so we must be tracking
	# something.  Pull what is in there out, and log the task
	# duration in the logging directory.  Then write the new task
	# into the file with the start time.

	open ( my $RD, '<', $taskFile )
	    or confess "Failed to open $taskFile for read: $!\n";

	my $inJrec = '';
	while ( my $line = <$RD> ) {
	    $inJrec .= $line;
	}

	close ( $RD )
	    or confess "Failed to close $taskFile from read: $!\n";

	my $inRec = from_json ( $inJrec );
	logTime ( $inRec->{taskName}, $inRec->{taskTime} );

	my $rec = {};
	$rec->{taskName} = $opts->{t};
	$rec->{taskTime} = time ();

	my $jRec = to_json ( $rec );

	open ( my $WT, '>', $taskFile )
	    or confess "Failed to open $taskFile for write: $!\n";

	print {$WT} "$jRec";

	close ( $WT )
	    or confess "Failed to close $taskFile from write: $!\n";
	

    } else {

	# The task file does not exist yet, so we need to create it.
	my $rec = {};
	$rec->{taskName} = $opts->{t};
	$rec->{taskTime} = time ();

	my $jRec = to_json ( $rec );

	open ( my $WT, '>', $taskFile )
	    or confess "Failed to open $taskFile for write: $!\n";

	print {$WT} "$jRec";

	close ( $WT )
	    or confess "Failed to close $taskFile from write: $!\n";
    }
}

sub printReport {

    my $rep = {};
    my $logFile = sprintf "%s/%s", $logDir, $opts->{s};
    my $grandTotal = 0;

    open ( my $RD, '<', $logFile )
	or confess "Failed to open $logFile for read: $!\n";

    while ( my $line = <$RD> ) {
	chomp ( $line );

	# Intentionally throwing away the date information.  That part
	# of the file is for the humans...
	my ( $junk, $task, $timeRec ) = split ( /\t/, $line );
	my ( $day, $hour, $min, $sec ) = split ( ':', $timeRec );

	if ( !defined ( $rep->{$task} ) ) {
	    $rep->{$task} = 0;
	}

	# Convert all the time into seconds.
	$rep->{$task} += $day * 86400;
	$rep->{$task} += $hour * 3600;
	$rep->{$task} += $min * 60;
	$rep->{$task} += $sec;
    }

    close ( $RD )
	or confess "Failed to close $logFile from read: $!\n";

    print "\nTask Time:\n\n";
    
    foreach my $task ( sort keys %{$rep} ) {
	my $printFlag = 1;
	my $totalTask = 1;

	foreach my $ignore ( @{$ignoreTasks} ) {
	    if ( $task eq $ignore ) {
		$totalTask = 0;
		last;
	    }
	}

	if ( $totalTask ) {
	    $grandTotal += $rep->{$task};
	}

	foreach my $special ( @{$specialTasks} ) {
	    if ( $task =~ /$special/ ) {
		printSpecial ( $task, $rep->{$task} );
		$printFlag = 0;
		last;
	    }
	}

	if ( $printFlag ) {
	    printNormal ( $task, $rep->{$task} );
	}
    }

    print "\n";

    printNormal ( "Total:", $grandTotal );
    printSpecial ( "Total:", $grandTotal );

    print "\n";
}

sub printSpecial {
    my $task = shift;
    my $timeVal = shift;

    my ( $days, $hours, $minutes, $seconds ) = timeBreakDown ( $timeVal );

    printf "%20s -> %02dd %02dh %02dm %02ds\n", $task, $days, $hours,
	$minutes, $seconds;
}

sub printNormal {
    my $task = shift;
    my $timeVal = shift;

    $timeVal = $timeVal / 3600;

    printf "%20s -> %s\n", $task, $timeVal;
}

### Main Routine ###

parseConfig ();

if ( defined ( $opts->{t} ) ) {
    # We are tracking a task
    trackTask ();
}

if ( defined ( $opts->{s} ) ) {
    # Print the report for a specific log file.
    printReport ();
}

if ( defined ( $opts->{l} ) ) {
    # Display current task with current time worked.
    printCurrentTask ();
}

exit ( 0 );
