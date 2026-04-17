{ inputs }:

pkgs: {
  niri-unstable = pkgs.callPackage ./niri.nix {
    src = inputs.niri-unstable;
  };

  xwayland-satellite-unstable = pkgs.callPackage ./xwayland-satellite.nix {
    src = inputs.xwayland-satellite-unstable;
  };
}
