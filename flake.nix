{
  description = "A scrollable-tiling Wayland compositor.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
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
    inputs@{
      self,
      nixpkgs,
      ...
    }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      mkPkgs =
        system:
        import nixpkgs {
          inherit system;
          overlays = [ inputs.rust-overlay.overlays.default ];
        };

      mkPackages =
        pkgs:
        let
          toolchain = pkgs.rust-bin.stable.latest.default;
          rustPlatform = pkgs.makeRustPlatform {
            cargo = toolchain;
            rustc = toolchain;
          };
        in
        {
          niri = pkgs.callPackage ./packages/niri.nix {
            src = inputs.niri;
            inherit rustPlatform;
          };

          xwayland-satellite = pkgs.callPackage ./packages/xwayland-satellite.nix {
            src = inputs.xwayland-satellite;
            inherit rustPlatform;
          };
        };
    in
    {
      packages = lib.genAttrs systems (system: mkPackages (mkPkgs system));
      overlays.default = final: prev: mkPackages final;

      homeManagerModules.default = import ./modules/home-module.nix;
      nixosModules.default = import ./modules/nixos-module.nix;
    };
}
