#!/bin/bash

# preexec.bash -- Bash support for ZSH-like 'preexec' and 'precmd' functions.

# The 'preexec' function is executed before each interactive command is
# executed, with the interactive command as its argument.  The 'precmd'
# function is executed before each prompt is displayed.

# To use, in order:

#  1. source this file
#  2. define 'preexec' and/or 'precmd' functions (AFTER sourcing this file),
#  3. as near as possible to the end of your shell setup, run 'preexec_install'
#     to kick everything off.

# Note: this module requires 2 bash features which you must not otherwise be
# using: the "DEBUG" trap, and the "PROMPT_COMMAND" variable.  preexec_install
# will override these and if you override one or the other this _will_ break.

# This is known to support bash3, as well as *mostly* support bash2.05b.  It
# has been tested with the default shells on MacOS X 10.4 "Tiger", Ubuntu 5.10
# "Breezy Badger", Ubuntu 6.06 "Dapper Drake", and Ubuntu 6.10 "Edgy Eft".


# Copy screen-run variables from the remote host, if they're available.

if [[ "$SCREEN_RUN_HOST" == "" ]]
then
    SCREEN_RUN_HOST="$LC_SCREEN_RUN_HOST"
    SCREEN_RUN_USER="$LC_SCREEN_RUN_USER"
fi

# This variable describes whether we are currently in "interactive mode";
# i.e. whether this shell has just executed a prompt and is waiting for user
# input.  It documents whether the current command invoked by the trace hook is
# run interactively by the user; it's set immediately after the prompt hook,
# and unset as soon as the trace hook is run.
preexec_interactive_mode=""

function bash_preexec () {
    local savedqmark="$?";
    _setqmark "${savedqmark}";
    preexec;
    for f in "${preexec_functions[@]}"; do
        _setqmark "${savedqmark}";
        "${f}" "$@";
    done;
}

function bash_precmd () {
    local savedqmark="$?";
    _setqmark "${savedqmark}";
    precmd;
    for f in "${precmd_functions[@]}"; do
        _setqmark "${savedqmark}";
        "${f}" "$@";
    done;
}

# This function is installed as the PROMPT_COMMAND; it is invoked before each
# interactive prompt display.  It sets a variable to indicate that the prompt
# was just displayed, to allow the DEBUG trap, below, to know that the next
# command is likely interactive.
function preexec_invoke_cmd () {
    local savedqmark="$?";
    last_hist_ent="$(HISTTIMEFORMAT= history 1)";
    _setqmark "${savedqmark}";
    bash_precmd;
    preexec_interactive_mode="yes";
}

function _setqmark () {
    return "$1";
}

# This function is installed as the DEBUG trap.  It is invoked before each
# interactive prompt display.  Its purpose is to inspect the current
# environment to attempt to detect if the current command is being invoked
# interactively, and invoke 'preexec' if so.
function preexec_invoke_exec () {
    local savedqmark="$?";
    if [[ -n "$COMP_LINE" ]]; then
        # We're in the middle of a completer.  This obviously can't be
        # an interactively issued command.
        return;
    fi
    if [[ -z "$preexec_interactive_mode" ]]; then
        # We're doing something related to displaying the prompt.  Let the
        # prompt set the title instead of me.
        return;
    else
        # If we're in a subshell, then the prompt won't be re-displayed to put
        # us back into interactive mode, so let's not set the variable back.
        # In other words, if you have a subshell like
        #   (sleep 1; sleep 2)
        # You want to see the 'sleep 2' as a set_command_title as well.
        if [[ 0 -eq "$BASH_SUBSHELL" ]]
        then
            preexec_interactive_mode="";
        fi;
    fi;
    if [[ "preexec_invoke_cmd" == "$BASH_COMMAND" ]]; then
        # Sadly, there's no cleaner way to detect two prompts being displayed
        # one after another.  This makes it important that PROMPT_COMMAND
        # remain set _exactly_ as below in preexec_install.  Let's switch back
        # out of interactive mode and not trace any of the commands run in
        # precmd.

        # Given their buggy interaction between BASH_COMMAND and debug traps,
        # versions of bash prior to 3.1 can't detect this at all.
        preexec_interactive_mode="";
        return;
    fi;

    # In more recent versions of bash, this could be set via the "BASH_COMMAND"
    # variable, but using history here is better in some ways: for example, "ps
    # auxf | less" will show up with both sides of the pipe if we use history,
    # but only as "ps auxf" if not.
    hist_ent="$(HISTTIMEFORMAT= history 1)";
    local prev_hist_ent="${last_hist_ent}";
    last_hist_ent="${hist_ent}";
    if [[ "${prev_hist_ent}" != "${hist_ent}" ]]; then
        local this_command="$(echo "${hist_ent}" | sed -e "s/^[ ]*[0-9]*[ ]*//g")";
    else
        local this_command="";
    fi;

    # If none of the previous checks have earlied out of this function, then
    # the command is in fact interactive and we should invoke the user's
    # preexec hook with the running command as an argument.
    _setqmark "${savedqmark}";
    bash_preexec "$this_command";
}

