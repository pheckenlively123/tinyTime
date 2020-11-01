# tinyTime

Many employers like to track how their employees spend their time at work.
This small utility aims to take some of the pain out of that process.

tinyTime reports time in two different formats, decimal hours, and a
more detailed time breakdown based on days, hours, minutes, and
seconds.  An example of this more detailed time reporting style is
provided below.

         PKENUM -> 00d 05h 36m 07s

The specialTasks section of the config.xml lets uses specify regexes
that will receive the more detailed time view.

Some time keeping systems work best with just decimal hours.  Others need a break down by hours and minutes.  Pick the system that works best for the items you are tracking.

End users will want to adjust the config.xml, and run runAndGun.sh.
The script will prompt for the next task, and it provides a running
breakdown of the tasks worked so far for the day.

Use the runAndGun.sh script to total up specific time logs in the logs
directory.

Most of the time, end users should not need to run tt.pl directly, but
if they do, the usage declaration is provided below.

<pre>
Usage:
    tt -c CONFIG [-t TASK|-s LOGFILE|-l] [-h]
Arguments:
    -c CONFIG    XML config file.
    [-t TASK]    Track a new task.
    [-s LOGFILE] Sum up time for tasks in a log file.
    [-l]         List current task.
    -h           Print usage, and exit.
</pre>