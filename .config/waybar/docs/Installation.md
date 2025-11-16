Which Distro are you using?

- [Alpine](#alpine)
- [Arch](#arch)
- [Fedora](#fedora)
- [Fedora Silverblue](#fedora-silverblue)
- [FreeBSD](#freebsd)
- [Gentoo](#gentoo)
- [openSUSE](#opensuse)
- [NixOS](#nixos)
- [Ubuntu and Debian](#ubuntu-and-debian)
- [Void](#void)
- [Other](#other)

## Alpine

Since Alpine v3.11, you can install the [`waybar` package](https://pkgs.alpinelinux.org/packages?name=waybar&branch=edge&repo=&arch=&maintainer=) from the `community` repository. As a superuser, type:

```sh
apk add waybar
```

## Arch

On Arch, you can simply install [waybar](https://www.archlinux.org/packages/extra/x86_64/waybar/) from extra. You can also install [waybar-git](https://aur.archlinux.org/packages/waybar-git/) from the AUR.  

Another option is to use [Omarchy](https://github.com/basecamp/omarchy) an opinionated Arch-based distribution that already ships with a preconfigured Waybar and Hyprland setup. This approach can save time if you prefer to start with ready-made defaults instead of manually configuring Waybar from scratch.

## Fedora

On Fedora, Waybar is also in the official repositories. Install with `dnf install waybar`.

### Fedora Silverblue

Fedora Silverblue uses an immutable ostree-based filesystem, meaning ordinarily you would not install packages directly. There are three main approaches to installing Waybar.

#### Package layering (easiest)
You can install Waybar from the official repositories, using [package layering](https://docs.fedoraproject.org/en-US/fedora-silverblue/getting-started/#package-layering) with:
```sh
rpm-ostree install waybar
```
This functions similarly to packages installed with `dnf` and requires a reboot to take effect. `rpm-ostree update` will work as normal. 

#### Flatpak
[Flatpak](https://flatpak.org/) is the usual approach to installing software on Silverblue. There are no official Flatpak packages for Waybar at this time.

#### Customised ostree image
A customised ostree image could be prepared already including Waybar. You can do this by modifying [workstation-ostree-config](https://pagure.io/workstation-ostree-config). Guidance is available [here](https://discussion.fedoraproject.org/t/minimal-or-custom-silverblue-ostree-images/1574).
## Gentoo

On Gentoo, the package is in the official repositories. Install with `emerge -a waybar`. Note that all versions are currently unstable, so you will have to accept keywords for it.

## FreeBSD
You may also need to run `pkg install pavucontrol` for volume control if not yet installed. 
```sh
pkg install waybar
```

## openSUSE

On openSUSE, Waybar is in the official repositories. Install with `zypper in waybar`. See [devel project](https://build.opensuse.org/package/show/X11:Wayland/waybar).

## NixOS

On NixOS, you can try out Waybar with: `nix-shell -p waybar`, then run `waybar` once you are inside the shell.

Alternatively you can install it directly as a flake by adding this to your `flake.nix`:
``` nix
{
    inputs = {
        nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
        waybar.url = "github:Alexays/Waybar/master";
        # Your other inputs here
    };
    outputs = {self, ...}@inputs:{
    nixosConfigurations.YourHostHere = nixpkgs-unstable.lib.nixosSystem {
        # Your other configs here
        modules = [
            # Define custom `waybar_git` package here
            ({ pkgs, ... }:{
                nixpkgs.overlays = [
                    (_: _: { waybar_git = inputs.waybar.packages.${pkgs.stdenv.hostPlatform.system}.waybar; })
                ];
            })
            # Your other modules here
        ];
    };};
}
```

You can then reference `pkgs.waybar_git` anywhere else you want to use it instead of `pkgs.waybar`.

For example in home manager:
``` nix
home-manager.users.YourUserNameHere = { config, pkgs, ...}: {
    programs.waybar = {
        enable = true;
        package = pkgs.waybar_git;
    };
}
```

#### Note:
You don't have to use the default: `waybar.url = "github:Alexays/Waybar/master"`, you can use your own fork such as `waybar.url = "github:yuannan/Waybar/master"`, if you want to apply your own patches.

## Ubuntu and Debian

On Ubuntu, since version 20.04 LTS ("Focal Fossa"), Waybar is available as `waybar` in `universe`. Install with `apt-get install waybar`. See the [Ubuntu Packages page](https://packages.ubuntu.com/search?keywords=waybar&searchon=names&suite=all&section=all).

The required fonts have been available as packages since 22.04 LTS ("Jammy Jellyfish"), use `apt-get install fonts-font-awesome fonts-fork-awesome`.

The same packages are available in Debian since 1.2.0 ("bookworm").

## Void

On Void, the package is available as `Waybar`. Install with `xbps-install -S Waybar`.

## Other

To build and install Waybar just run:

```sh
git clone https://github.com/Alexays/Waybar && cd Waybar && sudo make install
```

-----

## How to use with Sway?

First, ensure you have the `otf-font-awesome` package installed. These are free fonts provided by Fonts Awesome and commonly used in Waybar configurations. You can also download the OTF fonts package from [this link](https://fontawesome.com/how-to-use/on-the-desktop/setup/getting-started).                                                                                           

You can use Waybar by defining in your Sway config file:
```
bar swaybar_command waybar
```

or at the end of your sway config file

```
exec waybar
```