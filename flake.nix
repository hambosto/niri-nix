{
  description = "A scrollable-tiling Wayland compositor.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";

    niri-unstable.url = "github:niri-wm/niri";
    niri-unstable.flake = false;

    xwayland-satellite-unstable.url = "github:Supreeeme/xwayland-satellite";
    xwayland-satellite-unstable.flake = false;
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      systems,
      ...
    }:
    let
      lib = nixpkgs.lib;
      forAllSystems = lib.genAttrs (import systems);
      kdl = import ./lib/kdl.nix { inherit lib; };
      makePackageSet = import ./pkgs { inherit inputs nixpkgs; };
    in
    {
      lib = {
        inherit kdl;
        internal = { inherit makePackageSet; };
      };

      packages = forAllSystems (system: makePackageSet nixpkgs.legacyPackages.${system});
      overlays.niri = final: _prev: makePackageSet final;
      homeModules.niri = import ./modules/home.nix {
        inherit
          inputs
          nixpkgs
          kdl
          makePackageSet
          ;
      };
      nixosModules.niri = import ./modules/nixos.nix {
        inherit inputs nixpkgs makePackageSet;
      };
    };
}
