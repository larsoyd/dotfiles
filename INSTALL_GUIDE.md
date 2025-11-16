# Complete Arch Linux Tutorial (Hyprland w/ Automounting Partitions)

This is a Arch installation guide for the Hyprland window manager on Arch Linux.

**GPT Auto-Mount + Hyprland + NVIDIA**

> **Prerequisites:** This guide assumes you have an AMD processor with NVIDIA graphics.

## 1. Boot from ISO

Let's kick things off by confirming the live environment is healthy before diving deeper.

Set up your keyboard layout if you're not on an US keyboard, and verify UEFI boot:

```bash
# Load a Norwegian keyboard layout if you're not using the US default
loadkeys no-latin1

# Make the console font readable on high-resolution displays
setfont ter-118n

# Sync system clock
timedatectl set-ntp true

# --- Web Test (wired & Wi-Fi) ---

# See your links & their state (names like enpXsY for Ethernet, wlan0 for Wi-Fi)
# interface listing
ip link

# networkd's view; "configured" with DHCP is what you want
networkctl list

---

Ethernet:

# If you're on Ethernet, DHCP should be automatic on the ISO.
# You can confirm an IPv4/IPv6 address like:
# Look for "Address:" and "Gateway:"
networkctl status | sed -n '1,80p'

---

Wi-Fi:

# If you're on Wi-Fi, (1) make sure nothing is soft-blocked, (2) connect with iwctl.
# Check for soft blocks on wireless devices
rfkill list

# Unblock Wi-Fi if you see "Soft blocked: yes" for wlan (safe to run always)
rfkill unblock all

# Discover your wireless device name (often "wlan0" on ISO)
iwctl device list

# Scan for SSIDs (keep the quotes if your AP name has spaces)
iwctl station "YOUR-DEV" scan

# List available networks so you can pick the right one
iwctl station "YOUR-DEV" get-networks

# Connect to your Wi-Fi; iwctl will prompt for the passphrase
iwctl station "YOUR-DEV" connect "YOUR-SSID"

---

# DNS & IP sanity checks (these distinguish raw IP reachability vs DNS resolution)
ping -c 3 archlinux.org
```

## 2. Partition the NVMe drive with systemd-repart

With networking sorted, it's time to carve up the disk exactly how the final system needs it.

```bash
# Inspect block devices before partitioning
lsblk -l

# Set the device you want to operate on (change if lsblk shows a different path)
d=/dev/nvme0n1

# Define the desired partitions for systemd-repart using nano
mkdir -p /tmp/repart.d
```

```bash
# Create 10-esp.conf
nano /tmp/repart.d/10-esp.conf

# 10-esp.conf
[Partition]
Type=esp
Label=EFI
Format=vfat
SizeMinBytes=2G
SizeMaxBytes=2G
```

```bash
# Create 20-root.conf
nano /tmp/repart.d/20-root.conf

# 20-root.conf
[Partition]
Type=root
Label=root
Format=ext4
```

```bash
# Preview the plan
systemd-repart --definitions=/tmp/repart.d --empty=force "$d"

# Apply the changes for real. Pick ONE of these options.
#
# OPTION A) Normally without fast_commit:
#
systemd-repart --definitions=/tmp/repart.d --dry-run=no --empty=force "$d"

---

# OPTION B) If you want `fast_commit` enabled you run this command.
#
# ext4 has a faster journaling system called fast_commit
# Note that some users have reported instability using it, however.
# It should be fine nowadays, but if unsure don't enable it.
#
# According to the Arch wiki it significantly improves journaling performance:
#
# Run systemd-repart with fast_commit enabled
SYSTEMD_REPART_MKFS_OPTIONS_EXT4='-O fast_commit' \
  systemd-repart --definitions=/tmp/repart.d --dry-run=no --empty=force "$d"

---

# Optional: verify results
lsblk -f "$d"

# Optional: verify fast_commit results
# You should see fast_commit listed under features:
tune2fs -l /dev/disk/by-label/root | grep features

# optional, stronger check:
# Check dumpe2fs output for the fast commit feature
dumpe2fs -h /dev/disk/by-label/root | grep -i 'Fast commit length'
```

