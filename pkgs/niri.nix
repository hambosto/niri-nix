{
  lib,
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

let
  fmtDate =
    raw:
    let
      year = builtins.substring 0 4 raw;
      month = builtins.substring 4 2 raw;
      day = builtins.substring 6 2 raw;
    in
    "${year}-${month}-${day}";
in
rustPlatform.buildRustPackage {
  pname = "niri";
  version = "unstable-${fmtDate src.lastModifiedDate}-${src.shortRev}";

  inherit src patches;

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
  ++ lib.optional withScreencastSupport pipewire
  ++ lib.optional withSystemd systemdLibs
  ++ lib.optional (!withSystemd) eudev;

  checkFlags = [ "--skip=::egl" ];

  buildNoDefaultFeatures = true;
  buildFeatures =
    lib.optional withDbus "dbus"
    ++ lib.optional withDinit "dinit"
    ++ lib.optional withScreencastSupport "xdp-gnome-screencast"
    ++ lib.optional withSystemd "systemd";

  doCheck = false;

  passthru.providedSessions = [ "niri" ];

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

  postInstall =
    lib.optionalString (withSystemd || withDinit) ''
      install -Dm0755 resources/niri-session -t $out/bin
      install -Dm0644 resources/niri.desktop -t $out/share/wayland-sessions
    ''
    + lib.optionalString (withDbus || withScreencastSupport || withSystemd) ''
      install -Dm0644 resources/niri-portals.conf -t $out/share/xdg-desktop-portal
    ''
    + lib.optionalString withSystemd ''
      install -Dm0644 resources/niri{-shutdown.target,.service} -t $out/lib/systemd/user
    ''
    + lib.optionalString withDinit ''
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

  postFixup = lib.optionalString withSystemd ''
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
}
