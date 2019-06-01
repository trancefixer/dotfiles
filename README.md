# homedir
home directory config files

These are some home directory files that I have honed over the decades, and decided to finally share.
I think they've proven useful and stable enough that they should work in most Unix environments.
You will see old stuff in here.  Do not be surprised to see mention of SunOS and AIX.
I hope you can benefit from all the work that went into these.

## startup shell scripts
I'm starting with my shell startup scripts and will gradually add more.

* .profile
* .kshrc
* .bash_profile # for bash-specific things
* .bashrc # for bash-specific things

One of the key takeaways is that anything you would normally put into `.profile` can go into `.profile.local` and so on.
This enables you to update these files without stomping on your local changes.
