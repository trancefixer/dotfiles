#! /bin/sh
# -*- mode:sh -*-
# .xinitrc - an X11 xinit/xdm startup script
#
# This shell script can be invoked by either xinit or xdm as user X 11
# startup script.  It acts as the client process the invoking program
# starts up and waits for (that is, it should not call X itself).
# It typically starts up some xterms and a window manager, for example.
# The logic in the shell script tries to do the ``right thing''
# under a wide variety of X hardware/software configurations.
# When it exits, the X server is terminated.
# See startx(1) or xinit(1) for more details.
#
# Dependencies: onconsole
#

## Environment

userresources="$HOME/.Xresources"
usermodmap="$HOME/.Xmodmap"
sysresources="$XWINHOME/lib/X11/xinit/.Xresources"
sysmodmap="$XWINHOME/lib/X11/xinit/.Xmodmap"

e2 () { echo "$@" >&2; }

# Test a directory (sanity check).
# Returns true (0) only if it is a directory and searchable.
tdir () {
    test "$#" -eq 0 && e2 "Usage: tdir dirname" && return 2
    test -d "$1" && test -x "$1"
}

# Set a specified variable to equal the first valid directory in a list.
setvardir() {
    test "$#" -lt 2 && e2 "Usage: setvardir varname dir1 dir2 ..." && return 2
    local n="$1"
    shift
    while test "$#" -gt 0; do
        tdir "$1" && eval "$n=\"$1\"" && export $n && return 0
	shift
    done
    return 1
}

# NLS path for Motif-based programs
setvardir XNLSPATH /usr/X11/lib/X11/nls

# These are keysyms for Motif programs on non-Motif systems (e.g. netscape?).
test -r "/usr/X11/lib/XKeysymDB" \
&& XKEYSYMDB="/usr/X11/lib/XKeysymDB" \
&& export XKEYSYMDB

# This is the viewing program for the showpicture program in metamail package.
X_VIEWER="xv -24 -geometry +1+1"
export X_VIEWER

# These are options to xli, which used to be used by vf script.
XLIOPTS="-fullscreen -cdither -normalize"
export XLIOPTS

# This is also used by xli.
DISPLAY_GAMMA="2.4"
export DISPLAY_GAMMA

# Only do things to the system console if it is our login terminal.
test -z "$console" && console=$(onconsole -n)

# The incantation below puts all the symbols xrdb defines into shell
# variables.  To avoid possible name conflicts, the symbol names are
# prefixed with ``X_''. The algorithm is:
#
#	1) Put a space at beginning/end of the line (catch boundary conditions)
#
#	2) Any contiguous set of non-space characters starting with -D
#	that does not contain ``='' is a blank definition.  Change this
#	into -Dword=true, so the shell thinks it is a command name.
#	Using ``true'' instead of some other value is handy for things like
#
#		if ${X_COLOR-false} ; then
#			do things you only want to do on a color display
#		fi
#
#	3) Change the -D to an X_ and evaluate the assignment statements
#
#
eval $(xrdb -symbols | sed -e 's/^\(.*\)$/ \1 /' \
	-e 's@ -D\([^= ][^= ]*\) @ -D\1=true@g' -e 's@ -D\([^ ]*\)=@ X_\1=@g')

onserver=true
# Is this running on the same host as the server?
# If the host part of $DISPLAY is ``unix'' or our local hostname,
# then we probably are. HOST_NAME should be set by .profile already.
{ test "$X_SERVERHOST" != "$X_CLIENTHOST" || test -z "$X_SERVERHOST"; } \
&& test unix != "${X_HOST-unix}" \
&& test "$X_HOST" != "${HOST_NAME:=$(hostname)}" \
&& onserver=false

## Server Settings

# Turn on bug compatability if 1) my server is R4 or better and 2) I think
# the xset available to me knows what to do.  I fudge on the second one by
# seeing whether xrdb defines RELEASE (the R3 xrdb does not)

