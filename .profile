# $Id$
# Hey EMACS this is -*- mode:sh -*-

# This is sourced at login-time by sh, ash, ksh, and bash.

# Assumptions: login(1) sets HOME SHELL PATH TERM LOGNAME
#              XDM(1) sets DISPLAY PATH SHELL XAUTHORITY

# Login script order:
# sh, ash, ksh  /etc/profile ~/.profile
# bash          /etc/profile (~/.bash_profile ~/.bash_login ~/.profile)

# To customize this script, put commands in the file $HOME/.profile.local

## Show login stuff:

# Echo message to fd 2 (stderr).
e2 () { echo "$@" >&2; }

e2 'Running .profile'

## Set a semi-paranoid umask.
umask 007

## Set colon-seperated search path elements:

# Test a directory (sanity check).
# Returns true (0) only if it is a directory and searchable.
test_directory () {
    test "$#" -eq 0 && e2 "Usage: test_directory dirname" && return 2
    test -d "$1" && test -x "$1"
}

# Canonicalize a directory name by dereferencing symlinks.
canonicalize_directory () {
    test_directory "$1" && echo $(cd "$1"; /bin/pwd)
}

# Check to see if a directory is already in a search path.
in_search_path () {
    test "$#" -lt 2 && e2 "Usage: in_search_path path dirname" && return 2
    local n="$1"
    local d="$2"
    eval 'case $'$n' in *:'$d':*) return 0; esac'
    return 1
}

# Sanity-check then append a directory to a search path.
dirapp () {
    test "$#" -lt 2 && e2 "Usage: dirapp varname dirname" && return 2
    local n="$1"
    local d="$2"
    d=$(canonicalize_directory "$d") || return 1
    eval in_search_path \"\$$n\" $d && return 1
    if eval test -n \"\$$n\"; then
        eval $n=\"\$$n:$d\"
    else
        eval $n=\"$d\"
    fi
}

# Sanity-check then prepend a directory to a search path.
# TODO: Allow caller to "move" directory to front with this funcall.
dirpre () {
    test "$#" -lt 2 && e2 "Usage: dirpre varname dirname" && return 2
    local n="$1"
    local d="$2"
    d=$(canonicalize_directory "$d") || return 2
    # eval in_search_path \"\$$n\" $d && return 1
    if eval test -n \"\$$n\"; then
        eval $n=\"$d:\$$n\"
    else
        eval $n=\"$d\"
    fi
}

# Call dirapp for a list of directories.
dirapplist () {
    test "$#" -lt 2 && e2 "Usage: dirapplist varname d1 d2 ..." && return 2
    local n="$1"
    shift
    while test "$#" -gt 0; do
        dirapp "$n" "$1"
        shift
    done
}

# Call dirpre for a list of directories.
# NOTE: Directories will appear in reverse order in varname.
dirprelist () {
    test "$#" -lt 2 && e2 "Usage: dirapplist varname d1 d2 ..." && return 2
    local n="$1"
    shift
    while test "$#" -gt 0; do
        dirpre "$n" "$1"
        shift
    done
}

manpath () {
    test "$#" -lt 2 && e2 "Usage: manpath base1 base2 ..." && return 2
    local n="$1"
    shift
    while test "$#" -gt 0; do
        dirapplist MANPATH "$n"/share/man "$n"/man
        shift
    done
}

# These should be present on any target system.
# In fact, they should already be in the search path.
dirapplist PATH /bin /usr/bin
# I like to be able to run e.g. ifconfig, sendmail.
dirapplist PATH /sbin /usr/sbin /usr/games /usr/libexec /usr/ccs/bin
dirpre PATH /usr/ucb
export PATH

# Set the search path for manual pages.
dirapplist MANPATH /usr/share/man /usr/share/man/old /usr/contrib/man
export MANPATH

# Set the search path for info pages.
dirapplist INFOPATH /usr/share/info
export INFOPATH

