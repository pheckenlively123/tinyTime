#!/usr/bin/bash

function printPrompt {
    echo "Current task: "
    cat current.json
    echo ""
    ./tt.pl -c config.xml -s $(ls logs | tail -n 1)
    echo "Enter task to track: "
}

printPrompt

while read it ; do
    echo ""
    echo "Starting track on: $it"
    
    ./tt.pl -c config.xml -t $it

    printPrompt
done
