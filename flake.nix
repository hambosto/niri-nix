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
    {
      self,
      nixpkgs,
      systems,
      ...
    }:
    let
      forAllSystems = f: nixpkgs.lib.genAttrs (import systems) f;
      pkgsFor = system: nixpkgs.legacyPackages.${system};
    in
    {
      packages = forAllSystems (system: {
        niri-unstable = (pkgsFor system).callPackage ./pkgs/niri.nix { };
        xwayland-satellite-unstable = (pkgsFor system).callPackage ./pkgs/xwayland-satellite.nix { };
      });

      overlays.niri = final: _prev: {
        niri-unstable = final.callPackage ./pkgs/niri.nix { };
        xwayland-satellite-unstable = final.callPackage ./pkgs/xwayland-satellite.nix { };
      };

      homeModules.niri = import ./modules/home.nix { };
      nixosModules.niri = import ./modules/nixos.nix { };
    };
}