# Set the search path for python programs.
dirapplist PYTHONPATH /lusr/lib/python2.3/site-packages

## Do shell-specific handling:

# This code distinguishes between various shell versions.
if test "$(echo ~)" != "$HOME"
then
    # This is the standard Bourne shell.
    :
else
    # TODO: Figure out a deterministic way to distinguish shells.
    # Should I just check $SHELL instead?
    if test "${RANDOM:-0}" -eq "${RANDOM:-0}"
    then
        # Tell ash where to find our shell functions.
        # NOTE: We can't use dirapp because %func isn't part of the path.
        test_directory "$HOME/functions" && PATH="$PATH:$HOME/functions%func"
    fi
fi

# Do we support aliases?
if alias test=test > /dev/null 2>&1
then
    unalias test
    for alias_file in .bashrc .kshrc
    do
      alias_file="$HOME/$alias_file"
      if test -r "$alias_file"
      then
          echo Loading aliases from "$alias_file"
          export ENV="$alias_file"
          # NB: to get aliases in login shell you need to source it.
          . "$ENV"
      fi
    done
fi
# Do we need the type functionality?
if type type > /dev/null 2>&1
then
    :
else
    test -r "$HOME/.ashtype" && . "$HOME/.ashtype"
fi


## Run this stuff on logout.
if test -r "$HOME/.shlogout"
then
    trap '. $HOME/.shlogout' 0
else
    # Make a reasonable attempt to clear the screen.
    trap 'clear' 0
fi

## Set the environment variables:

# Try to set the envar called by name in arg1 to the output of the commands
# that follow, one argument per command.
setvarcmd () {
    test "$#" -lt 2 \
        && e2 "Usage: setvarcmd varname \"cmd1 args\" \"cmd2 args\" ..." \
        && return 2
    local n="$1"
    shift
    while test "$#" -ge 1 && eval test -z \"\$$n\"; do
        eval "$n=\"$($1 2>/dev/null)\""
        shift
    done
    # TODO: what if no commands generate ouput?
    export $n
}

setvarcmd OS_NAME "uname -s" "uname"
e2 "Operating system: $OS_NAME"

setvarcmd OS_RELEASE "uname -r"
e2 "Release: $OS_RELEASE"

setvarcmd HW_NAME "arch" "uname -m"
e2 "Hardware/Architecture name: $HW_NAME"

# NOTE: This frequently does not include the domain name.
setvarcmd HOST_NAME "hostname -f" "uname -n" "hostname"
e2 "Host Name: $HOST_NAME"

# Add the domain name, if it has not been specified.
# This makes it easier to write site-specific clauses.
FQDN="$HOST_NAME"
case "$HOST_NAME" in
    *.*) ;;
    *) while read cmd rest
    do
        if test "$cmd" = domain
        then
            FQDN="$FQDN.$rest"
            break
        fi
    done < /etc/resolv.conf
    ;;
esac
e2 "FQDN: $FQDN"

# Parse out the domain name (FQDN minus the first section)
DOMAIN_NAME="${FQDN#*.}"
e2 "Domain Name: $DOMAIN_NAME"

# Find some other binary directories, but only for the right architecture.
# Set MAIL to point to mailbox so shell can tell us when we have mail.
# TODO: fix for mailbox in $HOME/mbox.
case "$OS_NAME" in
    AIX)
        dirapp PATH /public/ibm/bin
        ;;
    SunOS*)
        dirapp PATH /public/sun4/bin
        # Find my mail box and have this shell check it periodically.
        # NOTE: Do not export or subshells will check mail too.
        test_directory /usr/spool/mail && MAIL=/usr/spool/mail/$LOGNAME
        ;;
    *BSD)
        test_directory /var/mail && MAIL=/var/mail/$LOGNAME
        ;;
esac

