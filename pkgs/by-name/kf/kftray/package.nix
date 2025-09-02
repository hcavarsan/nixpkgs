{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  cacert,
  cargo-tauri,
  desktop-file-utils,
  glib-networking,
  jq,
  libayatana-appindicator,
  libdrm,
  libGL,
  librsvg,
  libxkbcommon,
  makeBinaryWrapper,
  moreutils,
  nodejs,
  openssl,
  perl,
  pkg-config,
  pnpm,
  webkitgtk_4_0,
  wrapGAppsHook3,
  libcanberra,
  xdg-utils,
}:

rustPlatform.buildRustPackage rec {
  pname = "kftray";
  version = "0.23.2";

  src = fetchFromGitHub {
    owner = "hcavarsan";
    repo = "kftray";
    rev = "v${version}";
    hash = "sha256-DoDp5NQhk75t6wQAoVpU/+niBCNU5YG+E0WRiegIk7g=";
  };

  cargoHash = "sha256-8csv47TGYWTF5ysFn+lxAzMViViAag4vUunUpCTYUh8=";

  pnpmDeps = pnpm.fetchDeps {
    inherit pname src;
    hash = if stdenv.isDarwin then "sha256-e367SyVoLpCVfE2IBf/Nuj1KXgOQJaNWzzQYyRKJDjQ=" else "sha256-hd2eKjYPaoA71nEs0qnnh0hY+LCqUVj0MOx05SqaVxc=";
    fetcherVersion = 1;
  };

  nativeBuildInputs = [
    cargo-tauri.hook
    desktop-file-utils
    jq
    moreutils
    nodejs
    perl
    pkg-config
    pnpm.configHook
    wrapGAppsHook3
  ] ++ lib.optional stdenv.isDarwin makeBinaryWrapper;

  buildInputs = [
    cacert
    openssl
  ] ++ lib.optionals stdenv.isLinux [
    glib-networking
    libayatana-appindicator
    libdrm
    libGL
    librsvg
    libxkbcommon
    webkitgtk_4_0
    libcanberra
    xdg-utils
  ];

  postPatch = ''
    mkdir -p crates/kftray-tauri/bin

    jq '.plugins.updater.endpoints = [] | .bundle.createUpdaterArtifacts = false' crates/kftray-tauri/tauri.conf.json \
      | sponge crates/kftray-tauri/tauri.conf.json
  '' + lib.optionalString stdenv.isLinux ''

    substituteInPlace $cargoDepsCopy/libappindicator-sys-*/src/lib.rs \
      --replace-fail "libayatana-appindicator3.so.1" "${libayatana-appindicator}/lib/libayatana-appindicator3.so.1"
  '';

  cargoBuildFlags = [ "--package" "kftray-tauri" ];

  tauriBuildFlags = [
    "--config"
    "crates/kftray-tauri/tauri.conf.json"
  ];

  preBuild = ''
    cargo build --release --bin kftray-helper
    cp target/release/kftray-helper crates/kftray-tauri/bin/kftray-helper-${stdenv.hostPlatform.rust.rustcTarget}
  '';

  # Skip tests - requires filesystem writes and system commands
  doCheck = false;

  env = {
    RUSTC_BOOTSTRAP = 1;
    VITE_ENV = "production";
    TAURI_DEBUG = "false";
  };

  postInstall =
    lib.optionalString stdenv.hostPlatform.isDarwin ''
      makeBinaryWrapper $out/Applications/kftray.app/Contents/MacOS/kftray $out/bin/kftray
    ''
    + lib.optionalString stdenv.hostPlatform.isLinux ''
      install -Dm644 $src/icon.png $out/share/icons/hicolor/512x512/apps/kftray.png
      install -Dm644 $src/crates/kftray-tauri/icons/tray-light.png $out/share/icons/hicolor/scalable/status/kftray-tray.png

      desktop-file-edit \
        --set-comment "kubectl port-forward manager with traffic inspection, udp support, proxy connections through k8s clusters and state via local files or git repos." \
        --set-key="Keywords" --set-value="kubernetes;kubectl;port-forward;" \
        --set-key="StartupWMClass" --set-value="kftray" \
        $out/share/applications/kftray.desktop
    '';

  meta = with lib; {
    description = "kubectl port-forward manager with traffic inspection, udp support, proxy connections through k8s clusters and state via local files or git repos";
    longDescription = ''
      Note: On non-NixOS Linux distributions, you may need to run this application with nixGL due to graphics driver compatibility issues.
      Install nixGL and run: nixGL kftray
    '';
    homepage = "https://github.com/hcavarsan/kftray";
    license = lib.licenses.gpl3;
    maintainers = with maintainers; [ hcavarsan ];
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    mainProgram = "kftray";
  };
}
