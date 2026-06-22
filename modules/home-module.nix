{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.niri;
  hm = fetchTarball {
    url = "https://github.com/nix-community/home-manager/archive/6716d811e5f6a0b9f014af3dcdfb9571e383e8cc.tar.gz";
    sha256 = "1c5xlhvn28770rlrq1q333s25696b83xbg3s7vp165jypz8gbaml";
  };
  toKDL = (import "${hm}/modules/lib/generators.nix" { inherit lib; }).toKDL { };
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
        types.submodule {
          freeformType = valueType;
        };
      default = { };
      description = ''
        KDL configuration for Niri written in Nix.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile = {
      "niri/config.kdl" = lib.mkIf (cfg.settings != { }) {
        source =
          let
            configFile = pkgs.writeText "config.kdl" (toKDL cfg.settings);
          in
          pkgs.runCommand "config.kdl" { } ''
            ${lib.getExe cfg.package} validate -c ${configFile}
            cp ${configFile} $out
          '';
      };
    };
  };
}
