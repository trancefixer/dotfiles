#
# $Id$

# I know, you're asking; why is this in the .rc file?
# Because I don't want Bourne sub-shells getting this PS1; it doesn't work.
# For that same reason, we do NOT export it
# (the only other way to do it is to set PS1 for EVERY shell in the .rc file)

bold="\[$(tput md 2> /dev/null)\]" || unset bold
norm="\[$(tput me 2> /dev/null)\]" || unset norm
PS1="$bold"'\t \u@\h $SHLVL $(echo $?) \s\$'"$norm "

# under BASH, any alias which ends in a blank will
# cause the next word to be checked for aliases, too
alias x='exec '
alias xt='xterm -e '

test -r $HOME/.bashrc.local && . $HOME/.bashrc.local
test -r $HOME/.kshrc && . $HOME/.kshrc
