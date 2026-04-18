{ inputs, nixpkgs }:
pkgs: {
  niri-unstable = pkgs.callPackage ./niri.nix {
    patches = [ ./niri-release.patch ];
    src = inputs.niri-unstable;

  };

  xwayland-satellite-unstable = pkgs.callPackage ./xwayland-satellite.nix {
    patches = [ ./xwayland-release.patch ];
    src = inputs.xwayland-satellite-unstable;
  };
}