# Set a specified variable to equal the first valid directory in a list.
# TODO: Should I check to see if it is set already?
setvardir() {
    test "$#" -lt 2 && e2 "Usage: setvardir varname dir1 dir2 ..." && return 2
    local n="$1"
    shift
    while test "$#" -gt 0; do
        test_directory "$1" && eval "$n=\"$1\"" && export $n && return 0
        shift
    done
    return 1
}

# I had to use Openwin on some SunOS machines.
if setvardir OPENWINHOME /usr/openwin; then
    dirapp PATH "$OPENWINHOME/bin"
    dirapp MANPATH "$OPENWINHOME/share/man"
    dirapp LD_LIBRARY_PATH "$OPENWINHOME/lib"
fi

# This is for the new Sun CDE desktop
if test_directory /usr/dt; then
    dirapp MANPATH /usr/dt/man
    dirapp PATH /usr/dt/bin
    dirapp LD_LIBRARY_PATH /usr/dt/lib
fi

# XWINHOME is used by some startx(1), XF86Setup(1), and
# apparently xman(1), XF86_S3(1), etc.
# Technically I should only accept /usr/X386 if we are on an x86,
# but what would it be doing there on another architecture anyway?
if setvardir XWINHOME /usr/X11R6 /usr/X386; then
    # put X executables in search path
    dirapp PATH "$XWINHOME/bin"
    # put X manpages in search path
    dirapp MANPATH "$XWINHOME/man"
fi