if [ "${X_RELEASE-3}" -gt 3 ] ; then
    # Turned off.  I do not like re-introducing bugs.
    # bugcompat="bc" # R4 server bug compatability mode
    :
fi

# add extra font directories
morefonts=""
if $onserver
then
    test -d $HOME/fonts && test -x $HOME/fonts \
	&& morefonts="${morefonts} fp+ \"$HOME/fonts\""

    test -d "$XWINHOME/lib/X11/fonts/xview" \
	&& test -x "$XWINHOME/lib/X11/fonts/xview" \
	&& morefonts="${morefonts} fp+ \"$XWINHOME/lib/X11/fonts/xview\""
fi

# turn bell on, repeat on, and invoke some other options
xset b on r on $morefonts $bugcompat

# Merge X resources into the server resource database.
# We will also define HOME to be my home directory
# (for establishing my bitmap file path)
test -r "$sysresources" && xrdb -merge "$sysresources"
test -r "$userresources" && xrdb -merge -DHOME="$HOME" "$userresources"

# modify kemaps, if desired
test -r "$sysmodmap" && xmodmap "$sysmodmap"
test -r "$usermodmap" && xmodmap "$usermodmap"

## Clients

# pass on our color depth to any sub-processes (see .mailcap)
BPP="${X_PLANES:-$BPP}"
export BPP

# Run GNOME if it exists.
test -x /etc/X11/xdm/Xsession && exec /etc/X11/xdm/Xsession gnome
 
# xterm for doing stuff on the local Unix system.  If we are not on the
# system console, make it a login shell.
$console || loginshell="-ls"

xterm $loginshell -sb -title "${loginshell:+login }${HOST-$(hostname)}" \
    -geometry 80X25-4+4 &
xtermpid1=$!

xterm $loginshell -sb -title "${loginshell:+login }${HOST-$(hostname)}" \
    -geometry 80x25+4+4 &
xtermpid2=$!

xterm -sb -title 'procmail.log' -geometry 80x8-4+359 \
    -e tail -f "$HOME/tmp/procmail.log" &
logpid=$!

# set a dark background
xsetroot -solid black

geom=1024x768+0+0
vl=/var/log
set -- red orange yellow cyan green purple
rt_flags="-g $geom -no-filename"
for f in messages auth ipmon linksys
do
	f="$vl/$f"
	if test -e $f
	then
		rt_flags="$rt_flags $f,$1"
		shift
	fi
done
root-tail $rt_flags &
monpid=$!

# If we are run from a Sun console, start up a console xterm with a visual
# bell.
if $console && (sun 2>/dev/null) ; then
	xterm -name "Console" -C -geometry 80x24-4-4 -fn 6x10 -vb &
else
	xconsole -exitOnFail -geometry 500x70-4+495 &
fi
consolepid=$!

# Start xautolock to lock the screen.
xautolock -time 30 -locker xlock -corners -00+ -cornerdelay 5 \
	-cornerredelay 30 &

# Start the window manager. If possible, redirect its standard output and
# stderr to /dev/console so we see what is going on.
$console && test -c "$ttyout" && logit=">${ttyout} 2>&1"

if [ "${X_RELEASE-3}" -gt 3 -a -f "$HOME/.twmrc.R4" ] ; then
	twmrc="-f .twmrc.R4"	# use twmrc for R4 twm
fi

# start my window manager
for i in /usr /usr/X11R6 /usr/local
do
	i="$i/bin/fvwm"
	test -x "$i" && wmgr="$i"
done
test -z "$wmgr" && test -x "$XWINHOME/bin/twm" && wmgr="$XWINHOME/bin/twm"
eval "$wmgr" $logit

## Cleanup

# Kill off the clients we started; ignore error messages.
kill $consolepid $xtermpid1 $xtermpid2 $logpid $monpid 2> /dev/null

# On Suns, restore the keyboard to a rational state.
$console && (sun 2>/dev/null) && kbd_mode -a

# fini
exit 0