# Execute this to set up preexec and precmd execution.
function preexec_install () {

    # zsh has this functionality already, so don't do anything.
    [[ $ZSH_VERSION ]] && return 0;

    # Default do-nothing implementation of preexec.
    function preexec () {
        return "$?";
    }

    # Default do-nothing implementation of precmd.
    function precmd () {
        return "$?";
    }

    preexec_functions=();
    precmd_functions=();

    # *BOTH* of these options need to be set for the DEBUG trap to be invoked
    # in ( ) subshells.  This smells like a bug in bash to me.  The null stackederr
    # redirections are to quiet errors on bash2.05 (i.e. OSX's default shell)
    # where the options can't be set, and it's impossible to inherit the trap
    # into subshells.

    set -o functrace > /dev/null 2>&1
    shopt -s extdebug > /dev/null 2>&1

    # Finally, install the actual traps.  Note: this must be the _last_ command
    # in PROMPT_COMMAND for it to work, otherwise the debug trap will get
    # confused and execute for random other commands.
    PROMPT_COMMAND="${PROMPT_COMMAND}"$'\n'"preexec_invoke_cmd;";
    trap 'preexec_invoke_exec' DEBUG;
}

# Since this is the reason that 99% of everybody is going to bother with a
# pre-exec hook anyway, we'll include it in this module.

# Change the title of the xterm.
function preexec_xterm_title () {
    local title="$1";
    echo -ne "\033]0;$title\007" 1>&2;
}

function preexec_screen_title () {
    local title="$1";
    echo -ne "\033k${title}\033\\" 1>&2;
}

# Abbreviate the "user@host" string as much as possible to preserve space in
# screen titles.  Elide the host if the host is the same, elide the user if the
# user is the same.
function preexec_screen_user_at_host () {
    if [[ "$SCREEN_RUN_HOST" == "$SCREEN_HOST" ]]
    then
        return
    else
        if [[ "$SCREEN_RUN_USER" == "$USER" ]]
        then
            echo -n "@${SCREEN_HOST}";
        else
            echo -n "${USER}@${SCREEN_HOST}";
        fi
    fi
}

