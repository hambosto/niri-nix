{
  description = "A scrollable-tiling Wayland compositor.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";

    niri-unstable.url = "github:niri-wm/niri";
    niri-unstable.flake = false;

    xwayland-satellite-unstable.url = "github:Supreeeme/xwayland-satellite";
    xwayland-satellite-unstable.flake = false;
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      systems,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      forAllSystems = f: nixpkgs.lib.genAttrs (import systems) f;
      pkgsFor = system: nixpkgs.legacyPackages.${system};
      kdl = import ./kdl.nix { inherit lib; };

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
            pkg-config
            pkgs.rustPlatform.bindgenHook
            installShellFiles
          ];

          buildInputs = with pkgs; [
            wayland
            libgbm
            libglvnd
            seatd
            libinput
            libdisplay-info_0_2
            libxkbcommon
            pango
            pipewire
            systemdLibs
          ];

          buildNoDefaultFeatures = true;
          buildFeatures = [
            "dbus"
            "xdp-gnome-screencast"
            "systemd"
          ];

          checkFlags = [ "--skip=::egl" ];

          patches = [ ./001-niri-release.patch ];

          RUSTFLAGS = [
            "-C link-arg=-Wl,--push-state,--no-as-needed"
            "-C link-arg=-lEGL"
            "-C link-arg=-lwayland-client"
            "-C link-arg=-Wl,--pop-state"
            "-C debuginfo=line-tables-only"
          ];

          NIRI_BUILD_VERSION_STRING = "unstable ${fmtDate src.lastModifiedDate} (commit ${src.rev})";

          outputs = [
            "out"
            "doc"
          ];

          postPatch = ''
            export RUSTFLAGS="$RUSTFLAGS --remap-path-prefix $NIX_BUILD_TOP=/"
            export RUSTFLAGS="$RUSTFLAGS --remap-path-prefix $NIX_BUILD_TOP/source=./"
            patchShebangs resources/niri-session
          '';

          postInstall = ''
            install -Dm0755 resources/niri-session -t $out/bin
            install -Dm0644 resources/niri.desktop -t $out/share/wayland-sessions
            install -Dm0644 resources/niri-portals.conf -t $out/share/xdg-desktop-portal
            install -Dm0644 resources/niri{-shutdown.target,.service} -t $out/lib/systemd/user

            installShellCompletion --cmd niri \
              --bash <($out/bin/niri completions bash) \
              --zsh <($out/bin/niri completions zsh) \
              --fish <($out/bin/niri completions fish) \
              --nushell <($out/bin/niri completions nushell)

              install -Dm0644 README.md resources/default-config.kdl -t $doc/share/doc/niri
          '';

          postFixup = ''
            substituteInPlace $out/lib/systemd/user/niri.service \
              --replace-fail "ExecStart=niri" "ExecStart=$out/bin/niri"
          '';

          meta = {
            description = "Scrollable-tiling Wayland compositor";
            homepage = "https://github.com/YaLTeR/niri";
            license = lib.licenses.gpl3Only;
            maintainers = with lib.maintainers; [ hambosto ];
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
            pkg-config
            pkgs.rustPlatform.bindgenHook
            makeWrapper
          ];

          buildInputs = with pkgs; [ xcb-util-cursor ];

          buildNoDefaultFeatures = true;
          buildFeatures = [ "systemd" ];

          doCheck = false;

          patches = [ ./001-xwayland-release.patch ];

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
            maintainers = with lib.maintainers; [ hambosto ];
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
              type = types.kdlDocument;
              default = [ ];
              description = ''
                Niri configuration as a KDL document attrset, serialised via
                the kdl library and validated with `niri validate` at build time.
              '';
            };
          };

          # config = lib.mkIf cfg.enable {
          #   xdg.configFile."niri/config.kdl" = lib.mkIf (cfg.settings != [ ]) {
          #     source =
          #       pkgs.runCommand "config.kdl"
          #         {
          #           config = serialize.nodes cfg.settings;
          #           passAsFile = [ "config" ];
          #           buildInputs = [ cfg.package ];
          #         }
          #         ''
          #           niri validate -c $configPath
          #           cp $configPath $out
          #         '';
          #   };
          # };

          config.xdg.configFile.config = {
            enable = cfg.enable;
            target = "niri/config.kdl";
            # source = validated-config-for pkgs cfg.package cfg.finalConfig;
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
        niri-unstable = mkNiri (pkgsFor system) inputs.niri-unstable;
        xwayland-satellite-unstable = mkXwaylandSatellite (pkgsFor system) inputs.xwayland-satellite-unstable;
      });

      overlays.niri = final: _prev: {
        niri-unstable = mkNiri final inputs.niri-unstable;
        xwayland-satellite-unstable = mkXwaylandSatellite final inputs.xwayland-satellite-unstable;
      };

      homeModules.niri = homeModule;
      nixosModules.niri = nixosModule;

      lib = { inherit kdl; };
    };
}
