# -*- mode:sh -*-
# $Id$
# do not edit the copy in the home directory
# this is read for EVERY invocation of the shell, so keep it short
# NOTE: never print any output from this; it screws up rsh

# syntax from sh(1) to detect interactive shells
case $- in *i*)

    ## commands for interactive use only

    # set up emacs-style bindings for history
    set -o emacs

    ## OS-specific aliases
    case "$OS_NAME" in
      Coherent)
        ## UNIX aliases V7 - coherent
        alias whoami='who am i | cut -f1 -d" "'
        alias apropos='man -k'
        alias w='who'
        alias sreb='sync;sync;sync;sync;sync;sync;sync;sync;sync;sync;reboot'
        ;;
      *BSD*)
        # general
        alias l='ls -la'
        alias lc='ls -CF'
        alias lart='ls -alrt'
        alias larct='ls -larct'
        alias lh='ls -lh'
        alias sreb='shutdown -r now'

        # pf-related
        alias q='pfctl -s queue -v -v'
        alias pflush='pfctl -Fa'
        alias pfr='pfctl -s rules'
        ;;
      SunOS)
        # SunOS's crontab has an annoying exit value check
        alias crontab='VISUAL=emacs crontab'
        ;;
      Linux*)
        # general
        alias sreb='shutdown -r now'

        # apt
        alias agi='apt-get install'
        alias agu='apt-get update'
        alias ags='apt-cache search'
        alias agsh='apt-cache show'
        alias agr='apt-get remove'
        alias agd='apt-get dist-upgrade'

	# iptables
	alias ipt='iptables'
	alias iptl='iptables -L -v --line-numbers'
	;;
      esac

    ## X
    case "$OS_NAME" in
      SunOS)
        alias sx='openwin 2> /tmp/x.stderr.$$ && clear'
        ;;
      *)
        # If we have not defined sx so far, define it as an alias.
        type sx > /dev/null 2>&1 || alias sx='startx 2> /tmp/x.stderr.$$'
        ;;
    esac

    ## shell-specific aliases
    if test -z "$BASH_VERSION"
    then
        # if we don't have BASH, define this handy command
        alias logout='exit'
    fi

    ## misspelled words
    alias mroe='more'
    alias ls-la='ls -la'
    alias sl='ls'
    alias cd..='cd ..'
    alias grpe='grep'

    ## MS-DOS aliases
    alias cls='clear'
    alias dir='ls -la'
    alias md='mkdir'
    alias rd='rmdir'
    alias del='rm'
    alias prune='rm -irf'
    alias move='mv'

    ## system command shortcuts

    # general
    alias e='echo'
    alias cdup='cd ..'
    alias lo='logout'
    alias m='more'
    alias h='history'
    alias k=kill
    alias j=jobs
    alias h=history
    alias pk=pkill
    alias sy=sync
    alias t=top
    alias mvi='mv -i'
    alias igrep='grep -i'
    alias grepi='grep -i'

    # ls
    alias la='ls -la'
    alias lsc='ls -CF'
    alias lsf='ls -CF'
    alias ll='ls -l'
    alias lh='ls -lh'

    # disk space
    alias df="df -h"
    alias du="du -h"

    # ps
    alias psl='ps -alux'
    alias pss='ps -aux'
    alias psaux='ps -aux'
    alias psauxw='ps -auxw'
    alias psgrep='ps -auxwww | grep'

    # shutdowns
    alias sd='shutdown'
    alias suicide='kill -9 -1'

    # editors
    alias vedit='vi'
    alias em='emacs -nw'
    alias tab4='EXINIT="set tabstop=4 showmode" vi'
    alias tab8='EXINIT="set tabstop=8 showmode" vi'

    # su stuff
    if type sudo > /dev/null 2>&1
    then
	# if we have sudo, that sometimes saves us from
	# entering a password, so use that to run su.
	sudo='sudo'
    else
        sudo=''
    fi
    # handy macro
    su="$sudo su"
    # aliases - note double quotes
    alias sbr="if grep -q toor: /etc/passwd; then $su - toor; else $su - root; fi"
    alias sur="$su - root"
    alias xs="if grep -q toor: /etc/passwd; then exec $su - toor; else exec $su - root; fi"
    alias xsur="exec $su - root"

    # screen
    # -a include all capabilities in each window's termcap
    # -A adapt sizes of all windows to the current terminal
    # -D detach session, if currently attached, logging out other session
    # -RR reattach session or create it if necessary
    if false && type byobu > /dev/null 2>&1
    then
	screen=byobu
    else
	screen=screen
    fi
    alias scr="$screen -aA -D -RR"
    alias xsc="exec $screen -aA -D -RR"

    # graphics-related
    alias gif='xv -24 -geometry +1+1'
    alias jpg='xv -24 -geometry +1+1'
    # optimized for speed, interactive use, large displays, small anims
    alias mpg='xanim -Ake +boSs2T1Zpe'

    # security
    alias cfs=i

    # CVS and version control
    alias cup='cvs upd'
    alias cnup='cvs -n upd'
    alias ccom='cvs com'
    alias cci='cvs com'
    alias cdiff='cvs diff'
    alias ucdiff='cvs diff -u'

    # SVN
    alias status='svn status'
    alias commit='svn commit'
    alias svnd='svn diff'
    alias upd='svn update'
    alias update='svn update'

    # MH
    alias n='next'
    alias s='show'
    alias note='anno -component X-Note -text '
    alias pi='pick'
    alias wf='folders | grep -v "no messag"'
    alias f='folder'
    alias rmn='rmm next'
    alias sc='scan'
    alias re='repl'
    alias c='comp'
    alias rf='refile'
    alias p='prev'

    # rsync
    # for general use, especially when files are in use
    alias rs='rsync --human-readable --archive --verbose --stats --progress --hard-links --protect-args'
    # for mirroring when the files aren't in use, preserves links to files outside the transfer
    alias rsmir='rsync --human-readable --archive --verbose --stats --progress --inplace --hard-links --protect-args'
    # same as rsmir but with no preservation of modification time
    alias rscp='rsync --human-readable -rlpgoD --verbose --stats --progress --inplace --hard-links --protect-args'
    # like rsmir but remove the source files once transferred
    alias rsmv='rsync --human-readable --archive --verbose --inplace --stats --progress --remove-source-files --protect-args'
    # same but preserving hard links
    alias rsmvh='rsync --human-readable --archive --verbose --inplace --hard-links --stats --progress --remove-source-files --protect-args'

    # SSH-related
    alias ssht='ssh -l toor'
    alias sshr='ssh -l root'
    alias xssh='eval exec ssh-agent $SHELL'

    # ntp
    alias ntp='ntpq -p'

    # Testing connectivity
    alias pg='ping -n 4.2.2.2'

    # email
    alias results='mutt -f=results'

    # under BASH, any alias which ends in a blank will
    # cause the next word to be checked for aliases, too
    alias x='exec '
    alias xt='xterm -e '
esac

test -r "$HOME/.kshrc.funcs" && . "$HOME/.kshrc.funcs"
test -r "$HOME/.kshrc.local" && . "$HOME/.kshrc.local"