function timing_precmd () {
    # elapsed-time/ran-command calculation follows
    local rancmd="";
    if [ -n "${thiscmd}" ]; then
        local rancmd=" (${PROMPTCHAR} ${thiscmd})";
        local when="${cmdstart}";
    else
        local when="${prevstart}";
        local rancmd="";
    fi;
    local showelapsed="";
    if [ -n "${when}" ]; then
        local now="$(date +%s)";
        local elapsed="$(($now-$when))";
        if [[ "${elapsed}" != 0 ]]; then
            local showelapsed=" (${elapsed} seconds elapsed)";
            if type terminal-notifier > /dev/null 2>&1 ; then
                # NB: PROMPT_LAST_ERROR is a feature of settings.bash, which
                # means this is a layering violation.
                if [[ "${elapsed}" -gt 1 ]]; then
                    # https://stackoverflow.com/a/34503049/13564
                    local sendactivator="$(case "${TERM_PROGRAM}" in
    (Apple_Terminal)
        echo -n com.apple.terminal;
        ;;
    (iTerm.app)
        echo -n com.googlecode.iterm2;
        ;;
    (*)
        echo -n com.apple.Mail;
        ;;
    esac;
)";
                    terminal-notifier \
                        -title "Command '${thiscmd}'" \
                        -subtitle "ran for ${elapsed} seconds" \
                        -message "$(
if [[ "${PROMPT_LAST_ERROR}" == "0" ]]; then
    echo "and completed successfully.";
else
    echo "then exited with status ${PROMPT_LAST_ERROR}";
fi;
)" \
                        -activate "${sendactivator}";
                fi;
            fi;
        fi;
    fi;
    local done_symbol="â†ª";
    if [[ "$TERM" == "cygwin" ]]; then
        done_symbol="->";
    fi;
    echo -e "\033[38;5;88m ${done_symbol} $(date)${rancmd}${showelapsed}\033[0m" 1>&2;
}

function timing_preexec () {
    # xterm seems to treat backslashes funny; they terminate the escape
    # sequence or something.  I'm not sure why, but if we don't escape them
    # by doubling them (like so) then running an interactive command with a
    # backslash in it will result in a messed-up terminal and half a
    # terminal title echoed onto the command line.
    thiscmd="$(echo "$1" | sed -e 's/\\/\\\\/g' | head -n 1)"
    if [ -z "$1" ]; then
        prevstart="${cmdstart}";
        cmdstart="$(date '+%s')";
        return;
    fi;
    local start_symbol="â†©";
    if [[ "$TERM" == "cygwin" ]]; then
        start_symbol="<-";
    fi;
    echo -e "\033[38;5;23m ${start_symbol} $(date)\033[0m" 1>&2;
    prevstart="${cmdstart}";
    cmdstart="$(date '+%s')";
}

function preexec_xterm_title_install () {
    # These functions are defined here because they only make sense with the
    # preexec_install below.
    preexec_install;

    function xterm_title_precmd () {
        if [[ "${TERM}" == screen ]]; then
            preexec_screen_title "$(preexec_screen_user_at_host)${PROMPTCHAR}";
        fi;
        preexec_xterm_title \
            "${PROMPTCHAR} - ${USER}@${SCREEN_HOST} $(dirs -0)";
        timing_precmd "$@";
    }

    function xterm_title_preexec () {
        timing_preexec "$@";
        preexec_xterm_title \
            "${TERM} - $thiscmd {`dirs -0`} (${USER}@${SCREEN_HOST})";
        if [[ "${TERM}" == screen ]]
        then
            local cutit="$1"
            local cmdtitle=`echo "$cutit" | cut -d " " -f 1`
            if [[ "$cmdtitle" == "exec" ]]
            then
                local cmdtitle=`echo "$cutit" | cut -d " " -f 2`
            fi
            if [[ "$cmdtitle" == "screen" ]]
            then
                # Since stacked screens are quite common, it would be nice to
                # just display them as '$$'.
                local cmdtitle="${PROMPTCHAR}"
            else
                local cmdtitle=":$cmdtitle"
            fi
            preexec_screen_title "$(preexec_screen_user_at_host)${PROMPTCHAR}$cmdtitle";
        fi
    }
    precmd_functions+=(xterm_title_precmd);
    preexec_functions+=(xterm_title_preexec);
}

function preexec_timing_install () {
    preexec_install;
    precmd_functions+=(timing_precmd);
    preexec_functions+=(timing_preexec);
}