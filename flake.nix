{
  description = "A scrollable-tiling Wayland compositor.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    systems.url = "github:nix-systems/default";

    niri-unstable.url = "github:niri-wm/niri";
    niri-unstable.flake = false;

    xwayland-satellite-unstable.url = "github:Supreeeme/xwayland-satellite";
    xwayland-satellite-unstable.flake = false;

    niri-utils = {
      url = "github:sodiboo/niri-flake/d96d43634b2207a6a0f836c693f299642737f4f0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-stable.follows = "";
      inputs.niri-stable.follows = "";
      inputs.niri-unstable.follows = "";
      inputs.xwayland-satellite-stable.follows = "";
      inputs.xwayland-satellite-unstable.follows = "";
    };
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
      inherit (inputs.niri-utils.lib) kdl;
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
        pkgs: src:
        pkgs.rustPlatform.buildRustPackage {
          pname = "niri";
          version = "unstable-${fmtDate src.lastModifiedDate}-${src.shortRev}";

          inherit src;

          cargoLock.lockFile = "${src}/Cargo.lock";
          cargoLock.allowBuiltinFetchGit = true;

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

          NIRI_BUILD_VERSION_STRING = "unstable ${fmtDate src.lastModifiedDate} (commit ${src.rev})";

          passthru.providedSessions = [ "niri" ];

          postPatch = ''
            # patchShebangs resources/niri-session
            # substituteInPlace resources/niri.service \
            #  --replace-fail "ExecStart=niri" "ExecStart=$out/bin/niri"
          '';

          postInstall =
            let

              niriSession = pkgs.writeShellScriptBin "niri-session" ''
                # Detect if being run as a user service, which implies external session management,
                # exec compositor directly
                if [ -n "''${MANAGERPID:-}" ] && [ "''${SYSTEMD_EXEC_PID:-}" = "$$" ]; then
                  case "$(ps -p "$MANAGERPID" -o cmd=)" in
                  *systemd*--user*)
                    exec niri --session
                    ;;
                  esac
                fi

                if [ -n "$SHELL" ] &&
                   grep -q "$SHELL" /etc/shells &&
                   ! (echo "$SHELL" | grep -q "false") &&
                   ! (echo "$SHELL" | grep -q "nologin"); then
                  if [ "$1" != '-l' ]; then
                    exec bash -c "exec -l '$SHELL' -c '$0 -l $*'"
                  else
                    shift
                  fi
                fi

                # Make sure there's no already running session.
                if ${lib.getExe' pkgs.systemd "systemctl"} --user -q is-active niri.service; then
                  echo 'A niri session is already running.'
                  exit 1
                fi

                # Reset failed state of all user units.
                ${lib.getExe' pkgs.systemd "systemctl"} --user reset-failed

                # Import the login manager environment.
                ${lib.getExe' pkgs.systemd "systemctl"} --user import-environment

                if hash ${lib.getExe' pkgs.dbus "dbus-update-activation-environment"} 2>/dev/null; then
                  ${lib.getExe' pkgs.dbus "dbus-update-activation-environment"} --all
                fi

                # Start niri and wait for it to terminate.
                ${lib.getExe' pkgs.systemd "systemctl"} --user --wait start niri.service

                # Force stop of graphical-session.target.
                ${lib.getExe' pkgs.systemd "systemctl"} --user start --job-mode=replace-irreversibly niri-shutdown.target

                # Unset environment that we've set.
                ${lib.getExe' pkgs.systemd "systemctl"} --user unset-environment WAYLAND_DISPLAY DISPLAY XDG_SESSION_TYPE XDG_CURRENT_DESKTOP NIRI_SOCKET
              '';
            in
            ''
              install -Dm0755 ${niriSession}/bin/niri-session $out/bin/niri-session
              # install -Dm0755 resources/niri-session -t $out/bin
              install -Dm0644 resources/niri.desktop -t $out/share/wayland-sessions
              # install -Dm0644 resources/niri-portals.conf -t $out/share/xdg-desktop-portal
              # install -Dm0644 resources/niri.service -t $out/lib/systemd/user
              # install -Dm0644 resources/niri-shutdown.target -t $out/lib/systemd/user

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

          patches = [ ./00001-xwayland-profile.patch ];

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
        niri-unstable = mkNiri (pkgsFor system) inputs.niri-unstable;
        xwayland-satellite-unstable = mkXwaylandSatellite (pkgsFor system) inputs.xwayland-satellite-unstable;
      });

      overlays.default = final: _prev: {
        niri-unstable = mkNiri final inputs.niri-unstable;
        xwayland-satellite-unstable = mkXwaylandSatellite final inputs.xwayland-satellite-unstable;
      };

      homeModules.default = homeModule;
      nixosModules.default = nixosModule;

      lib = { inherit kdl; };
    };
}
