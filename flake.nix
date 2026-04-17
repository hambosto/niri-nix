{
  description = "A scrollable-tiling Wayland compositor.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

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
    inputs@{
      self,
      nixpkgs,
      ...
    }:
    let
      call = nixpkgs.lib.flip import {
        inherit
          kdl
          ;
        inherit (nixpkgs) lib;
      };
      kdl = call ./kdl.nix;

      date = {
        year = builtins.substring 0 4;
        month = builtins.substring 4 2;
        day = builtins.substring 6 2;
        hour = builtins.substring 8 2;
        minute = builtins.substring 10 2;
        second = builtins.substring 12 2;
      };

      fmt-date = raw: "${date.year raw}-${date.month raw}-${date.day raw}";
      package-version = src: "unstable-${fmt-date src.lastModifiedDate}-${src.shortRev}";
      version-string = src: "unstable ${fmt-date src.lastModifiedDate} (commit ${src.rev})";

      make-niri =
        {
          src,
          patches ? [ ],
          rustPlatform,
          pkg-config,
          installShellFiles,
          wayland,
          systemdLibs,
          eudev,
          pipewire,
          libgbm,
          libglvnd,
          seatd,
          libinput,
          libxkbcommon,
          libdisplay-info_0_2 ? libdisplay-info,
          libdisplay-info,
          pango,
          withDbus ? true,
          withDinit ? false,
          withScreencastSupport ? true,
          withSystemd ? true,
        }:
        rustPlatform.buildRustPackage {
          pname = "niri";
          version = package-version src;
          src = src;
          inherit patches;
          cargoLock = {
            lockFile = "${src}/Cargo.lock";
            allowBuiltinFetchGit = true;
          };
          nativeBuildInputs = [
            pkg-config
            rustPlatform.bindgenHook
            installShellFiles
          ];

          buildInputs = [
            wayland
            libgbm
            libglvnd
            seatd
            libinput
            libdisplay-info_0_2
            libxkbcommon
            pango
          ]
          ++ nixpkgs.lib.optional withScreencastSupport pipewire
          ++ nixpkgs.lib.optional withSystemd systemdLibs
          ++ nixpkgs.lib.optional (!withSystemd) eudev;

          checkFlags = [
            "--skip=::egl"
          ];

          buildNoDefaultFeatures = true;
          buildFeatures =
            nixpkgs.lib.optional withDbus "dbus"
            ++ nixpkgs.lib.optional withDinit "dinit"
            ++ nixpkgs.lib.optional withScreencastSupport "xdp-gnome-screencast"
            ++ nixpkgs.lib.optional withSystemd "systemd";

          passthru.providedSessions = [ "niri" ];
          dontStrip = true;

          RUSTFLAGS = [
            "-C link-arg=-Wl,--push-state,--no-as-needed"
            "-C link-arg=-lEGL"
            "-C link-arg=-lwayland-client"
            "-C link-arg=-Wl,--pop-state"
            "-C debuginfo=line-tables-only"
          ];

          NIRI_BUILD_VERSION_STRING = version-string src;

          outputs = [
            "out"
            "doc"
          ];

          postPatch = ''
            export RUSTFLAGS="$RUSTFLAGS --remap-path-prefix $NIX_BUILD_TOP=/"
            export RUSTFLAGS="$RUSTFLAGS --remap-path-prefix $NIX_BUILD_TOP/source=./"

            patchShebangs resources/niri-session
          '';

          postInstall =
            nixpkgs.lib.optionalString (withSystemd || withDinit) ''
              install -Dm0755 resources/niri-session -t $out/bin
              install -Dm0644 resources/niri.desktop -t $out/share/wayland-sessions
            ''
            + nixpkgs.lib.optionalString (withDbus || withScreencastSupport || withSystemd) ''
              install -Dm0644 resources/niri-portals.conf -t $out/share/xdg-desktop-portal
            ''
            + nixpkgs.lib.optionalString withSystemd ''
              install -Dm0644 resources/niri{-shutdown.target,.service} -t $out/lib/systemd/user
            ''
            + nixpkgs.lib.optionalString withDinit ''
              install -Dm0644 resources/dinit/niri{,-shutdown} -t $out/lib/dinit.d/user
            ''
            + ''
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
            license = nixpkgs.lib.licenses.gpl3Only;
            maintainers = with nixpkgs.lib.maintainers; [ sodiboo ];
            mainProgram = "niri";
            platforms = nixpkgs.lib.platforms.linux;
          };
        };

      validated-config-for =
        pkgs: package: config:
        pkgs.runCommand "config.kdl"
          {
            inherit config;
            passAsFile = [ "config" ];
            buildInputs = [ package ];
          }
          ''
            niri validate -c $configPath
            cp $configPath $out
          '';

      make-xwayland-satellite =
        {
          src,
          patches ? [ ],
          rustPlatform,
          pkg-config,
          makeWrapper,
          xwayland,
          xcb-util-cursor,
          withSystemd ? true,
        }:
        rustPlatform.buildRustPackage {
          pname = "xwayland-satellite";
          version = package-version src;
          inherit src patches;
          cargoLock = {
            lockFile = "${src}/Cargo.lock";
            allowBuiltinFetchGit = true;
          };
          nativeBuildInputs = [
            pkg-config
            rustPlatform.bindgenHook
            makeWrapper
          ];

          buildInputs = [
            xcb-util-cursor
          ];

          buildNoDefaultFeatures = true;
          buildFeatures = nixpkgs.lib.optional withSystemd "systemd";
          doCheck = false;

          VERGEN_GIT_DESCRIBE = version-string src;

          postInstall = ''
            wrapProgram $out/bin/xwayland-satellite \
              --prefix PATH : "${nixpkgs.lib.makeBinPath [ xwayland ]}"
          ''
          + nixpkgs.lib.optionalString withSystemd ''
            install -Dm0644 resources/xwayland-satellite.service -t $out/lib/systemd/user
          '';

          postFixup = nixpkgs.lib.optionalString withSystemd ''
            substituteInPlace $out/lib/systemd/user/xwayland-satellite.service \
              --replace-fail /usr/local/bin $out/bin
          '';

          meta = {
            description = "Rootless Xwayland integration to any Wayland compositor implementing xdg_wm_base";
            homepage = "https://github.com/Supreeeme/xwayland-satellite";
            license = nixpkgs.lib.licenses.mpl20;
            maintainers = with nixpkgs.lib.maintainers; [ hambosto ];
            mainProgram = "xwayland-satellite";
            platforms = nixpkgs.lib.platforms.linux;
          };
        };

      make-package-set = pkgs: {
        niri-unstable = pkgs.callPackage make-niri {
          src = inputs.niri-unstable;
        };
        xwayland-satellite-unstable = pkgs.callPackage make-xwayland-satellite {
          src = inputs.xwayland-satellite-unstable;
        };
      };

      cached-packages-for =
        system:
        nixpkgs.legacyPackages.${system}.runCommand "all-niri-flake-packages" { } (
          ''
            mkdir $out
          ''
          + builtins.concatStringsSep "" (
            nixpkgs.lib.mapAttrsToList (name: package: ''
              ln -s ${package} $out/${name}
            '') (make-package-set nixpkgs.legacyPackages.${system})
          )
        );

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      lib = {
        inherit kdl;
        internal = {
          inherit make-package-set validated-config-for;
          package-set = abort "niri-flake internals: `package-set.\${package} pkgs` is now `(make-package-set pkgs).\${package}`";
        };
      };

      packages = forAllSystems (system: make-package-set inputs.nixpkgs.legacyPackages.${system});
      overlays.niri = final: prev: make-package-set final;

      apps = forAllSystems (
        system:
        (builtins.mapAttrs (name: package: {
          type = "app";
          program = nixpkgs.lib.getExe package;
        }) (make-package-set inputs.nixpkgs.legacyPackages.${system}))
        // {
          default = self.apps.${system}.niri-unstable;
        }
      );

      formatter = forAllSystems (system: inputs.nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);
      devShells = forAllSystems (system: {
        default = import ./shell.nix {
          flake = self;
          inherit system;
        };
      });

      homeModules.niri =
        {
          config,
          pkgs,
          lib,
          ...
        }:
        let
          cfg = config.programs.niri;
          kdl = import ./kdl.nix {
            inherit lib;
            inputs = inputs;
          };
        in
        {
          options.programs.niri = {
            package = nixpkgs.lib.mkOption {
              type = nixpkgs.lib.types.package;
              default = (make-package-set pkgs).niri-unstable;
              description = "The niri package to use.";
            };
            settings = nixpkgs.lib.mkOption {
              type = nixpkgs.lib.types.nullOr (
                nixpkgs.lib.types.either nixpkgs.lib.types.str kdl.types.kdl-document
              );
              default = null;
              description = ''
                The niri config file.

                - When this is null, no config file is generated.
                - When this is a string, it is assumed to be the config file contents.
                - When this is a KDL document, it is serialized to a string before being used.
              '';
            };
          };

          config.xdg.configFile.niri-config = {
            enable = cfg.config != null;
            target = "niri/config.kdl";
            source =
              let
                final-config =
                  if builtins.isString cfg.config then
                    cfg.config
                  else if cfg.config != null then
                    kdl.serialize.nodes cfg.config
                  else
                    null;
              in
              validated-config-for pkgs cfg.package final-config;
          };
        };
      nixosModules.niri =
        {
          config,
          options,
          pkgs,
          ...
        }:
        let
          cfg = config.programs.niri;
        in
        {
          disabledModules = [ "programs/wayland/niri.nix" ];

          options.programs.niri = {
            enable = nixpkgs.lib.mkEnableOption "niri";
            package = nixpkgs.lib.mkOption {
              type = nixpkgs.lib.types.package;
              default = (make-package-set pkgs).niri-unstable;
              description = "The niri package to use.";
            };
          };

          config = nixpkgs.lib.mkMerge [
            (nixpkgs.lib.mkIf cfg.enable {
              environment.systemPackages = [
                pkgs.xdg-utils
                pkgs.nautilus
                cfg.package
              ];

              xdg = {
                autostart.enable = nixpkgs.lib.mkDefault true;
                menus.enable = nixpkgs.lib.mkDefault true;
                mime.enable = nixpkgs.lib.mkDefault true;
                icons.enable = nixpkgs.lib.mkDefault true;
              };

              xdg.portal = {
                enable = true;
                extraPortals = nixpkgs.lib.mkIf (
                  !cfg.package.cargoBuildNoDefaultFeatures
                  || builtins.elem "xdp-gnome-screencast" cfg.package.cargoBuildFeatures
                ) [ pkgs.xdg-desktop-portal-gnome ];
                configPackages = [ cfg.package ];
              };

              security.pam.services.swaylock = { };
              programs.dconf.enable = nixpkgs.lib.mkDefault true;
            })
          ];
        };

      checks = forAllSystems (
        system:
        let
          test-nixos-for =
            nixpkgs: modules:
            (nixpkgs.lib.nixosSystem {
              inherit system;
              modules = [
                {
                  system.stateVersion = "23.11";
                  fileSystems."/".fsType = "ext4";
                  fileSystems."/".device = "/dev/sda1";
                  boot.loader.systemd-boot.enable = true;
                }
              ]
              ++ modules;
            }).config.system.build.toplevel;
        in
        {
          cached-packages = cached-packages-for system;

          nixos = test-nixos-for nixpkgs [
            self.nixosModules.niri
            {
              programs.niri.enable = true;
            }
          ];
        }
      );
    };
}
