{
  inputs,
  nixpkgs,
  makePackageSet,
}:
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.niri;
  hasScreencast =
    !cfg.package.cargoBuildNoDefaultFeatures
    || builtins.elem "xdp-gnome-screencast" cfg.package.cargoBuildFeatures;
in
{
  disabledModules = [ "programs/wayland/niri.nix" ];

  options.programs.niri = {
    enable = lib.mkEnableOption "niri";

    package = lib.mkOption {
      type = lib.types.package;
      default = (makePackageSet pkgs).niri-unstable;
      description = "The niri package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
      pkgs.nautilus
    ];

    services.displayManager.sessionPackages = [ cfg.package ];
    services.dbus.packages = [ pkgs.nautilus ];

    xdg.portal = {
      enable = true;
      configPackages = [ cfg.package ];
      extraPortals = lib.mkIf (
        !cfg.package.cargoBuildNoDefaultFeatures
        || builtins.elem "xdp-gnome-screencast" cfg.package.cargoBuildFeatures
      ) [ pkgs.xdg-desktop-portal-gnome ];
    };
  };
}
