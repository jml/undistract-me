# Copyright (c) 2008-2012 undistract-me developers. See LICENSE for details.
#
# Source this, and then run notify_when_long_running_commands_finish_install
#
# Relies on http://www.twistedmatrix.com/users/glyph/preexec.bash.txt

# Generate a notification for any command that takes longer than this amount
# of seconds to return to the shell.  e.g. if LONG_RUNNING_COMMAND_TIMEOUT=10,
# then 'sleep 11' will always generate a notification.

# Default timeout is 10 seconds.
if [ -z "$LONG_RUNNING_COMMAND_TIMEOUT" ]; then
    LONG_RUNNING_COMMAND_TIMEOUT=10
fi

# The pre-exec hook functionality is in a separate branch.
if [ -z "$LONG_RUNNING_PREEXEC_LOCATION" ]; then
    LONG_RUNNING_PREEXEC_LOCATION=/usr/share/undistract-me/preexec.bash
fi

if [ -f "$LONG_RUNNING_PREEXEC_LOCATION" ]; then
    . $LONG_RUNNING_PREEXEC_LOCATION
else
    echo "Could not find preexec.bash"
fi


function notify_when_long_running_commands_finish_install() {

    # TODO: Only notify if the shell doesn't have focus.  One way to do this
    # is to contact Terminator with our unique id (stored in the environment
    # as TERMINATOR_something_or_other) and ask it if we have focus.  Another
    # way would be to use xprop to get the window ID and compare against
    # $WINDOWID (or the PID & then process tree if necessary).  That will
    # report false positives for tabbed terminals.

    # A directory containing files for each currently running shell (not
    # subshell), each named for their PID.  Each file is either empty,
    # indicating that no command is running, or contains information about the
    # currently running command for that shell.
    local running_commands_dir=~/.cache/running-commands

    mkdir -p $running_commands_dir

    # Clear out any old PID files.  That is, any files named after a PID
    # that's not currently running bash.
    for pid_file in $running_commands_dir/*; do
        local pid=$(basename $pid_file)
        # If $pid is numeric, then check for a running bash process.
        case $pid in
        ''|*[!0-9]*) local numeric=0 ;;
        *) local numeric=1 ;;
        esac

        if [[ $numeric -eq 1 ]]; then
            local command=$(ps --no-headers -o command $pid)
            if [[ $command != $BASH ]]; then
                rm -f $pid_file
            fi
        fi
    done
    unset pid_file

    # The file containing information about the currently running command for
    # this shell.  Either empty (meaning no command is running) or in the
    # format "$start_time\n$command", where $command is the currently running
    # command and $start_time is when it started (in UNIX epoch format, UTC).
    last_command_started_cache=$running_commands_dir/$$

    function precmd () {

        if [[ -r $last_command_started_cache ]]; then

            local last_command_started=$(head -1 $last_command_started_cache)
            local last_command=$(tail -n +2 $last_command_started_cache)

            if [[ -n "$last_command_started" ]]; then
                local now=$(date -u +%s)
                local time_taken=$(( $now - $last_command_started ))
                if [[ $time_taken -gt $LONG_RUNNING_COMMAND_TIMEOUT ]]; then
                    notify-send \
                        -i utilities-terminal \
                        -u low \
                        "Long command completed" \
                        "\"$last_command\" took $time_taken seconds"
                fi
            fi
            # No command is running, so clear the cache.
            echo -n > $last_command_started_cache
        fi
    }

    function preexec () {
        date -u +%s > $last_command_started_cache
        echo "$1" >> $last_command_started_cache
    }

    preexec_install
}
