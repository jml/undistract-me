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

    function active_window_id () {
        if [[ -n $DISPLAY ]] ; then
            set - $(xprop -root _NET_ACTIVE_WINDOW)
            echo $5
            return
        fi
        echo nowindowid
    }

    function precmd () {

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
    }

    function preexec () {
        last_command_started=$(printf "%(%s)T\n" -1)
        last_command=$(echo "$1")
        last_window=$(active_window_id)
    }

    preexec_install
}
