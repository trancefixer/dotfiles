# Hey EMACS this is -*- mode:sh -*-
# $Id$
# Managed in https://github.com/trancefixer/homedir; do not edit the copy in the home directory
# To customize this script, put commands in the file $HOME/.bash_profile.local

echo Running .bash_profile

set -o notify

# shell variables
export notify=1
export history_control=ignoredups
export hostname_completion_file=~/.hosts
export no_exit_on_failed_exec=1
export command_oriented_history=1
export HISTSIZE=500
export HISTFILESIZE=500

# shell functions
for i in $HOME/functions/*
do
    if [ -f $i ]
    then
	. $i
	export -f $(basename $i)
    fi
done

# Run .bash_profile.local if it exists
test -r $HOME/.bash_profile.local && . $HOME/.bash_profile.local

# .profile never exits so do this first
test -r $HOME/.bashrc && . $HOME/.bashrc

# must come after shell functions so sx will work
test -r $HOME/.profile && . $HOME/.profile
