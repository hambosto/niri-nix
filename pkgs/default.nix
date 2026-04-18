{ inputs, nixpkgs }:
pkgs: {
  niri-unstable = pkgs.callPackage ./niri.nix {
    patches = [ ./profile-release.patch ];
    src = inputs.niri-unstable;

  };

  xwayland-satellite-unstable = pkgs.callPackage ./xwayland-satellite.nix {
    src = inputs.xwayland-satellite-unstable;
  };
}
