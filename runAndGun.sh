#!/usr/bin/bash

function printPrompt {
    # List current task
    ./tt.pl -c config.xml -l
    echo ""
    # List time report for most recent time log.
    ./tt.pl -c config.xml -s $(ls logs | tail -n 1)
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
