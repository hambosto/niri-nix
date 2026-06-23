{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.niri;
  toKDL = lib.hm.generators.toKDL { };

  validatedConfig =
    package: settings:
    pkgs.runCommand "config.kdl"
      {
        passAsFile = [ "kdl" ];
        kdl = toKDL settings;
      }
      ''
        ${lib.getExe package} validate -c "$kdlPath"
        cp "$kdlPath" "$out"
      '';
in
{
  options.programs.niri = {
    enable = lib.mkEnableOption "niri";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      description = "The niri package to use.";
    };

    settings = lib.mkOption {
      type =
        with lib.types;
        let
          valueType =
            nullOr (oneOf [
              bool
              int
              float
              str
              path
              (attrsOf valueType)
              (listOf valueType)
            ])
            // {
              description = "Niri configuration value";
            };
        in
        submodule { freeformType = valueType; };
      default = { };
      description = "KDL configuration for niri written in Nix.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.package != null;
        message = "programs.niri.package must not be null when programs.niri.enable is true.";
      }
    ];

    xdg.configFile."niri/config.kdl" = lib.mkIf (cfg.settings != { }) {
      source = validatedConfig cfg.package cfg.settings;
    };
  };
}
