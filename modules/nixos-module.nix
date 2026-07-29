{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.niri;
in
{
  disabledModules = [ "programs/wayland/niri.nix" ];

  options.programs.niri = {
    enable = lib.mkEnableOption "Niri, a scrollable-tiling Wayland compositor";
    package = lib.mkPackageOption pkgs "niri" { };

    useNautilus = lib.mkEnableOption "Nautilus as file-chooser for xdg-desktop-portal-gnome" // {
      default = true;
    };

    useGnomeKeyring = lib.mkEnableOption "gnome-keyring as the XDG secrets portal backend" // {
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    services.displayManager.sessionPackages = [ cfg.package ];

    # Required for xdg-desktop-portal-gnome's FileChooser to work properly
    services.dbus.packages = lib.mkIf cfg.useNautilus [ pkgs.nautilus ];

    # Recommended by upstream
    # https://niri-wm.github.io/niri/Important-Software.html
    services.gnome.gnome-keyring.enable = lib.mkIf cfg.useGnomeKeyring true;

    systemd.packages = [ cfg.package ];

    # Restarting the compositor kills the graphical session; same
    # treatment as the display-manager modules.
    systemd.user.services.niri = {
      restartIfChanged = false;
      # Defining the unit here generates a drop-in; without this it
      # would carry the NixOS default Environment="PATH=coreutils:…",
      # clobbering the PATH that niri-session imported into the user
      # manager and breaking spawn actions that rely on it.
      enableDefaultPath = false;
    };

    xdg.portal = lib.mkMerge [
      {
        enable = lib.mkDefault true;
        extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
      }
      (lib.mkIf cfg.useNautilus {
        configPackages = [ cfg.package ];
      })
      (lib.mkIf (!cfg.useNautilus) {
        config.niri = {
          default = [
            "gnome"
            "gtk"
          ];
          "org.freedesktop.impl.portal.Access" = "gtk";
          "org.freedesktop.impl.portal.FileChooser" = "gtk";
          "org.freedesktop.impl.portal.Notification" = "gtk";
          "org.freedesktop.impl.portal.Secret" = lib.mkIf cfg.useGnomeKeyring "gnome-keyring";
        };
      })
    ];
  };
}
