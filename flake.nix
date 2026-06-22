{
  description = "A scrollable-tiling Wayland compositor.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    niri-unstable.url = "github:niri-wm/niri";
    niri-unstable.flake = false;

    xwayland-satellite-unstable.url = "github:Supreeeme/xwayland-satellite";
    xwayland-satellite-unstable.flake = false;
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
          niri-unstable = pkgs.callPackage ./packages/niri.nix {
            src = inputs.niri-unstable;
          };
          xwayland-satellite-unstable = pkgs.callPackage ./packages/xwayland-satellite.nix {
            src = inputs.xwayland-satellite-unstable;
          };
        }
      );

      overlays.default = final: prev: {
        niri-unstable = final.callPackage ./packages/niri.nix {
          src = inputs.niri-unstable;
        };
        xwayland-satellite-unstable = final.callPackage ./packages/xwayland-satellite.nix {
          src = inputs.xwayland-satellite-unstable;
        };
      };

      nixosModules.default = { lib, pkgs, ... }: {
        imports = [ ./modules/nixos-module.nix ];
        programs.niri.package =
          lib.mkDefault
            self.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
      };

      homeManagerModules.default = { lib, pkgs, ... }: {
        imports = [ ./modules/home-module.nix ];
        programs.niri.package =
          lib.mkDefault
            self.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
      };
    };
}