## 3. Mount filesystems (labels match your original layout)

After laying out partitions, mounting them in the right order keeps the rest of the install smooth.

```bash
# Mount root first
mount /dev/disk/by-label/root /mnt
```

### 3.1 Create and mount EFI directory with strict masks

#### 3.1.1 Here is some information on why I am mounting EFI like this:

```md
Those options are a security-friendly way to mount the EFI System Partition.
They won’t get in your way for normal use.

fmask=0177 and dmask=0077: VFAT does not store Unix permissions.
These masks tell the kernel how to fake them: files become 600 (owner read/write, no exec),
directories 700 (owner only).

In other words, only root can read or write there, and files are not marked executable.
They are the right defaults for an EFI partition and won’t interfere with normal operation.

noexec: blocks running programs from that filesystem. 
nodev: device files on that filesystem are not treated as devices. 
nosuid: any setuid or setgid bit is ignored, so binaries there cannot gain elevated privileges.
```

```bash
# Create the EFI mountpoint inside /mnt
mkdir -p /mnt/efi

# Mount the EFI System Partition with restrictive masks
mount -o fmask=0177,dmask=0077,noexec,nodev,nosuid /dev/disk/by-label/EFI /mnt/efi
```

## 4. Base System Install

With filesystems ready, populate the base system so the rest of the tooling has a foundation.

First update mirrorlist for optimal download speeds, obv replace Norway and Germany.
A good rule of thumb here is doing your country + closest neighbours and then a few larger neighbours after that.
So for me it's Norway,Sweden,Denmark then Germany,Netherlands:

```bash
# Update mirrorlist before install so you install with fastest mirrors
# PROTIP: "\" lets you split a long command across readable lines.
reflector \
      --country 'Norway,Sweden,Denmark,Germany,Netherlands' \
      --age 12 \
      --protocol https \
      --sort rate \
      --latest 10 \
      --save /etc/pacman.d/mirrorlist

# When you understand all of this you can use a faster version of this that I like to use:
reflector -c NO,SE,DK,DE,NL -a 12 -p https \
      -l 10 --sort rate --save /etc/pacman.d/mirrorlist
```

and then **Install the base of Arch Linux!** :

```bash
# Install the Arch base system (AMD CPU baseline works everywhere)
pacstrap /mnt base
```

## 5. System Configuration

Now that the base packages are present, hop into the new system and tailor it to your preferences.

### 5.1 Enter the New System

```bash
# However before you can say you've installed arch you need to configure the system
# This is how you chroot into your newly installed system:
#
# Enter the new system's root using chroot
arch-chroot /mnt
```

### 5.2 Set Timezone

```bash
# Set timezone to your own continent and city
ln -sf /usr/share/zoneinfo/Europe/Oslo /etc/localtime

# Set hardware clock
hwclock --systohc
```

### 5.3 Configure Locale

```bash
# Now we are going to configure our system language.
# I am going to have my system be in English,
# but my time and date will be set as it is in Norway.
# So an English system with a DD/MM/YYYY and 00:00 "military clock".
#
# Open /etc/locale.gen so you can enable the locales you need
nano /etc/locale.gen

# Go down the list and uncomment both:
# Uncomment: en_US.UTF-8 UTF-8 # English
# Uncomment: nb_NO.UTF-8 UTF-8 # Bokmål Norwegian (replace with your own or leave out)

# Then generate locales
# Generate the locales you just enabled
locale-gen

# Set system locale
# Define LANG/LC_TIME in /etc/locale.conf
nano /etc/locale.conf

# add
# LANG for system language
LANG=en_US.UTF-8
# LC_TIME for date & time to my specific LANG default
LC_TIME=nb_NO.UTF-8


# Set console keymap & font
# Open /etc/vconsole.conf to keep the console readable at boot
nano /etc/vconsole.conf

# add
# Skip this if US keyboard
KEYMAP=no-latin1
# But add this console font to make the console larger and more readable on boot
FONT=ter-118n
# This is a console font which makes it larger,
# and more easily readable on boot

```