findperlmanpages() { dirapplist MANPATH "$(perl -MConfig -e 'for $key (keys %Config)
{ if ($key =~ /man.*dir/) { $a{$Config{$key}}=1; } }; print join(":", sort keys %a);')"; }

# Find locally-installed programs.
if setvardir LOCALIZED /usr/local /local /lusr /opt; then
    # Prepend locally-installed program dir so it can override system binaries.
    dirpre PATH "$LOCALIZED/bin"
    # Search here for manual pages.
    dirprelist MANPATH "$LOCALIZED/share/man" "$LOCALIZED/man"
    # BSD systems might have this, others probably will not.
    dirpre PATH "$LOCALIZED/sbin"
    # Some sites insist on per-package bin directories, sigh.
    # NOTE: This could go later in this file, as a site-dependent section,
    # but these directories probably will not exist on most systems.
    for i in tex gnu tk tcl elm expect ghostscript lotus netmake newsprint \
             tk nmh mh samba; do
        dirapp PATH "$LOCALIZED/$i/bin"
        dirapp MANPATH "$LOCALIZED/$i/man"
    done
    findperlmanpages $LOCALIZED
    dirapp MANPATH "$LOCALIZED/teTeX/man"
    # This is the info path for GNU info hypertext command, and EMACS
    dirapplist INFOPATH "$LOCALIZED/info" \
                        "$LOCALIZED/share/info" \
                        "$LOCALIZED/teTeX/info"
    # Sometimes programs in /usr/local/bin require this.
    dirapp LD_LIBRARY_PATH "$LOCALIZED/lib"
    # This was required to run Lotus Notes at one site
    dirapp LD_LIBRARY_PATH "$LOCALIZED/lotus/common/lel/r100/sunspa53"
    # Set the cool Concurrent Version System repository directory.
    setvardir CVSROOT "$LOCALIZED/share/cvsroot" 
fi

# Find package directory, if any.
# Do not use PKGDIR as this conflicts with package makefiles.
if setvardir PACKAGEDIR /usr/pkg; then
    # Prepend elements to path.
    dirpre PATH "$PACKAGEDIR/bin"
    dirpre PATH "$PACKAGEDIR/sbin"
    # Search here for manual pages
    dirpre MANPATH "$PACKAGEDIR/man"
    dirapplist INFOPATH "$PACKAGEDIR/info" "$PACKAGEDIR/share/info"
fi

# Find my installed programs.
# NOTE: If we boot up in single-user mode, home directory is root.
if test "$HOME" != "/"; then
    # I have even more control over these so they get prepended.
    dirprelist PATH "$HOME/bin" "$HOME/bin/$OS_NAME" \
                    "$HOME/bin/$OS_NAME/$OS_RELEASE"
    dirpre LD_LIBRARY_PATH "$HOME/lib"
    dirapp MANPATH "$HOME/man" "$HOME/share/man"
    findperlmanpages $HOME
    dirapp INFOPATH "$HOME/share/info"
    # Set the Pretty Good Privacy filepath (where it finds its files).
    setvardir PGPPATH "$HOME/pgp"
    # Set the cool Concurrent Version System repository directory.
    setvardir CVSROOT "$HOME/share/cvsroot" 
fi

# There is no convenient place to do this above so do it here.
export LD_LIBRARY_PATH

# Echo the full filename of the executable in the path to stdout.
# NOTE: All args are call-by-value.
findinpath () {
    test "$#" -lt 1 && e2 "Usage: findinpath exe_basename [path]" && return 2
    local f="$1"
    local IFS=":$IFS"
    set -- ${2:-$PATH}
    while test "$#" -gt 0
    do
        test -x "$1/$f" && echo "$1/$f" && return 0
        shift
    done
    return 1
}

# This is my preferred editor.
if EDITOR=$(findinpath emacs)
then
    EDITOR="$EDITOR -nw"
else
    EDITOR=$(findinpath vi)
fi
export EDITOR

# This is the visual, or full-screen editor of choice.
VISUAL="$EDITOR"
export VISUAL

# This is the editor for the fc builtin (for ksh).
FCEDIT="$EDITOR"
export FCEDIT

# EX init file or commands (used in vi(1))
EXINIT="set tabstop=4 showmode"
export EXINIT
# TODO: is this test sufficient and correct?
test "$OS_NAME" = "NetBSD" && EXINIT="$EXINIT verbose"

# This is my personal CVS working area.
setvardir CVSHOME "$HOME/dev/cvs"

# TEMP is a temporary directory for many programs:
# cc gcc mailq merge newaliases sendmail rcs (and friends)
# ghostscript i386-mach3-gcc perlbug perldoc
setvardir TEMP $HOME/tmp /tmp

# TMPDIR is a temporary directory for these programs:
# sort
# NOTE: gcc tries TMPDIR, then TMP, then TEMP
setvardir TMPDIR $HOME/tmp /tmp

# Use a large tmp dir for metamail.
setvardir METAMAIL_TMPDIR $HOME/tmp /tmp

# BLOCKSIZE is the size of the block units used by several commands:
# df, du, ls
# For more information see NetBSD environ(7).
BLOCKSIZE="1k"
export BLOCKSIZE

# CVS_RSH lets us use ssh instead of rsh for client/server
CVS_RSH=$(findinpath ssh)
export CVS_RSH
RSYNC_RSH=$(findinpath ssh)
export RSYNC_RSH

# Set the pagination program for man, mailers, etc.
if PAGER=$(findinpath less); then
    # We found less so set less options:
    #   -M = more verbose than "more"
    #   -f = force special files to be opened
    LESS="-Mf"
    export LESS

    # latin1 Selects  the  ISO 8859/1 character set.  latin-1 is
    #        the same as ASCII, except  characters  between  161
    #        and 255 are treated as normal characters.
    LESSCHARSET="latin1"
    export LESSCHARSET
else
    # Every system should have this.
    PAGER=$(findinpath more)
fi
export PAGER

# This is required to keep Fedora from using UTF-8 encoding in manpages,
# which make things like "&<80><98>" appear in manpages and such.
# To demonstrate, try: LANG="en_US.utf8" man iptables
# TODO: Figure out what the hell I'm doing with this stuff.
LANG="C"
export LANG

## Show fortune for fun:
type fortune > /dev/null 2>&1 && fortune -a

onconsole () {

    # If passed -n, do not print anything.
    if test "$1" = "-n"
    then
        ech () { :; }
    else
        ech () { echo "$@"; }
    fi

    ttyout="$(tty 2>&1)" \
        || ttyout="$(who am i | cut -c 10- | { read foo junk; echo "$foo"; })"

    case "$ttyout" in
        # ( We are on the system console if this pattern matches.
        # vga,ttyv*,ttyE* are for NetBSD
        # tty[0-9]* is for Linux
        /dev/vga|/dev/ttyv*|/dev/ttyE*|/dev/tty[0-9]*|/dev/console|/dev/ttyC*) ech "true"; return 0 ;;
        # ( Anything else means no.
        *) ech "false"; return 1 ;;
    esac

    echo "Should never get here!" 1>&2
}

