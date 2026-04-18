{
  description = "A scrollable-tiling Wayland compositor.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";

    niri-unstable = {
      url = "github:niri-wm/niri";
      flake = false;
    };

    xwayland-satellite-unstable = {
      url = "github:Supreeeme/xwayland-satellite";
      flake = false;
    };
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
      lib = nixpkgs.lib;
      eachSystem = lib.genAttrs (import systems);
      pkgsFor = system: nixpkgs.legacyPackages.${system};
      kdl = import ./kdl.nix { inherit lib; };

      overlay = final: _prev: {
        niri-unstable = final.callPackage ./pkgs/niri.nix { src = niri-unstable; };
        xwayland-satellite-unstable = final.callPackage ./pkgs/xwayland-satellite.nix {
          src = xwayland-satellite-unstable;
        };
      };

    in
    {
      packages = eachSystem (
        system:
        let
          pkgs = (pkgsFor system).extend overlay;
        in
        {
          inherit (pkgs) niri-unstable xwayland-satellite-unstable;
        }
      );

      overlays.default = overlay;
      homeModules.niri = import ./modules/home.nix { inherit self kdl; };
      nixosModules.niri = import ./modules/nixos.nix { inherit self; };

      lib = { inherit kdl; };
    };
}
