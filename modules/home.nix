{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.niri;
  inherit (inputs.niri-utils.lib.kdl) types serialize;
in
{
  options.programs.niri = {
    enable = lib.mkEnableOption "niri";
    package = lib.mkOption {
      type = lib.types.package;
      description = "The niri package to use.";
    };

    settings = lib.mkOption {
      type = types.kdl-document;
      default = { };
      description = ''
        Niri configuration.

        A KDL document attrset that is serialised via the kdl library
        and validated with `niri validate` at build time.
      '';
    };
  };

  config.xdg.configFile.config = lib.mkIf (cfg.enable && cfg.settings != { }) {
    enable = true;
    target = "niri/config.kdl";
    source =
      pkgs.runCommand "config.kdl"
        {
          config = serialize.nodes cfg.settings;
          passAsFile = [ "config" ];
          buildInputs = [ cfg.package ];
        }
        ''
          niri validate -c $configPath
          cp $configPath $out
        '';
  };
}
