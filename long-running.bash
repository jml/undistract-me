# Source this, and then run notify_when_long_running_commands_finish_install
#
# Relies on http://www.twistedmatrix.com/users/glyph/preexec.bash.txt

if [ -f preexec.bash ]; then
    . preexec.bash
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
    local RUNNING_COMMANDS_DIR=~/.cache/running-commands

    mkdir -p $RUNNING_COMMANDS_DIR

    # Clear out any old PID files.  That is, any files named after a PID
    # that's not currently running bash.
    for pid_file in $RUNNING_COMMANDS_DIR/*; do
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

    # The file containing information about the currently running command for
    # this shell.  Either empty (meaning no command is running) or in the
    # format "$start_time\n$command", where $command is the currently running
    # command and $start_time is when it started (in UNIX epoch format, UTC).
    _LAST_COMMAND_STARTED_CACHE=$RUNNING_COMMANDS_DIR/$$

    function precmd () {
        local TIMEOUT=30

        if [[ -r $_LAST_COMMAND_STARTED_CACHE ]]; then

            local last_command_started=$(head -1 $_LAST_COMMAND_STARTED_CACHE)
            local last_command=$(tail -n +2 $_LAST_COMMAND_STARTED_CACHE)

            if [[ -n $last_command_started ]]; then
                local now=$(date -u +%s)
                local time_taken=$(( $now - $last_command_started ))
                if [[ $time_taken -gt $TIMEOUT ]]; then
                    notify-send \
                        -i utilities-terminal \
                        -u low \
                        "Long command completed" \
                        "\"$last_command\" took $time_taken seconds"
                fi
            fi
            # No command is running, so clear the cache.
            echo -n > $_LAST_COMMAND_STARTED_CACHE
        fi
    }

    function preexec () {
        date -u +%s > $_LAST_COMMAND_STARTED_CACHE
        echo "$1" >> $_LAST_COMMAND_STARTED_CACHE
    }

    preexec_install
}
