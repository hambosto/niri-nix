A Nix flake providing the [Niri](https://github.com/niri-wm/niri) scrollable-tiling Wayland compositor, its ecosystem, and NixOS/Home Manager modules.

## Features

- **Niri** - Scrollable-tiling Wayland compositor
- **Xwayland Satellite** - Rootless Xwayland integration for any Wayland compositor
- **NixOS Module** - System-wide installation with portal configuration
- **Shell Completions** - Bash, Zsh, Fish, and Nushell completions

## Available Packages

| Package | Description |
|---------|-------------|
| `niri` | Niri compositor from git |
| `xwayland-satellite` | Xwayland satellite from git |

## NixOS Module

The module provides `programs.niri` with the following options:

- `programs.niri.enable` - Enable the Niri compositor
- `programs.niri.package` - The Niri package to use (default: `niri`)

## Credits

- [Niri](https://github.com/niri-wm/niri) - The Wayland compositor
- [Xwayland Satellite](https://github.com/Supreeeme/xwayland-satellite) - Xwayland integration
