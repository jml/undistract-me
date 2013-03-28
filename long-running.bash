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

    function sec_to_human () {
        local H=''
        local M=''
        local S=''

        local h=$(($1 / 3600))
        [ $h -gt 0 ] && H="${h} hour" && [ $h -gt 1 ] && H="${H}s"

        local m=$((($1 / 60) % 60))
        [ $m -gt 0 ] && M=" ${m} min" && [ $m -gt 1 ] && M="${M}s"

        local s=$(($1 % 60))
        [ $s -gt 0 ] && S=" ${s} sec" && [ $s -gt 1 ] && S="${S}s"

        echo $H$M$S
    }

    function precmd () {

        if [[ -n "$__udm_last_command_started" ]]; then
            local now current_window

            printf -v now "%(%s)T" -1
            current_window=$(active_window_id)
            if [[ $current_window != $__udm_last_window ]] ||
                [[ $current_window == "nowindowid" ]] ; then
                local time_taken=$(( $now - $__udm_last_command_started ))
                local time_taken_human=$(sec_to_human $time_taken)
                if [[ $time_taken -gt $LONG_RUNNING_COMMAND_TIMEOUT ]] &&
                    [[ -n $DISPLAY ]] ; then
		    local icon=dialog-information
		    local urgency=low
		    if [[ $__preexec_exit_status != 0 ]]; then
			icon=dialog-error
			urgency=normal
		    fi
                    notify=$(command -v notify-send)
                    if [ -n "$notify" ]; then
                        $notify \
                            -i $icon \
                            -u $urgency \
                            "Long command completed" \
                            "\"$__udm_last_command\" took $time_taken_human"
                    else
                        echo -ne "\a"
                    fi
                fi
                if [[ -n $LONG_RUNNING_COMMAND_CUSTOM_TIMEOUT ]] &&
                    [[ -n $LONG_RUNNING_COMMAND_CUSTOM ]] &&
                    [[ $time_taken -gt $LONG_RUNNING_COMMAND_CUSTOM_TIMEOUT ]] ; then
                    # put in brackets to make it quiet
		    export __preexec_exit_status
                    ( $LONG_RUNNING_COMMAND_CUSTOM \
                        "\"$__udm_last_command\" took $time_taken_human" & )
                fi
            fi
        fi
    }

    function preexec () {
	# use __udm to avoid global name conflicts
        __udm_last_command_started=$(printf "%(%s)T\n" -1)
        __udm_last_command=$(echo "$1")
        __udm_last_window=$(active_window_id)
    }

    preexec_install
}
