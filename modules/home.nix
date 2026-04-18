{ self, kdl }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.niri;
  inherit (kdl) types serialize;
in
{
  options.programs.niri = {
    enable = lib.mkEnableOption "niri";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
      description = "The niri package to use.";
    };

    settings = lib.mkOption {
      type = types.kdlDocument;
      default = [ ];
      description = ''
        Niri configuration as a KDL document attrset, serialised via
        the kdl library and validated with `niri validate` at build time.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."niri/config.kdl" = lib.mkIf (cfg.settings != [ ]) {
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
  };
}
