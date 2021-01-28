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

# Default is not to play sound along with notification. (0 is false, non-zero is true.)
if [ -z "$UDM_PLAY_SOUND" ]; then
	UDM_PLAY_SOUND=0
fi


# Find and source bash-preexec
#  - If an up-to-date version of bash-preexec is installed at standard 
#    location, then it is used
#  - Otherwise, the outdated version of bash-preexec shipped with 
#    undistract-me is used
function __udm_callback_with_mainline_bashpreexec() {
  source "$1"
  preexec_functions+=(__udm_preexec)
  precmd_functions+=(__udm_precmd)
}
function __udm_callback_with_outdated_bashpreexec() {
  source "$1"
  preexec=__udm_preexec
  precmd=__udm_precmd
  preexec_install
}
# Case 1: find bash-preexec in common installation locations
__udm_register_callbacks=__udm_callback_with_mainline_bashpreexec
if [ -f '/usr/share/bash-preexec/bash-preexec.sh' ]; then 
  __udm_bash_preexec_path='/usr/share/bash-preexec/bash-preexec.sh'
elif [ -f '~/.bash-preexec.sh' ]; then 
  __udm_bash_preexec_path='~/.bash-preexec.sh'
# Case 2: Fallback: use outdated, shipped-along bash-preexec
else 
  __udm_register_callbacks=__udm_callback_with_outdated_bashpreexec
  # The pre-exec hook functionality is in a separate branch.
  __udm_bash_preexec_path="$LONG_RUNNING_PREEXEC_LOCATION"
  if [ -z "$__udm_bash_preexec_path" ]; then
    __udm_bash_preexec_path="/usr/share/undistract-me/preexec.bash"
  fi
  if [ ! -f "$__udm_bash_preexec_path" ]; then
    __udm_bash_preexec_path="$( dirname "${BASH_SOURCE[0]}" )/preexec.bash"
  fi
  if ! [ -f "$__udm_bash_preexec_path" ]; then
    echo "Could not find preexec.bash"
  fi  
fi


function notify_when_long_running_commands_finish_install() {

    function get_now() {
        local secs
        if ! secs=$(printf "%(%s)T" -1 2> /dev/null) ; then
            secs=$(\date +'%s')
        fi
        echo $secs
    }

    function active_window_id () {
        if [[ -n $DISPLAY ]] ; then
            xprop -root _NET_ACTIVE_WINDOW | awk '{print $5}'
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

    function __udm_precmd () {

        if [[ -n "$__udm_last_command_started" ]]; then
            local now current_window

            now=$(get_now)
            current_window=$(active_window_id)
            if [[ $current_window != $__udm_last_window ]] ||
                 [[ ! -z "$IGNORE_WINDOW_CHECK" ]] ||
                [[ $current_window == "nowindowid" ]] ; then
                local time_taken=$(( $now - $__udm_last_command_started ))
                local time_taken_human=$(sec_to_human $time_taken)
                local appname=$(basename "${__udm_last_command%% *}")
                if [[ $time_taken -gt $LONG_RUNNING_COMMAND_TIMEOUT ]] &&
                    [[ -n $DISPLAY ]] &&
                    [[ ! " $LONG_RUNNING_IGNORE_LIST " == *" $appname "* ]] ; then
                    local icon=dialog-information
                    local urgency=low
                    if [[ $__preexec_exit_status != 0 ]]; then
                        icon=dialog-error
                        urgency=normal
                    fi
                    notify=$(command -v notify-send)
                    if [ -x "$notify" ]; then
                        $notify \
                        -i $icon \
                        -u $urgency \
                        "Command completed in $time_taken_human" \
                        "$__udm_last_command"
                        if [[ "$UDM_PLAY_SOUND" != 0 ]]; then
                            paplay /usr/share/sounds/freedesktop/stereo/complete.oga &
                        fi
                    else
                        echo -ne "\a"
                    fi
                fi
                if [[ -n $LONG_RUNNING_COMMAND_CUSTOM_TIMEOUT ]] &&
                    [[ -n $LONG_RUNNING_COMMAND_CUSTOM ]] &&
                    [[ $time_taken -gt $LONG_RUNNING_COMMAND_CUSTOM_TIMEOUT ]] &&
                    [[ ! " $LONG_RUNNING_IGNORE_LIST " == *" $appname "* ]] ; then
                    # put in brackets to make it quiet
                    export __preexec_exit_status
                    ( $LONG_RUNNING_COMMAND_CUSTOM \
                        "\"$__udm_last_command\" took $time_taken_human" & )
                fi
            fi
        fi
    }

    function __udm_preexec () {
        # use __udm to avoid global name conflicts
        __udm_last_command_started=$(get_now)
        __udm_last_command=$(echo "$1")
        __udm_last_window=$(active_window_id)
    }

    $__udm_register_callbacks "$__udm_bash_preexec_path"
}
