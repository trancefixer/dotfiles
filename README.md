# homedir
home directory config files

These are some home directory files that I have honed over the decades, and decided to finally share.
I think they've proven useful and stable enough that they should work in most Unix environments.
You will see old stuff in here.  Do not be surprised to see mention of SunOS and AIX and systems without X11.
I hope you can benefit from all the work that went into these.

## startup shell scripts
I'm starting with my shell startup scripts and will gradually add more.

* .profile # sourced at most logins
* .kshrc # sourced for every subshell
* .bash_profile # for bash-specific things
* .bashrc # for bash-specific things

One of the key takeaways is that anything you would normally put into `.profile` can go into `.profile.local` and so on.
This enables you to update these files without stomping on your local changes.

In general, you should add something to the bourne/ksh shell files unless it's bash-specific.

### details - shell startup sequence

Of all the "dot files", `.profile` presents the greatest opportunity for customization.
This file is read by sh derivatives as part of the login process, and usually sets environment variables that
influence the behavior of many programs invoked as part of that login session.

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