console=$(onconsole)

# Export it for .xinitrc to use.
export console

## OS-dependent fixes:

case "$OS_NAME" in
    NetBSD*)
        case "$OS_RELEASE" in
            0*|1.0*|1.1)
                # MANPATH does not work in early releases of NetBSD
                unset MANPATH
                ;;
        esac
        ;;
esac

## Set up terminal and start X if appropriate.

# If we weren't started under X, then start it.
if test -z "$DISPLAY"; then

    if test -r "$HOME/.tset"
    then
        . "$HOME/.tset"
    else
        # If tset exists, use it to set up the terminal.
        if type tset > /dev/null 2>&1
        then
            # Set TERM and TERMCAP variables
            if test "$TERM" = "pcvt25h" \
                    && test "$OS_NAME" = "NetBSD" \
                    && test "$OS_RELEASE" = "1.1A"
            then
                e2 "Skipping tset due to $OS_NAME termcap buffer overflow bug"
            else
                eval $(tset -s -m 'network>9600:?xterm' -m 'unknown:?vt100' \
                               -m 'dialup:?vt100')
            fi
        fi
    
        export LINES
        export COLUMNS
    
        # This is OS-dependent terminal setup.
        case "$OS_NAME" in
            NetBSD)
                # PCVT was the primary console driver in NetBSD early on.
                # Today it has been replaced by wscons, which is more portable.
                # However, old ispcvt binaries incorrectly identify wscons
                # as a PCVT terminal, but old scon binaries fail.
                case "$OS_RELEASE" in
                    1.[0-4]*)
                        if ispcvt 2> /dev/null
                        then
                            # 28 lines on screen, HP function keys, 80 columns
                            # NB: due to bug in scon, it only sets the row/col
                            # of ttys if it is done in two commands like so:
                            scon -s 28 && scon -H && scon -8
                            LINES=25
                            COLUMNS=80
                        fi
                        ;;
                    1.[5-9]*)
                        # TODO: Set up wscons.
                        :
                        ;;
                esac
                ;;
	    OpenBSD)
	        case $(tty) in
		    /dev/console|/dev/ttyC*|/dev/tty0*) : console=true;;
		    *) : console=false;
		esac
		;;
            # This is untested.
            SunOS)
                case $(tty) in
                    /dev/console)
                       # TODO: put this in sx function.
                       exec /usr/openwin/bin/openwin
                       echo "Something weird happened."
                       ;;
                esac
                ;;
            *)
                # Be conservative about screen if not known.
                LINES=24
                COLUMNS=80
                ;;
        esac
    fi
        if $console && type sx > /dev/null 2>&1 && type X > /dev/null 2>&1
        then
                sx
        else
                if test -z "$SSH_AGENT_PID"
                then
                    test -f "$HOME/.profile.local" && . "$HOME/.profile.local"
                    # TODO: this is incompatible with ksh
                    type -path ssh-agent > /dev/null && exec ssh-agent $SHELL
                fi
        fi
else
    # We started under X; add our key.
    # Unfortunately it also asks if we forward auth via ssh.
    test "$SHLVL" -le 1 && ssh-add < /dev/null
fi

test -r "$HOME/.profile.funcs" && . "$HOME/.profile.funcs"

test -r "$HOME/.profile.local" && . "$HOME/.profile.local"

# TODO: launch screen or byobu as appropriate, if they exist

# Exit with true value for "make test".
:
