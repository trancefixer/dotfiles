# homedir
home directory config files

These are some home directory files that I have honed over the decades, and decided to finally share.
I think they've proven useful and stable enough that they should work in most Unix environments.
You will see old stuff in here.  Do not be surprised to see mention of SunOS and AIX and systems without X11.
I hope you can benefit from all the work that went into these.

## installation ##

```
# This will copy these dotfiles
mkdir $HOME/src && (cd $HOME/src && git clone git@github.com:trancefixer/dotfiles.git)
# This will install these dotfiles over your $HOME, so be very careful; -i flag means interactive (asks to overwrite)
(cd $HOME/src/dotfiles && cp -piR ./ $HOME/)
```

## what shells read what files

ash reads:
- .profile (once at login)
- $ENV (with each invocation)

bash reads:
- .bash_profile (once at login)
- .bash_login (once at login)
- .profile (once at login)
- $ENV or .bashrc (with each invocation)

sh reads:
- .profile (once at login)

pdksh reads:
- .profile (once at login)
- $ENV (with each invocation)

Therefore, these files are read by these shells:

| file | sh | ash | pdksh | bash |
| ---- | -- | --- | ----- | ---- |
| .bash_profile | | | | Y |
| .bash_login | | | | Y |
| .profile | Y | Y | Y | Y |
| $ENV | | Y | Y | Y |

To test a created .procmailrc, use:

`procmail -Yf- -m TEST=yes .procmailrc`

Then, input a test message on STDIN.  You may also want to set LOGNAME.  Expect a spurious bounce on large emails, but look for the first rule matched.

## startup shell scripts
I'm starting with my shell startup scripts and will gradually add more.

* `.profile` # sourced at most logins
* `.kshrc` # sourced for every subshell
* `.bash_profile` # for bash-specific things
* `.bashrc` # for bash-specific things
* `.xsession` # for certain kinds of X window logins, used instead of login shell

One of the key takeaways is that anything you would normally put into `.profile` can go into `.profile.local` and so on.
This enables you to update these files without stomping on your local changes.

In general, you should add something to the bourne/ksh shell files unless it's bash-specific.

### details - shell startup sequence

Of all the "dot files", `.profile` presents the greatest opportunity for customization.
This file is read by sh derivatives as part of the login process, and usually sets environment variables that
influence the behavior of many programs invoked as part of that login session.

#### logging in

##### via login(1)

`sh` derivatives consider a shell a login shell when `argv[0]`, begins with a dash (`-`, ASCII value 45).
Note that this is a violation of the convention that the first element of argv[] contain the last component
of the executed program's path (for more information, see `execve(2)`). This is the only way to flag sh as a login shell.
However, ksh accepts `-l` and bash accepts `-login` as alternate ways of flagging a shell as a login shell.

All `sh` derivative login shells first process the system-wide `/etc/profile` if it exists.
The next file processed depends on the shell; `sh` and `ksh` process $HOME/.profile,
while `bash` processes the first it finds of $HOME/.bash_profile, $HOME/.bash_login, and $HOME/.profile.
Note that bash has a flag `-noprofile` which inhibits processing any of these files.

You may wonder where `sh` derivative login shells get their notion of `$HOME`.
The `HOME` environment variable is set by `login(1)`, as are `SHELL`, `PATH`, `TERM`, `LOGNAME`, `USER` (if BSD), `MAIL` (if not BSD),
and `TZ` (if Solaris).
For portability's sake, we should only rely on the common subset of environment variables set by `login(1)`
(if we rely on any of them at all).

Note that `login(1)` will print a variety of messages, unless `$HOME/.nologin` exists.
By the same rationale, we should feel free to output information from `.profile` under the same conditions.
The nologin support is primarily for UUCP and other automated logins, so we need not heed this rule too carefully,
unless you intend to use your .profile for your automated users as well.

##### via X11 & window managers

`.xsession` seems to be used, but I'm not sure exactly by which window managers # TODO


##### about shell startup scripts generally

Since we have the full power of the shell at our disposal when processing `.profile`, we may easily use its branching
constructs to process different parts of this file under different conditions.  This allows us to potentially use the same `.profile`
in many locations, unlike some other dot-files, simplifying the customization of multiple environments into a single file
distribution problem.

Furthermore, we will wish to do some similar and repetitive tasks in our `.profile` so it will be advisable to use its native function
definitions as a macro facility. If we were generating different `.profile` files using some kind of macro language like `m4` or `cpp`,
we could avoid depending on the availability of functions in our shell. However, the environments I am interested in all support
functions within `/bin/sh` so that is an implicit assumption in my `.profile`. This also allows runtime recursion, which preprocessors
could not provide (not that we will need it).

