{
  lib,
  src,
  rustPlatform,
  autoPatchelfHook,
  installShellFiles,
  pkg-config,
  libdisplay-info,
  libgbm,
  libglvnd,
  libinput,
  libxkbcommon,
  pango,
  pipewire,
  seatd,
  systemdLibs,
  wayland,
  rust-jemalloc-sys,
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

  cargoLock.lockFile = "${src}/Cargo.lock";
  cargoLock.allowBuiltinFetchGit = true;

  nativeBuildInputs = [
    autoPatchelfHook
    installShellFiles
    pkg-config
    rustPlatform.bindgenHook
  ];

  buildInputs = [
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
    rust-jemalloc-sys
  ];

  runtimeDependencies = [
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

  patches = [ ../patches/niri.patch ];

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
}
