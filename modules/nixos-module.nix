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
    enable = lib.mkEnableOption "niri";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      description = "The niri package to use.";
    };

    useNautilus = lib.mkEnableOption "Nautilus as file-chooser for xdg-desktop-portal-gnome" // {
      default = true;
    };

  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    services.displayManager.sessionPackages = [ cfg.package ];
    services.dbus.packages = lib.mkIf cfg.useNautilus [ pkgs.nautilus ];

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

    xdg.portal = {
      enable = true;
      config.niri = {
        default = [
          "gnome"
          "gtk"
        ];
        "org.freedesktop.impl.portal.Access" = "gtk";
        "org.freedesktop.impl.portal.FileChooser" = lib.mkIf (!cfg.useNautilus) "gtk";
        "org.freedesktop.impl.portal.Notification" = "gtk";
        "org.freedesktop.impl.portal.Secret" = "gnome-keyring";
      };
      extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
    };
  };
}
