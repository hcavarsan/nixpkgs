{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,

  cargo-tauri,
  nodejs,
  pnpm,
  perl,
  jq,
  moreutils,

  pkg-config,
  wrapGAppsHook3,

  openssl,
  webkitgtk_4_1,
  glib-networking,
  libappindicator,
  nix-update-script,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "kftray";
  version = "0.23.2";

  src = fetchFromGitHub {
    owner = "hcavarsan";
    repo = "kftray";
    tag = "v${finalAttrs.version}";
    hash = "sha256-DoDp5NQhk75t6wQAoVpU/+niBCNU5YG+E0WRiegIk7g=";
  };

  pnpmDeps = pnpm.fetchDeps {
    inherit (finalAttrs) pname src;
    hash = "sha256-hd2eKjYPaoA71nEs0qnnh0hY+LCqUVj0MOx05SqaVxc=";
    fetcherVersion = 1;
  };

  cargoRoot = "crates/kftray-tauri";
  buildAndTestSubdir = finalAttrs.cargoRoot;

  cargoHash = "sha256-8csv47TGYWTF5ysFn+lxAzMViViAag4vUunUpCTYUh8=";

  postPatch = ''
    # Copy Cargo.lock to cargoRoot
    cp Cargo.lock crates/kftray-tauri/
    
    # Disable tauri updater and bundling
    jq '.plugins.updater.endpoints = [] | .bundle.createUpdaterArtifacts = false' crates/kftray-tauri/tauri.conf.json \
      | sponge crates/kftray-tauri/tauri.conf.json
  '';

  preBuild = ''
    # Build kftray-helper sidecar binary
    cargo build --release --bin kftray-helper
    mkdir -p crates/kftray-tauri/bin
    cp target/release/kftray-helper crates/kftray-tauri/bin/kftray-helper-${stdenv.hostPlatform.rust.rustcTarget}
  '';

  nativeBuildInputs = [
    pnpm.configHook
    nodejs
    cargo-tauri.hook
    pkg-config
    wrapGAppsHook3
    perl
    jq
    moreutils
  ];

  buildInputs = [
    openssl
    webkitgtk_4_1
    glib-networking
    libappindicator
  ];

  # Skip tests - requires filesystem writes and system commands
  doCheck = false;

  dontWrapGApps = true;

  postInstall = ''
    wrapProgram $out/bin/kftray \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ libappindicator ]}
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "kubectl port-forward manager with traffic inspection, udp support, proxy connections through k8s clusters and state via local files or git repos";
    homepage = "https://github.com/hcavarsan/kftray";
    license = lib.licenses.gpl3;
    maintainers = with lib.maintainers; [ hcavarsan ];
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    mainProgram = "kftray";
  };
})