### 5.4 Set Hostname and Hosts

```bash
# Set hostname, echo lets you do it quickly w/o using nano
# good for one line stuff
#
# Write your hostname into /etc/hostname in one go
echo "BigBlue" > /etc/hostname

# Configure hosts file
# Edit /etc/hosts so the hostname resolves locally
nano /etc/hosts

# Add to /etc/hosts:
127.0.0.1 localhost BigBlue
::1       localhost
```

### 5.5 Create User Account

```bash
# Set root password
passwd

# Create user with necessary groups
useradd -m -G wheel lars
# Set the new user's password right away
passwd lars

# Enable sudo for wheel group
EDITOR=nano visudo
# Uncomment: %wheel ALL=(ALL:ALL) ALL
```


### 5.6 Create swap file & Configure Zswap

```bash
# Create a 16 GiB swap file and initialize it in one step.
#   --size 16G   -> allocate a 16 GiB file
#   --file       -> create the file with correct mode and real blocks
#   -U clear     -> clear any existing UUID in the header
mkswap -U clear --size 16G --file /swapfile

```
edit:
```bash
# Create the swap unit so systemd manages the file
nano /etc/systemd/system/swapfile.swap
```
and add:
```ini
[Unit]
Description=Swap file

[Swap]
What=/swapfile
Priority=100

[Install]
WantedBy=swap.target
```
then:
```bash
# Enable the swapfile unit for every boot
systemctl enable swapfile.swap
```

#### 5.6.1 Optimizations for swap use

```bash
# These are optimizations taken from the wiki.
# Generally considered to be optimal.
# Create a sysctl drop-in for zswap tuning
nano /etc/sysctl.d/99-zswap.conf

# add
vm.swappiness = 100
vm.page-cluster = 0
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125

# update the sysctl
# Reload sysctl configs so the zswap tweaks apply immediately
sysctl --system
```

## 6. Install the System

With core configuration out of the way, build up the broader software stack and performance tweaks.

```bash
# Import and locally sign the CachyOS repo key
# Grab the CachyOS signing key from Ubuntu's keyserver
pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com
# Locally sign the CachyOS key so pacman trusts it
pacman-key --lsign-key F3B607488DB35A47
```

```bash
# Install keyring and mirrorlists
pacman -U 'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst'
pacman -U 'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-22-1-any.pkg.tar.zst'
pacman -U 'https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v4-mirrorlist-22-1-any.pkg.tar.zst'
```

```bash
# Edit /etc/pacman.conf
nano /etc/pacman.conf
```

```bash
# Above core add the znver4 repos:
# CachyOS znver4 repos for AMD Zen 4 and Zen 5
# Keep the Arch repos ([core], [extra], [multilib]) exactly as they are.

[cachyos-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos-core-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist

[cachyos-extra-znver4]
Include = /etc/pacman.d/cachyos-v4-mirrorlist
```

### 6.1 Update mirrors and run reflector to new Cachy mirrors
```bash
# Update package database
pacman -Syu

# Update reflector
reflector -c NO,SE,DK,DE,NL -a 12 -p https \
--sort rate --fastest 10 --download-timeout 30 --save /etc/pacman.d/mirrorlist
```

### 6.2 Install ccache and config ccache
```bash
# Install ccache so rebuilds go faster
pacman -S --needed ccache

# Allow ccache to ignore locale/time macros for reproducible hits
ccache --set-config=sloppiness=locale,time_macros
```

### 6.3 Build Optimization
```bash
# Open /etc/makepkg.conf to tune build flags
nano /etc/makepkg.conf
```