It's extremely difficult to come up with guiding principles and structure for a `.profile`. For one thing, there are several dependencies
that have to be taken into account when creating a linear order for your statements. There are site-specific, OS-specific,
release-specific and architecture-specific components, and components that are specific to two or more of these categories.
Often it is not clear which category certain statements fall into; for example, BSD Unix uses `BLOCKSIZE` to affect the reporting units
in `df`, `du`, and some other programs. It is not clear whether this is a variable which should be set globally, or perhaps in a
BSD-specific portion of the `.profile`. There are design tradeoffs such as the desire for an uncluttered environment and the desire
to keep the `.profile` simple. Another tradeoff occurs when two OSes have similarites (for example, SunOS and BSD both have `/sbin`
directories for the super-user. Do you add `/sbin` to the path in both cases, causing code duplication, or do you make a case
statement that puts both of them together, and add `/sbin` to the path there? Thus, this `.profile` is most definitely a
compromise between several competing desires.

Since `.profile` is only processed once per login session, it's tempting to do a little more work in order to make the `.profile`
simpler. For example, you might want to invoke PERL and have it tell you where its manpages are located, rather than guessing
and testing several possibilities. Similarly, rather than putting `/sbin` handling into all BSD-like OS-specific sections, it
might be cleaner to test for the presence of `/sbin` and handle adding it to the PATH no matter which OS you are running.
Also note that I usually don't bother to preserve environment variables that are already set via `/etc/profile`, although
you may wish to do so.

### the .profile line-by-line

Here's a blow-by-blow for the file (could be out of date)
```
# Hey EMACS this is -*- mode:sh -*-
# Managed in https://github.com/trancefixer/homedir; do not edit the copy in the home directory
# To customize this script, put commands in the file $HOME/.profile.local
```

The first line tells EMACS that this is a shell script in the following line (I believe that more recent versions of EMACS allow mode:sh).
The second line tracks the hash of this version of the script.
The third line tells you not to touch this verison, the fourth line where to add your customizations.

Next I tell the user that the `.profile` is actually being run:

```
## Show login stuff:

# Echo message to fd 2 (stderr).
e2 () { echo "$@" >&2; }
```
The first thing the `.profile` should do is have an indication that it has been invoked.
This lets the user know that e.g. ssh actually worked and the system isn't hung.
This is particularly useful for diagnosing when the startup script is buggy and blocking on e.g. NFS mounts,
as well as give a visual indicator of how heavy the system load is (if it takes a long time to show this, the load is extremely heavy).
This code snippet defines a function (e2) which echoes all of its arguments to the standard error file descriptor
(read that operator as "standard output gets tied to fd 2"). There are occasions where standard output is buffered,
but standard error is usually line-buffered at most, so that is why I use it.
Note the use of double-quoted `$@`; this incantation preserves whitespace and argument boundaries, even if the arguments
include whitespace. It is a good idea to get into the habit of using this in preference to the boundary-destroying `$*`.
The code snippet then invokes e2 to display a simple message. Should you wish, you could easily test for the presence of
a `~/.nologin` file to supress printing any output.

Next I inform the OS that I wish to make all my files shared only by my group:
```
## Set a semi-paranoid umask.
umask 007
```

Next I want to make sure that this `.profile` can find the programs I want to invoke, so I must attend to setting the
`PATH` environment variable, which controls the search path for said programs.
Clearly I will want some functions to help me manipulate the colon-seperated list of directories:

```
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
```

Note that I try to use the term `path` to refer to a slash-seperated list of directories, starting with the root and ending with
a file or directory, whereas I use the term `search path` to refer to a colon-seperated list of paths.

For usage errors I return 2 to distinguish from the exit code of the last command, which could be 0 or 1 or -1.

Next I set up `PATH` elements which should always be present.
I think all reasonable operating systems start `PATH` with these elements, but it shouldn't hurt much to be sure:

```
# These should be present on any target system.
# In fact, they should already be in the search path.
dirapplist PATH /bin /usr/bin
# I like to be able to run e.g. ifconfig, sendmail.
dirapplist PATH /sbin /usr/sbin /usr/games /usr/libexec
dirpre PATH /usr/ucb
export PATH

# Set the search path for manual pages.
dirapplist MANPATH /usr/share/man /usr/share/man/old /usr/contrib/man
export MANPATH

# Set the search path for info pages.
dirapplist INFOPATH /usr/share/info
export INFOPATH

# Set the search path for python programs.
dirapplist PYTHONPATH /lusr/lib/python2.3/site-packages # TODO: remove this hack
```

Note that I mark these variables as exportable. In general my policy is to do so the first time I manipulate the variable.
You can't do `export VAR=VAL` in ash, so I do that on a separate line in .profile and .kshrc

```
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
```
This code tries to figure out which `sh` variant we are using. It then takes care of the shell-dependent initialization commands.
Note that since it uses dirapp, it has to occur after its definition, else I would have placed it earlier in the file.


```
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
```
Here we test to see if our shell supports aliases - this time by a direct test - and if it does, it loads the proper .rc file into the
login shell.  That's necessary because login shells don't default to loading these files (at least when I wrote it).
```
# Do we need the type functionality?
if type type > /dev/null 2>&1
then
    :
else
    test -r "$HOME/.ashtype" && . "$HOME/.ashtype"
fi
```
This section is a little kluge to help /bin/ash support the `type` shell builtin.
```
## Run this stuff on logout.
if test -r "$HOME/.shlogout"
then
    trap '. $HOME/.shlogout' 0
else
    # Make a reasonable attempt to clear the screen.
    trap 'clear' 0
fi
```
This code takes care of cleaning up when we log out.
That is, this code runs when a login shell exits.
If `$HOME/.shlogout` exists and is readable, we evaluate that and exit
with the last command's exit code; otherwise we just clear the screen so that we don't leave our work showing.
If the logout process varied from site to site, it might be more appropriate to put it in the site-specific section.
You could easily do some kind of disk wiping or encryption here.

(more to come)

