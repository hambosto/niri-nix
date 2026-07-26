{
  lib,
  src,
  rustPlatform,
  pkg-config,
  pipewire,
  libxkbcommon,
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
  pname = "xdg-desktop-portal-generic";
  version = "unstable-${fmtDate src.lastModifiedDate}-${src.shortRev}";

  inherit src;

  cargoLock.lockFile = "${src}/Cargo.lock";
  cargoLock.allowBuiltinFetchGit = true;

  doCheck = false;

  nativeBuildInputs = [
    pkg-config
    rustPlatform.bindgenHook
  ];
  buildInputs = [
    pipewire
    libxkbcommon
  ];

  patches = [ ../patches/xdg-desktop-portal-generic.patch ];

  postInstall = ''
    install -Dm644 data/generic.portal \
      $out/share/xdg-desktop-portal/portals/generic.portal
    install -Dm644 data/org.freedesktop.impl.portal.desktop.generic.service \
      $out/share/dbus-1/services/org.freedesktop.impl.portal.desktop.generic.service
    install -Dm644 data/xdg-desktop-portal-generic.service \
      $out/lib/systemd/user/xdg-desktop-portal-generic.service

    substituteInPlace \
      $out/share/dbus-1/services/org.freedesktop.impl.portal.desktop.generic.service \
      $out/lib/systemd/user/xdg-desktop-portal-generic.service \
      --replace-fail /usr/libexec/xdg-desktop-portal-generic $out/bin/xdg-desktop-portal-generic
  '';

  meta = {
    description = "Generic XDG Desktop Portal backend for Wayland compositors";
    homepage = "https://github.com/lamco-admin/xdg-desktop-portal-generic";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "xdg-desktop-portal-generic";
  };
}
