#!/usr/bin/bash

function printPrompt {
    # List current task
    ./tt.pl -c config.xml -l
    echo ""
    # List time report for most recent time log.
    logList=$(ls logs | tail -n 1)
    if [ "$logList" == "" ]; then
	echo "No logs yet.  :-P"
    else
	./tt.pl -c config.xml -s $(ls logs | tail -n 1)	
    fi
    echo "Enter task to track: "
}

printPrompt

while read it ; do

    if [ "$it" != "" ]; then
	echo ""
	echo "Starting track on: $it"
    
	./tt.pl -c config.xml -t $it
    fi

    printPrompt
done
