#! /bin/sh
# Hey EMACS this is -*- mode:sh -*-
# $Id$
. $HOME/.bash_profile || . $HOME/.profile # X sessoins do not normally read .profile so lets do that
exec $HOME/.xinitrc # no need to do this in a subshell so simply replace this process with that

