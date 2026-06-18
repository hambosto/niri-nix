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
      inherit (lib) genAttrs;
      kdl = import ./kdl.nix { inherit lib; };

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forEachSystem =
        perSystem:
        genAttrs systems (
          system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
          in
          perSystem { inherit pkgs system; }
        );

      fmtDate =
        raw:
        let
          year = builtins.substring 0 4 raw;
          month = builtins.substring 4 2 raw;
          day = builtins.substring 6 2 raw;
        in
        "${year}-${month}-${day}";

      mkNiri =
        pkgs: src:
        pkgs.rustPlatform.buildRustPackage {
          pname = "niri";
          version = "unstable-${fmtDate src.lastModifiedDate}-${src.shortRev}";

          inherit src;

          cargoLock.lockFile = "${src}/Cargo.lock";
          cargoLock.allowBuiltinFetchGit = true;

          nativeBuildInputs = with pkgs; [
            autoPatchelfHook
            installShellFiles
            pkg-config
            rustPlatform.bindgenHook
          ];

          buildInputs = with pkgs; [
            libdisplay-info
            libgbm
            libglvnd
            libinput
            libxkbcommon
            pango
            pipewire
            seatd
            systemdLibs
            wayland
          ];

          runtimeDependencies = with pkgs; [
            libglvnd
            wayland
          ];

          buildNoDefaultFeatures = true;
          buildFeatures = [
            "dbus"
            "xdp-gnome-screencast"
            "systemd"
          ];

          doCheck = false;

          patches = [ ./patches/niri-profile.patch ];

          NIRI_BUILD_VERSION_STRING = "unstable ${fmtDate src.lastModifiedDate} (commit ${src.rev})";

          passthru.providedSessions = [ "niri" ];

          postPatch = ''
            patchShebangs resources/niri-session
            substituteInPlace resources/niri.service \
              --replace-fail "ExecStart=niri" "ExecStart=$out/bin/niri"
          '';

          postInstall = ''
            install -Dm0755 resources/niri-session -t $out/bin
            install -Dm0644 resources/niri.desktop -t $out/share/wayland-sessions
            install -Dm0644 resources/niri-portals.conf -t $out/share/xdg-desktop-portal
            install -Dm0644 resources/niri.service -t $out/lib/systemd/user
            install -Dm0644 resources/niri-shutdown.target -t $out/lib/systemd/user

            installShellCompletion --cmd niri \
              --bash <($out/bin/niri completions bash) \
              --zsh <($out/bin/niri completions zsh) \
              --fish <($out/bin/niri completions fish) \
              --nushell <($out/bin/niri completions nushell)
          '';

          meta = {
            description = "Scrollable-tiling Wayland compositor";
            homepage = "https://github.com/YaLTeR/niri";
            license = lib.licenses.gpl3Only;
            mainProgram = "niri";
            platforms = lib.platforms.linux;
          };
        };

      mkXwaylandSatellite =
        pkgs: src:
        pkgs.rustPlatform.buildRustPackage {
          pname = "xwayland-satellite";
          version = "unstable-${fmtDate src.lastModifiedDate}-${src.shortRev}";

          inherit src;

          cargoLock.lockFile = "${src}/Cargo.lock";
          cargoLock.allowBuiltinFetchGit = true;

          nativeBuildInputs = with pkgs; [
            makeBinaryWrapper
            pkg-config
            rustPlatform.bindgenHook
          ];

          buildInputs = with pkgs; [
            libxcb
            xcb-util-cursor
          ];

          buildNoDefaultFeatures = true;
          buildFeatures = [ "systemd" ];

          doCheck = false;

          patches = [ ./patches/xwayland-profile.patch ];

          VERGEN_GIT_DESCRIBE = "unstable ${fmtDate src.lastModifiedDate} (commit ${src.rev})";

          postInstall = ''
            wrapProgram $out/bin/xwayland-satellite \
              --prefix PATH : "${lib.makeBinPath [ pkgs.xwayland ]}"
            install -Dm0644 resources/xwayland-satellite.service -t $out/lib/systemd/user
          '';

          postFixup = ''
            substituteInPlace $out/lib/systemd/user/xwayland-satellite.service \
              --replace-fail /usr/local/bin $out/bin
          '';

          meta = {
            description = "Rootless Xwayland integration to any Wayland compositor implementing xdg_wm_base";
            homepage = "https://github.com/Supreeeme/xwayland-satellite";
            license = lib.licenses.mpl20;
            mainProgram = "xwayland-satellite";
            platforms = lib.platforms.linux;
          };
        };

      nixosModule =
        {
          config,
          pkgs,
          lib,
          ...
        }:
        let
          cfg = config.programs.niri;
        in
        {
          disabledModules = [ "programs/wayland/niri.nix" ];

          options.programs.niri = {
            enable = lib.mkEnableOption "niri";

            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
              description = "The niri package to use.";
            };
          };

          config = lib.mkIf cfg.enable {
            environment.systemPackages = [
              cfg.package
              pkgs.nautilus
            ];

            services.displayManager.sessionPackages = [ cfg.package ];
            services.dbus.packages = [ pkgs.nautilus ];

            xdg.portal = {
              enable = true;
              configPackages = [ cfg.package ];
              extraPortals = lib.mkIf (
                !cfg.package.cargoBuildNoDefaultFeatures
                || builtins.elem "xdp-gnome-screencast" cfg.package.cargoBuildFeatures
              ) [ pkgs.xdg-desktop-portal-gnome ];
            };
          };
        };

      homeModule =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.programs.niri;
          inherit (kdl) types serialize;
        in
        {
          options.programs.niri = {
            enable = lib.mkEnableOption "niri";

            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable;
              description = "The niri package to use.";
            };

            settings = lib.mkOption {
              type = types.kdl-document;
              default = [ ];
              description = ''
                Niri configuration as a KDL document attrset, serialised via
                the kdl library and validated with `niri validate` at build time.
              '';
            };
          };

          config = lib.mkIf cfg.enable {
            xdg.configFile."niri/config.kdl" = lib.mkIf (cfg.settings != null) {
              source =
                let
                  configFile = pkgs.writeText "config.kdl" (serialize.nodes cfg.settings);
                in
                pkgs.runCommand "config.kdl" { } ''
                  ${lib.getExe cfg.package} validate -c ${configFile}
                  cp ${configFile} $out
                '';
            };
          };
        };
    in
    {
      packages = forEachSystem (
        { pkgs, ... }: {
          niri-unstable = mkNiri pkgs inputs.niri-unstable;
          xwayland-satellite-unstable = mkXwaylandSatellite pkgs inputs.xwayland-satellite-unstable;
        }
      );

      overlays.default = final: _prev: {
        niri-unstable = mkNiri final inputs.niri-unstable;
        xwayland-satellite-unstable = mkXwaylandSatellite final inputs.xwayland-satellite-unstable;
      };

      homeManagerModules.default = homeModule;
      nixosModules.default = nixosModule;

      lib = { inherit kdl; };
    };
}
