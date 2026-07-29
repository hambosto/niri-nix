{
  description = "A scrollable-tiling Wayland compositor.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    rust-overlay.url = "github:oxalica/rust-overlay/stable";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";

    niri.url = "github:niri-wm/niri";
    niri.flake = false;

    xwayland-satellite.url = "github:Supreeeme/xwayland-satellite";
    xwayland-satellite.flake = false;
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      rust-overlay,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      mkRustPlatform =
        pkgs:
        pkgs.makeRustPlatform {
          cargo = pkgs.rust-bin.stable.latest.default;
          rustc = pkgs.rust-bin.stable.latest.default;
        };

      forEachSystem =
        perSystem:
        lib.genAttrs systems (
          system:
          let
            pkgs = import nixpkgs {
              inherit system;
              overlays = [ rust-overlay.overlays.default ];
            };
            rustPlatform = mkRustPlatform pkgs;
          in
          perSystem { inherit pkgs system rustPlatform; }
        );
    in
    {
      packages = forEachSystem (
        { pkgs, rustPlatform, ... }:
        {
          niri = pkgs.callPackage ./packages/niri.nix {
            src = inputs.niri;
            inherit rustPlatform;
          };

          xwayland-satellite = pkgs.callPackage ./packages/xwayland-satellite.nix {
            src = inputs.xwayland-satellite;
            inherit rustPlatform;
          };
        }
      );

      overlays.default = final: prev: {
        niri = final.callPackage ./packages/niri.nix {
          src = inputs.niri;
          rustPlatform = mkRustPlatform final;
        };

        xwayland-satellite = final.callPackage ./packages/xwayland-satellite.nix {
          src = inputs.xwayland-satellite;
          rustPlatform = mkRustPlatform final;
        };
      };

      homeManagerModules.default = import ./modules/home-module.nix;
      nixosModules.default = import ./modules/nixos-module.nix;
    };
}
