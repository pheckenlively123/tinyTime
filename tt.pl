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
my $specalTasks;
my $logDir;
my $taskFile;
my $logPrefix;

### Command Line Processing ###

$usage =<<"EOF";
Usage:
    tt -c CONFIG [-r] [-t TASK] [-s LOGFILE] [-h]
Arguments:
    -c CONFIG  XML config file.
    -r         Report mode.
    -t TASK    Track a new task.
    -s LOGFILE Sum up time for tasks in a log file.
    -h         Print usage, and exit.
EOF
    
getopts ( 'rhc:t:s:', $opts );

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

if ( !defined ( $opts->{r} ) && !defined ( $opts->{t} ) ) {
    confess "Both -r and -t are missing.  We need one of them.\n\n" . $usage;
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
    
    $specalTasks = [];
    foreach my $taskNode ( @taskItemNodeList ) {
	my $task = $taskNode->textContent ();
	push ( @{$specalTasks}, $task );
    }
}

sub logTime {
    my $taskName = shift;
    my $taskTime = shift;

    # Task time is the time the task started.  We need to check the
    # current time and calculate the duration for the log from that.

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

### Main Routine ###

parseConfig ();

if ( defined ( $opts->{t} ) ) {
    # We are tracking a task
    trackTask ();
}

if ( defined ( $opts->{r} ) ) {
    # Print the report.
}

if ( defined ( $opts->{s} ) ) {
    # Print the report for a specific log file.
}

exit ( 0 );
