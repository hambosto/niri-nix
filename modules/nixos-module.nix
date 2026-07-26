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
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    services.displayManager.sessionPackages = [ cfg.package ];
    services.dbus.packages = [ pkgs.nautilus ];

    systemd.packages = [ cfg.package ];

    systemd.user.services.niri = {
      restartIfChanged = false;
      enableDefaultPath = false;
    };

    xdg.portal = {
      enable = true;
      configPackages = [ cfg.package ];
      extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
    };
  };
}
