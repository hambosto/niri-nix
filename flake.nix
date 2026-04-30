{
  description = "A scrollable-tiling Wayland compositor.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      kdl = import ./kdl.nix { inherit lib; };
      forAllSystems = f: nixpkgs.lib.genAttrs (import systems) f;
      pkgsFor = system: nixpkgs.legacyPackages.${system};
      fmtDate =
        raw:
        let
          year = builtins.substring 0 4 raw;
          month = builtins.substring 4 2 raw;
          day = builtins.substring 6 2 raw;
        in
        "${year}-${month}-${day}";

      mkNiri =
        pkgs:
        pkgs.rustPlatform.buildRustPackage rec {
          pname = "niri";
          version = "unstable-${fmtDate self.lastModifiedDate}-${builtins.substring 0 7 (src.rev)}";

          src = pkgs.fetchFromGitHub {
            owner = "niri-wm";
            repo = "niri";
            rev = "719255ac358304b96ac951ee1bfce1f0299202bd";
            hash = "sha256-1uyLRlGAFAecxyevBQ9/LZQjD6cwdcqECJBIWVIhlXE=";
          };

          cargoHash = "sha256-JLInwRj8WqpgaVQDFg+2MT6+7hdqJHhWOSd/3WKsmSM=";

          nativeBuildInputs = with pkgs; [
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

          buildNoDefaultFeatures = true;
          buildFeatures = [
            "dbus"
            "xdp-gnome-screencast"
            "systemd"
          ];

          doCheck = false;

          patches = [
            ./00001-niri-profile.patch
            ./00002-niri-environment.patch
          ];

          RUSTFLAGS = [
            "-C link-arg=-Wl,--push-state,--no-as-needed"
            "-C link-arg=-lEGL"
            "-C link-arg=-lwayland-client"
            "-C link-arg=-Wl,--pop-state"
          ];

          NIRI_BUILD_VERSION_STRING = "unstable ${fmtDate self.lastModifiedDate} (commit ${src.rev})";

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
        pkgs:
        pkgs.rustPlatform.buildRustPackage rec {
          pname = "xwayland-satellite";
          version = "unstable-${fmtDate self.lastModifiedDate}-${builtins.substring 0 7 (src.rev)}";

          src = pkgs.fetchFromGitHub {
            owner = "Supreeeme";
            repo = "xwayland-satellite";
            rev = "bc47ef59501556fc2584155ddef76493752dd727";
            hash = "sha256-V8+DrPOp940J6icERAaGuDQTKyEyZzFuRw363XwDKXg=";
          };

          cargoHash = "sha256-3rvOrgABu+GapZb48OafObJbF8NjJoLw3YzRu+LHhNE=";

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

          patches = [ ./00001-xwayland-profile.patch ];

          VERGEN_GIT_DESCRIBE = "unstable ${fmtDate self.lastModifiedDate} (commit ${src.rev})";

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

          config.xdg.configFile."niri/config.kdl" = lib.mkIf (cfg.enable && cfg.settings != null) {
            source =
              pkgs.runCommand "config.kdl"
                {
                  config = serialize.nodes cfg.settings;
                  passAsFile = [ "config" ];
                  buildInputs = [ cfg.package ];
                }
                ''
                  niri validate -c $configPath
                  cp $configPath $out
                '';
          };
        };
    in
    {
      packages = forAllSystems (system: {
        niri-unstable = mkNiri (pkgsFor system);
        xwayland-satellite-unstable = mkXwaylandSatellite (pkgsFor system);
      });

      overlays.default = final: _prev: {
        niri-unstable = mkNiri final;
        xwayland-satellite-unstable = mkXwaylandSatellite final;
      };

      homeModules.default = homeModule;
      nixosModules.default = nixosModule;

      lib = { inherit kdl; };
    };
}
