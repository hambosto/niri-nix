A Nix flake providing the [Niri](https://github.com/niri-wm/niri) scrollable-tiling Wayland compositor, its ecosystem, and NixOS/Home Manager modules.

## Features

- **Niri** - Scrollable-tiling Wayland compositor
- **XDG Desktop Portal Generic** - Generic portal backend for ScreenCast and file chooser
- **Xwayland Satellite** - Rootless Xwayland integration for any Wayland compositor
- **NixOS Module** - System-wide installation with portal configuration
- **Shell Completions** - Bash, Zsh, Fish, and Nushell completions

## Available Packages

| Package | Description |
|---------|-------------|
| `niri` | Niri compositor from git |
| `xdg-desktop-portal-generic` | Generic XDG Desktop Portal backend from git |
| `xwayland-satellite` | Xwayland satellite from git |

## NixOS Module

The module provides `programs.niri` with the following options:

- `programs.niri.enable` - Enable the Niri compositor
- `programs.niri.package` - The Niri package to use (default: `niri`)
- `programs.niri.portalPackage` - The portal package to use (default: `xdg-desktop-portal-generic`)
- `programs.niri.useNautilus` - Use Nautilus as file-chooser (default: `true`)

## Credits

- [Niri](https://github.com/niri-wm/niri) - The Wayland compositor
- [XDG Desktop Portal Generic](https://github.com/lamco-admin/xdg-desktop-portal-generic) - Generic portal backend
- [Xwayland Satellite](https://github.com/Supreeeme/xwayland-satellite) - Xwayland integration
