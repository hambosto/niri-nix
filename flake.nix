{
  description = "A scrollable-tiling Wayland compositor.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
    niri-utils = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.niri-unstable.follows = "";
      inputs.xwayland-satellite-unstable.follows = "";
      inputs.niri-stable.follows = "";
      inputs.xwayland-satellite-stable.follows = "";
      inputs.nixpkgs-stable.follows = "";
    };

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
      niri-unstable,
      xwayland-satellite-unstable,
      ...
    }:
    let
      forAllSystems = f: nixpkgs.lib.genAttrs (import systems) f;
      pkgsFor = system: nixpkgs.legacyPackages.${system};
    in
    {
      packages = forAllSystems (system: {
        niri-unstable = (pkgsFor system).callPackage ./pkgs/niri.nix { src = niri-unstable; };
        xwayland-satellite-unstable = (pkgsFor system).callPackage ./pkgs/xwayland-satellite.nix {
          src = xwayland-satellite-unstable;
        };
      });

      overlays.niri = final: _prev: {
        niri-unstable = final.callPackage ./pkgs/niri.nix { src = niri-unstable; };
        xwayland-satellite-unstable = final.callPackage ./pkgs/xwayland-satellite.nix {
          src = xwayland-satellite-unstable;
        };
      };

      homeModules.niri = import ./modules/home.nix;
      nixosModules.niri = import ./modules/nixos.nix;
    };
}
