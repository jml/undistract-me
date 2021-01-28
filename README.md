## Important note

This is a fork of [jml/undistract-me](https://github.com/jml/undistract-me). The original project uses `bash-preexec` incorrectly, making it incompatible with other scripts such as [bash-command-timer](https://github.com/qbouvet/undistract-me/archive/0.1.0.tar.gz), [bash-timer](https://github.com/hopeseekr/bash-timer). 

I have a [pull-request](https://github.com/jml/undistract-me/issues/67) pending on the original project, but the authors seem to have abandonned the project. I made this fork because I need the feature. 

When/If the pull request is accepted, this fork will be deleted.


# undistract-me

Notifies you when long-running terminal commands complete.

## What is this?

Does this ever happen to you?

You're doing some work, and as part of that you need to run a command on the
terminal that takes a little while to finish.  You run the command, watch it
for maybe a second and then switch to doing something else – checking
email or something.

You get so deeply involved in your email that twenty minutes fly by.  When
you switch back to your terminal the command has finished, but you've got no
idea whether it was nineteen seconds ago or nineteen *minutes* ago.

This happens to me a lot.  I'm just not disciplined enough to sit and watch
commands, and I'm not prescient enough to add something to each invocation to
tell me.  What I want is something that alerts me whenever long running
commands finish.

This is it.

Install this, and then you'll get a notification when any command finishes
that took longer than ten seconds to finish.

## Installation

### From the Ubuntu repositories

    $ sudo apt install undistract-me

### From the branch

    $ bzr checkout --lightweight lp:undistract-me
    $ . undistract-me/long-running.bash
    $ notify_when_long_running_commands_finish_install

### Add to your Bash

    $ echo 'source /etc/profile.d/undistract-me.sh' >> ~/.bashrc

## Configuration

By default, a long-running command is any command that takes more than 10s to
complete.  If this default is not right for you, set
`LONG_RUNNING_COMMAND_TIMEOUT` to a different number of seconds and export it.
It is possible to disable notifications for certain commands by adding them 
space-separated to `LONG_RUNNING_IGNORE_LIST` variable.

By default, the notification will only show if the active window is not the 
window the command is running in. If this is not right for you, (eg. if you 
are an Emacs user), you can set IGNORE_WINDOW_CHECK to 1 to skip the window
check.

In addition to a visual notification, you can make undistract-me notify you 
by playing an audible sound along with the notification popup by simply 
setting the variable UDM_PLAY_SOUND to a non-zero integer on the command line.
This functionality requires that pulseaudio-utils and sound-theme-freedesktop 
(which provides the notification sound file) be installed on a Debian-based 
system.

## Licensing

All of undistract-me, including this file, is made available with the Expat
license.  See `LICENSE` for details.

## Getting help

There's no dedicated IRC channel, but feel free to ping `jml` on Freenode,
probably in the `#ubuntu-devel` channel.

Alternatively, ask questions or file bugs on the
[undistract-me](https://launchpad.net/undistract-me) Launchpad project.

## Credits

[Glyph Lefkowitz](http://glyph.twistedmatrix.com/) wrote
[a neat hack to provide ZSH-like preexec support for bash](http://glyf.livejournal.com/63106.html).

A lot of help from [Chris Jones](http://www.tenshu.net/) of
[Terminator](http://www.tenshu.net/p/terminator.html).

[Mikey Neuling](https://github.com/mikey/) and Stephen Rothwell have made huge
improvements to the performance and quality of the shell script.  I'm amazed,
humbled and grateful.
