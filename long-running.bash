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

    function active_window_id () {
        if [[ -n $DISPLAY ]] ; then
            set - $(xprop -root _NET_ACTIVE_WINDOW)
            echo $5
            return
        fi
        echo nowindowid
    }

    # The file containing information about the currently running command for
    # this shell.  Either empty (meaning no command is running) or in the
    # format "$start_time\n$command", where $command is the currently running
    # command and $start_time is when it started (in UNIX epoch format, UTC).
    last_command_started_cache=$running_commands_dir/$$

    function precmd () {

        if [[ -r $last_command_started_cache ]]; then

            local last_command_started last_command last_window

            {
                read last_command_started
                read last_command
                read last_window
            } < $last_command_started_cache
            if [[ -n "$last_command_started" ]]; then
                local now current_window

                printf -v now "%(%s)T" -1
                current_window=$(active_window_id)
                if [[ $current_window != $last_window ]] ||
                   [[ $current_window == "nowindowid" ]] ; then
                    local time_taken=$(( $now - $last_command_started ))
                    if [[ $time_taken -gt $LONG_RUNNING_COMMAND_TIMEOUT ]] &&
                       [[ -n $DISPLAY ]] ; then
                        notify-send \
                          -i utilities-terminal \
                          -u low \
                          "Long command completed" \
                          "\"$last_command\" took $time_taken seconds"
                    fi
                    if [[ -n $LONG_RUNNING_COMMAND_CUSTOM_TIMEOUT ]] &&
                       [[ -n $LONG_RUNNING_COMMAND_CUSTOM ]] &&
                       [[ $time_taken -gt $LONG_RUNNING_COMMAND_CUSTOM_TIMEOUT ]] ; then
                        # put in brackets to make it quiet
                        ( $LONG_RUNNING_COMMAND_CUSTOM \
                            "\"$last_command\" took $time_taken seconds" & )
                    fi
                fi
            fi
            # No command is running, so clear the cache.
            echo -n > $last_command_started_cache
        fi
    }

    function preexec () {
        printf "%(%s)T\n" -1 > $last_command_started_cache
        echo "$1" >> $last_command_started_cache
        active_window_id >> $last_command_started_cache
    }

    preexec_install
}
