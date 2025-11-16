Send notifications in response to volume changes.

![2025-01-27T15:49:30,453748892-03:00](https://github.com/user-attachments/assets/5c05ac91-e272-41a0-b6cb-af27a4c2801b)

_Styling not included_

# Features
- Appears on top of full-screen windows (due to `layer=overlay`).
- Bypasses the do-not-disturb mode.
- Shows a progress bar along with the percentage

# Requirements
- Wireplumber as a Pipewire session manager (tested v0.5.6)
- Mako notification daemon (tested v1.9.0)
- libnotify (tested v0.8.3)

# Setup
## 1. Create the notifier script

```sh
#!/bin/sh

# Get the volume level and convert it to a percentage
volume=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
volume=$(echo "$volume" | awk '{print $2}')
volume=$(echo "( $volume * 100 ) / 1" | bc)

notify-send -t 1000 -a 'wp-vol' -h int:value:$volume "Volume: ${volume}%"
```

Save this file in your `PATH` (e.g. `~/.local/bin`) as `wp-vol`, and make it executable.

## 2. Edit your keybindings
This is an example for the Sway WM.

```diff
-bindsym XF86AudioRaiseVolume exec wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+
+bindsym XF86AudioRaiseVolume exec wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+ && wp-vol

-bindsym XF86AudioLowerVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
+bindsym XF86AudioLowerVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && wp-vol
```

Simply make sure `wp-vol` (the notifier script) is executed after `wpctl`.

Don't forget to reload your config.

## 3. Configure Mako
Put this section in your `~/.config/mako/config`.
```ini
[app-name=wp-vol]
layer=overlay
history=0
anchor=top-center
# Group all volume notifications together
group-by=app-name
# Hide the group-index
format=<b>%s</b>\n%b

[app-name=volume group-index=0]
# Only show last notification
invisible=0
```

Choose a dedicated area of your screen for such notifications (e.g. `anchor=top-center`).

If you have a do-not-disturb mode configured, this will ensure that volume notifications are always visible:
```ini
[mode=do-not-disturb]
invisible=1

# ... the [app-name=wp-vol] section from earlier should be placed after the do-not-disturb definition,
# so it can override it

[app-name=volume grouped=false]
# Force initial volume notification to be visible
invisible=0
```

Finally, reload the daemon.
```sh
makoctl reload
```