### 6.4 Optimize builds
```bash
# Add these flags for optimized builds
CFLAGS="-march=znver4 -O3 -pipe -fno-plt -fexceptions \
        -Wp,-D_FORTIFY_SOURCE=3 -Wformat -Werror=format-security \
        -fstack-clash-protection -fcf-protection -mpclmul"
CXXFLAGS="$CFLAGS -Wp,-D_GLIBCXX_ASSERTIONS"

MAKEFLAGS="-j$(nproc)"
NINJAFLAGS="-j$(nproc)"

LDFLAGS="-Wl,-O1 -Wl,--sort-common -Wl,--as-needed -Wl,-z,relro -Wl,-z,now \
         -Wl,-z,pack-relative-relocs"

GOAMD64=v4

LTOFLAGS="-flto=auto"
```

#### 6.3.1 Find the BUILDENV= line (note the !ccache)

```sh
# Find this ... :
BUILDENV=(!distcc color !ccache check !sign)

# ... and this line:
OPTIONS=(... !lto ...)
```


#### 6.3.2 Update BUILDENV and OPTIONS
```sh
# So you just remove the ! in front of ccache and lto.
# The man page explicitly says that ccache in BUILDENV tells
# makepkg to use ccache for compilation.
BUILDENV=(!distcc color ccache check !sign)

# Tells makepkg to inject those LTO flags when
# building packages that do not explicitly disable lto.
OPTIONS=(... lto ...)
```

### 6.5 Install Packages
```bash
# Install the core toolchain and shells you want available
pacman -S --needed git base-devel mesa-git linux-firmware nano amd-ucode sudo zsh dash

# Install waybar & polkit here before entering as user so you can enable the systemctl for it
pacman -S --needed waybar hyprpolkitagent
```

```bash
# Set zsh as default shell for user and root
# set dash as default for bin/sh
# Make zsh the default shell for your user
chsh -s /usr/bin/zsh lars
# Make zsh the default for root as well
chsh -s /usr/bin/zsh
# Point /bin/sh to dash for faster scripts
ln -sfT dash /usr/bin/sh
```

### 6.6 Login to user
```bash
# Switch to your new user to finish user-scoped setup
su - lars
```

### 6.7 Install yay
```bash
# Work in /tmp so you can delete the build dir later
cd /tmp

# Clone the yay AUR helper
git clone https://aur.archlinux.org/yay.git

# Enter the newly cloned repo
cd yay

# Build and install the package
makepkg -si

# Confirm
yay --version

# Leave directory
cd
```

### 6.8 Install linux-cachyos
```bash
# Install the CachyOS kernel and matching headers via yay
yay -S linux-cachyos linux-cachyos-headers
```

### 6.9 Install and Build hyprland
```bash
# Pull down Hyprland and supporting components from the AUR
yay -S hyprland-git hyprqt6engine-git uwsm-git app2unit-git wlogout-git \
nordzy-icon-theme
```

### 6.10 Enable Waybar service
```bash
# Enable Waybar to start automatically for your user
systemctl --user enable waybar.service hyprpolkitagent.service
```

### 6.10.5 Clone repo and run install script
```bash
# Work in /tmp so you can delete the build dir later
cd /tmp

# Clone the dots
git clone https://github.com/larsoyd/dotfiles

# Enter the newly cloned repo
cd dotfiles

# Install the dots
./setup.sh

# Leave directory
cd
```

### 6.11 Exit login
```bash
# Leave the user session now that yay & dots are installed
exit
```


### 6.12 Install Rest of Packages
```bash
# Install the rest of the desktop stack in one go
pacman -S --needed \
  networkmanager reflector kitty fuzzel nautilus brightnessctl network-manager-applet \
  nm-connection-editor mako pavucontrol qt5-wayland qt6-wayland \
  pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber \
  nvidia-open-dkms nvidia-utils libva-nvidia-driver libva-utils cuda libnewt \
  terminus-font ttf-dejavu ttf-liberation noto-fonts nerd-fonts noto-fonts-cjk \
  noto-fonts-extra noto-fonts-emoji xdg-desktop-portal-hyprland \
  pacman-contrib wget 
```

