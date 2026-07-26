{
  lib,
  src,
  rustPlatform,
  pkg-config,
  wrapGAppsHook4,
  gtk4,
  libadwaita,
  withPicker ? true,
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
  pname = "niri-screenshare";
  version = "unstable-${fmtDate src.lastModifiedDate}-${src.shortRev}";

  inherit src;

  cargoLock.lockFile = "${src}/Cargo.lock";
  cargoLock.allowBuiltinFetchGit = true;

  buildFeatures = lib.optional withPicker "picker";

  nativeBuildInputs = lib.optionals withPicker [
    pkg-config
    wrapGAppsHook4
  ];

  buildInputs = lib.optionals withPicker [
    gtk4
    libadwaita
  ];

  postInstall = ''
    mkdir -p $out/share/dbus-1/services $out/lib/systemd/user

    install -Dm644 data/niri.portal \
      $out/share/xdg-desktop-portal/portals/niri.portal

    install -Dm644 data/niri-portals.conf \
      $out/share/xdg-desktop-portal/niri-portals.conf

    substitute data/org.freedesktop.impl.portal.desktop.niri.service \
      $out/share/dbus-1/services/org.freedesktop.impl.portal.desktop.niri.service \
      --replace-fail /usr/lib/niri-screenshare "$out/bin/niri-screenshare"

    substitute data/niri-screenshare.service \
      $out/lib/systemd/user/niri-screenshare.service \
      --replace-fail /usr/lib/niri-screenshare "$out/bin/niri-screenshare"
  '';

  meta = {
    description = "Portal backend for niri implementing ScreenCast";
    homepage = "https://github.com/pantarune/niri-screenshare/";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "niri-screenshare";
  };
}
