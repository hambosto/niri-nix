{
  lib,
  src,
  patches ? [ ],
  rustPlatform,
  pkg-config,
  makeWrapper,
  xwayland,
  xcb-util-cursor,
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
  pname = "xwayland-satellite";
  version = "unstable-${fmtDate src.lastModifiedDate}-${src.shortRev}";

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

  buildInputs = [ xcb-util-cursor ];

  buildNoDefaultFeatures = true;
  buildFeatures = lib.optional withSystemd "systemd";

  doCheck = false;

  VERGEN_GIT_DESCRIBE = "unstable ${fmtDate src.lastModifiedDate} (commit ${src.rev})";

  postInstall = ''
    wrapProgram $out/bin/xwayland-satellite \
      --prefix PATH : "${lib.makeBinPath [ xwayland ]}"
  ''
  + lib.optionalString withSystemd ''
    install -Dm0644 resources/xwayland-satellite.service -t $out/lib/systemd/user
  '';

  postFixup = lib.optionalString withSystemd ''
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
}
