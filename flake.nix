{
  description = "A scrollable-tiling Wayland compositor.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    rust-overlay = {
      url = "github:oxalica/rust-overlay/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri = {
      url = "github:niri-wm/niri";
      flake = false;
    };

    xwayland-satellite = {
      url = "github:Supreeeme/xwayland-satellite";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      rust-overlay,
      niri,
      xwayland-satellite,
    }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forEachSystem = f: lib.genAttrs systems f;

      mkPackages =
        pkgs:
        let
          rustPkgs = pkgs.extend rust-overlay.overlays.default;
          rustPlatform = rustPkgs.makeRustPlatform {
            cargo = rustPkgs.rust-bin.stable.latest.default;
            rustc = rustPkgs.rust-bin.stable.latest.default;
          };
        in
        {
          niri = pkgs.callPackage ./packages/niri.nix {
            inherit rustPlatform;
            src = niri;
          };

          xwayland-satellite = pkgs.callPackage ./packages/xwayland-satellite.nix {
            inherit rustPlatform;
            src = xwayland-satellite;
          };
        };
    in
    {
      packages = forEachSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        mkPackages pkgs
      );

      overlays.default = final: prev: mkPackages final;
      homeManagerModules.default = import ./modules/home-module.nix;
      nixosModules.default = import ./modules/nixos-module.nix;
    };
}
