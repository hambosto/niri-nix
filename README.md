A Nix flake providing the [Niri](https://github.com/niri-wm/niri) scrollable-tiling Wayland compositor, its ecosystem, and NixOS/Home Manager modules.

My Niri flake rewrite based on [sodiboo/niri-flake](https://github.com/sodiboo/niri-flake), tailored to match my personal needs.

## Features

- **Niri** - Scrollable-tiling Wayland compositor
- **Xwayland Satellite** - Rootless Xwayland integration for any Wayland compositor
- **NixOS Module** - System-wide installation
- **Shell Completions** - Bash, Zsh, Fish, and Nushell completions

## Available Packages

| Package | Description |
|---------|-------------|
| `niri-unstable` | Niri compositor from git (unstable) |
| `xwayland-satellite-unstable` | Xwayland satellite from git (unstable) |

## Credits

- [Niri](https://github.com/niri-wm/niri) - The Wayland compositor
- [sodiboo/niri-flake](https://github.com/sodiboo/niri-flake) - Original flake this is based on
- [Xwayland Satellite](https://github.com/Supreeeme/xwayland-satellite) - Xwayland integration
