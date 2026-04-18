{
  lib,
  src,
  rustPlatform,
  pkg-config,
  installShellFiles,
  wayland,
  systemdLibs,
  pipewire,
  libgbm,
  libglvnd,
  seatd,
  libinput,
  libxkbcommon,
  libdisplay-info_0_2,
  pango,
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

  inherit src;

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
    pipewire
    systemdLibs
  ];

  checkFlags = [ "--skip=::egl" ];

  buildNoDefaultFeatures = true;
  buildFeatures = [
    "dbus"
    "xdp-gnome-screencast"
    "systemd"
  ];

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
}
