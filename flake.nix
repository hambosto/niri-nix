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
            rev = "dd1c3bcb9f1ef416df33ffa22d1d9bcee1398e7d";
            hash = "sha256-lBZc1UMy+1P1T/E41j3jQrpS7EFI3qegd+ktHZdamIg=";
          };

          cargoHash = "sha256-gfnalA3qI3a9h3PvsxgQLCrzapfjLLkxhTMJpwRh+ro=";

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

          NIRI_BUILD_VERSION_STRING = "unstable ${fmtDate self.lastModifiedDate} (commit ${src.rev})";

          passthru.providedSessions = [ "niri" ];

          postPatch = ''
            patchShebangs resources/niri-session
          '';

          postInstall = ''
            install -Dm0755 resources/niri-session -t $out/bin
            install -Dm0644 resources/niri.desktop -t $out/share/wayland-sessions
            install -Dm0644 resources/niri-portals.conf -t $out/share/xdg-desktop-portal

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
            rev = "a879e5e0896a326adc79c474bf457b8b99011027";
            hash = "sha256-wToKwH7IgWdGLMSIWksEDs4eumR6UbbsuPQ42r0oTXQ=";
          };

          cargoHash = "sha256-jbEihJYcOwFeDiMYlOtaS8GlunvSze80iWahDj1qDrs=";

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

            systemd.user.services.niri = {
              Unit = {
                Description = "A scrollable-tiling Wayland compositor";
                BindsTo = [ "graphical-session.target" ];
                Before = [ "graphical-session.target" ];
                Wants = [
                  "graphical-session-pre.target"
                  "xdg-desktop-autostart.target"
                ];
                After = [ "graphical-session-pre.target" ];
              };
              Service = {
                Slice = "session.slice";
                Type = "notify";
                ExecStart = "${lib.getExe cfg.package} --session";
              };
              Install = {
                WantedBy = [ "graphical-session.target" ];
              };
            };

            systemd.user.services.niri-shutdown = {
              Unit = {
                Description = "Shutdown running niri session";
                DefaultDependencies = false;
                StopWhenUnneeded = true;
                Conflicts = [
                  "graphical-session.target"
                  "graphical-session-pre.target"
                ];
                After = [
                  "graphical-session.target"
                  "graphical-session-pre.target"
                ];
              };
            };
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
