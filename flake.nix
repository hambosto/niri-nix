{
  description = "A scrollable-tiling Wayland compositor.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    niri.url = "github:niri-wm/niri";
    niri.flake = false;

    xwayland-satellite.url = "github:Supreeeme/xwayland-satellite";
    xwayland-satellite.flake = false;
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
      forEachSystem =
        perSystem:
        lib.genAttrs systems (
          system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
          in
          perSystem { inherit pkgs system; }
        );
    in
    {
      packages = forEachSystem (
        { pkgs, ... }:
        {
          niri = pkgs.callPackage ./packages/niri.nix {
            src = inputs.niri;
          };

          xwayland-satellite = pkgs.callPackage ./packages/xwayland-satellite.nix {
            src = inputs.xwayland-satellite;
          };
        }
      );

      overlays.default = final: prev: {
        niri = final.callPackage ./packages/niri.nix {
          src = inputs.niri;
        };

        xwayland-satellite = final.callPackage ./packages/xwayland-satellite.nix {
          src = inputs.xwayland-satellite;
        };
      };

      nixosModules.default = { lib, pkgs, ... }: {
        imports = [ ./modules/nixos-module.nix ];
        programs.niri.package = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.niri;
      };

      homeManagerModules.default = { lib, pkgs, ... }: {
        imports = [ ./modules/home-module.nix ];
        programs.niri.package = lib.mkDefault self.packages.${pkgs.stdenv.hostPlatform.system}.niri;
      };
    };
}
