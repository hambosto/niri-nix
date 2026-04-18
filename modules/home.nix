{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.niri;
in
{
  options.programs.niri = lib.mkOption {
    type = lib.types.submodule {
      options = {
        package = lib.mkOption {
          type = lib.types.package;
          description = "The niri package to use.";
        };

        settings = lib.mkOption {
          type = inputs.niri-utils.lib.kdl.types.kdl-document;
          default = { };
          description = ''
            Niri configuration.

            A KDL document attrset that is serialised via the kdl library
            and validated with `niri validate` at build time.
          '';
        };
      };
    };
  };

  config.xdg.configFile.config = lib.mkIf (cfg.settings != { }) {
    enable = true;
    target = "niri/config.kdl";
    source =
      pkgs.runCommand "config.kdl"
        {
          config = inputs.niri-utils.lib.kdl.serialize.nodes cfg.settings;
          passAsFile = [ "config" ];
          buildInputs = [ cfg.package ];
        }
        ''
          niri validate -c $configPath
          cp $configPath $out
        '';
  };
}
