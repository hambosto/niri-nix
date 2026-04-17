{ kdl, makePackageSet }:
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.niri;
  validatedConfig = import ../lib/validation.nix;
  finalConfig =
    if cfg.settings == null then
      null
    else if builtins.isString cfg.settings then
      cfg.settings
    else
      kdl.serialize.nodes cfg.settings;
in
{
  options.programs.niri = {
    package = lib.mkOption {
      type = lib.types.package;
      default = (makePackageSet pkgs).niri-unstable;
      description = "The niri package to use.";
    };

    settings = lib.mkOption {
      type = lib.types.nullOr (lib.types.either lib.types.str kdl.types.kdl-document);
      default = null;
      description = ''
        Niri configuration.

        - `null`   – no config file is generated.
        - `string` – used verbatim as the config file contents.
        - KDL document attrset – serialised via the kdl library before use.

        In all non-null cases the config is validated with `niri validate`
        at build time.
      '';
    };
  };

  config.xdg.configFile.niri-config = lib.mkIf (cfg.settings != null) {
    enable = true;
    target = "niri/config.kdl";
    source = validatedConfig {
      inherit pkgs;
      package = cfg.package;
      config = finalConfig;
    };
  };
}
