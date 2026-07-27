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
  fetchFromGitLab,
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

  # TEMPORARY OVERRIDE: nixpkgs' `libdisplay-info` is now 0.4, but this niri
  # unstable snapshot only supports the 0.3.x API. There's a nixpkgs PR/branch
  # adding a dedicated `libdisplay-info_0_3` package for exactly this case —
  # once that merges into nixos-unstable, drop this override and switch to
  # `libdisplay-info_0_3` from the function args instead (remove this `let`
  # block and add `libdisplay-info_0_3` to the top-level parameters).
  libdisplay-info_0_3 = libdisplay-info.overrideAttrs (finalAttrs: {
    version = "0.3.0";
    src = fetchFromGitLab {
      domain = "gitlab.freedesktop.org";
      owner = "emersion";
      repo = "libdisplay-info";
      rev = finalAttrs.version;
      sha256 = "sha256-nXf2KGovNKvcchlHlzKBkAOeySMJXgxMpbi5z9gLrdc=";
    };
  });
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
    libdisplay-info_0_3
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
