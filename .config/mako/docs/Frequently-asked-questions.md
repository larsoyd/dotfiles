## Does mako support emojis?

Yes! If they are not working in your system, make sure to install and configure an emoji font. See [this issue](https://github.com/emersion/mako/issues/196).

## Does mako support animated configurations?

Not at the moment, see [this issue](https://github.com/emersion/mako/issues/203).

## Some applications aren't sending notifications after I've installed mako

Many applications only check at startup whether a notification tool is available, and will need to be restarted if they were running at the time you started mako.

## Firefox and Thunderbird notifications are acting like normal windows or otherwise look different

Both depend on libnotify to talk to mako, and will fall back to using its own internal notification mechanism if it isn't installed. See [this issue](https://github.com/emersion/mako/issues/126).

## mako is unable to connect to dbus with "permission denied"

Check if AppArmor is interfering. See [this issue](https://github.com/emersion/mako/issues/257). Note we will no longer install an apparmor profile by default as of 1.5, so any issues will need to be resolved by your distribution after this version.

## I still have more questions!

Make sure to check out the issues, your question may already have an answer! Otherwise feel free to ask on IRC.