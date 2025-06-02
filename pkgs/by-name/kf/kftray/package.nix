{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  cargo-tauri_1,
  desktop-file-utils,
  jq,
  makeBinaryWrapper,
  moreutils,
  nodejs,
  pkg-config,
  pnpm_9,
  wrapGAppsHook3,

  dbus,
  gdk-pixbuf,
  glib,
  glib-networking,
  gobject-introspection,
  gtk3,
  libayatana-appindicator,
  libsoup_2_4,
  openssl,
  webkitgtk_4_0,

  nix-update-script,
}:

let
  version = "0.19.0";

  src = fetchFromGitHub {
    owner = "hcavarsan";
    repo = "kftray";
    rev = "v${version}";
    hash = "sha256-AM+RfQ77lh6T0SULHcHUBPvAtKk/1kDkUNUYcVonJHs=";
  };

  pnpm = pnpm_9;

  meta = {
    description = "Cross-platform system tray app for Kubernetes port-forward management";
    longDescription = ''
      kftray is a cross-platform system tray application that manages and synchronizes 
      kubectl port-forward configurations with ease. It provides a convenient graphical 
      interface for managing Kubernetes port forwarding directly from the system tray.
    '';
    homepage = "https://kftray.app";
    changelog = "https://github.com/hcavarsan/kftray/releases/tag/v${version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ]; # TODO: Add maintainer
    mainProgram = "kftray";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
in

rustPlatform.buildRustPackage {
  pname = "kftray";
  inherit version src meta;

  pnpmDeps = pnpm.fetchDeps {
    inherit version src;
    pname = "kftray";
    hash = "sha256-+JaeFzGTd9TPFyp11zzjZOVtRuLkoJBMAyYg6TAhJnc=";
  };

  useFetchCargoVendor = true;
  cargoHash = "sha256-3B7VI3UcyF4htELOQteUr+De9DF9wVk8TPCxZ7SnMls=";

  # Build only the kftray-tauri package from the workspace
  buildAndTestSubdir = "crates/kftray-tauri";

  # Disable tests due to flaky database and environment-dependent tests
  doCheck = false;

  postPatch = ''
    # Link frontend dist directory for Tauri build
    ln -s frontend/dist crates/kftray-tauri/

    # Disable updater and external binaries for nixpkgs
    jq '.tauri.updater.active = false | del(.tauri.bundle.externalBin)' \
      crates/kftray-tauri/tauri.conf.json | sponge crates/kftray-tauri/tauri.conf.json
  '' + lib.optionalString stdenv.hostPlatform.isLinux ''
    # Fix library paths for system tray support
    substituteInPlace $cargoDepsCopy/libappindicator-sys-*/src/lib.rs \
      --replace-fail "libayatana-appindicator3.so.1" "${libayatana-appindicator}/lib/libayatana-appindicator3.so.1"
  '';

  nativeBuildInputs = [
    cargo-tauri_1.hook
    jq
    moreutils
    nodejs
    pnpm.configHook
  ] ++ lib.optionals stdenv.hostPlatform.isLinux [
    desktop-file-utils
    pkg-config
    wrapGAppsHook3
  ] ++ lib.optionals stdenv.hostPlatform.isDarwin [
    makeBinaryWrapper
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    dbus
    gdk-pixbuf
    glib
    glib-networking
    gobject-introspection
    gtk3
    libayatana-appindicator
    libsoup_2_4
    openssl
    webkitgtk_4_0
  ] ++ lib.optionals stdenv.hostPlatform.isDarwin [
    openssl
  ];

  env = {
    OPENSSL_NO_VENDOR = 1;
  };

  postInstall = lib.optionalString stdenv.hostPlatform.isDarwin ''
    makeBinaryWrapper "$out/Applications/kftray.app/Contents/MacOS/kftray" "$out/bin/kftray"
  '' + lib.optionalString stdenv.hostPlatform.isLinux ''
    # Fix desktop file
    if [ -f "$out/share/applications/kftray.desktop" ]; then
      desktop-file-edit "$out/share/applications/kftray.desktop" \
        --set-comment "${meta.description}" \
        --set-key="StartupNotify" --set-value="true" \
        --set-key="Categories" --set-value="Development;Network;" \
        --set-key="Keywords" --set-value="kubernetes;kubectl;port-forward;k8s;" \
        --set-key="StartupWMClass" --set-value="kftray"
    fi
  '';

  # Only wrap the main binary, not all binaries
  dontWrapGApps = true;

  postFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    wrapGApp "$out/bin/kftray" \
      --set WEBKIT_DISABLE_COMPOSITING_MODE 1 \
      --set WEBKIT_DISABLE_DMABUF_RENDERER 1
  '';

  passthru = {
    updateScript = nix-update-script { };
  };
}