### 6.13 Configure Initramfs

```bash
# Edit mkinitcpio configuration
nano /etc/mkinitcpio.conf

---

# Example for MODULES:
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)

---

# Example for HOOKS
HOOKS=(base systemd autodetect microcode modconf keyboard sd-vconsole block filesystems fsck)

# Key changes:
# - MUST use 'systemd' instead of 'udev' 
# - Use 'sd-vconsole' instead of 'keymap' and 'consolefont'
# - Remove 'kms' from HOOKS=() also if you use nvidia
# - Ensure microcode is in HOOKS=()
#
# NOTE: IF you do not remove udev and if you do not replace it with systemd,
# THEN YOUR SYSTEM WILL NOT BOOT.
# This is the only pitfall with systemd-gpt-auto-generator,
#
# It's worth doublechecking.
# Check this again if your system isn't booting post-install.

```

### 6.14 Install UKIs and Configure Bootloader

```bash
# Install systemd-boot
#
# NOTE: Remember to include `--variables=yes` flag. - Here's why:
# Starting with systemd version 257, bootctl began detecting
# environments like arch-chroot as containers...
#
# This is an intended change and without it, it silently skips
# the step of writing EFI variables to NVRAM...
#
# For non-nerds: This prevents issues where the boot entry
# might not appear in the firmware's boot menu...
#
bootctl install --esp-path=/efi --variables=yes

# Minimal cmdline with kernel option(s)
nano /etc/kernel/cmdline

# These are the only kernel flags needed for this setup
# With GPT Autoloader you do not need to specify UUIDs here
#
# rootflags add options to the root filesystem, like noatime
# noatime is a typical optimization for EXT4 systems.
# nowatchdog is also optimization. Both of them are unneeded for single use desktops.
# they are on for "over-security"/kernel default reasons only.
# many distros ship with nowatchdog and noatime, EOS for example.
#
# if you really are worried about if you need them (you probably dont) then you can
# research them independently
#
# loglevel=3 just increases verbosity in logging.
#
# zswap.compressor=lz4 switches compressor to lz4 from zstd, lz4 is considered faster
#
# /etc/kernel/cmdline
rw rootflags=noatime nowatchdog loglevel=3 zswap.compressor=lz4 zswap.enabled=1
```

#### 6.14.1 Make the ESP directory
```bash
# Make ESP directory
mkdir -p /efi/EFI/Linux
```

#### 6.14.2 Edit the mkinitcpio presets so they write UKIs to the ESP

```bash
# Update the linux-cachyos mkinitcpio preset for UKI output
nano /etc/mkinitcpio.d/linux-cachyos.preset

# Content:
ALL_kver="/boot/vmlinuz-linux-cachyos"
PRESETS=('default')

default_uki="/efi/EFI/Linux/linux-cachyos.efi"
```

#### 6.14.3 Build the UKIs / This writes kernel *.efi's into ESP/EFI/Linux/

```bash
# Build every initramfs/preset so the EFI images land on the ESP
mkinitcpio -P
```

#### 6.14.4 Configure bootloader

```bash
# write the loader
# Define loader.conf so systemd-boot knows how to behave
nano /efi/loader/loader.conf

# Add to loader
timeout 10
console-mode auto
editor no
```


### 6.15 Enable Essential Services

```bash
# Enable essential services so networking, time, and boot updates work
systemctl enable NetworkManager systemd-timesyncd systemd-boot-update.service reflector.timer
```

```bash
# Exit chroot environment
exit

# Unmount all partitions
umount -R /mnt
```

### 6.16 Shutdown

```bash
# Power off the machine to prepare for the first real boot
shutdown now

# Remove ArchISO USB from computer then boot back into new install
# Enjoy Hyprland
```
