{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  perl,
  openssl,
  pkg-config,
}:

rustPlatform.buildRustPackage rec {
  pname = "kftui";
  version = "0.23.2";

  src = fetchFromGitHub {
    owner = "hcavarsan";
    repo = "kftray";
    rev = "v${version}";
    hash = "sha256-DoDp5NQhk75t6wQAoVpU/+niBCNU5YG+E0WRiegIk7g=";
  };

  cargoHash = "sha256-8csv47TGYWTF5ysFn+lxAzMViViAag4vUunUpCTYUh8=";

  cargoBuildFlags = [ "--bin" "kftui" ];

  # Skip tests - requires filesystem writes
  doCheck = false;

  nativeBuildInputs = [ perl pkg-config ];
  buildInputs = [ openssl ];

  env = {
    RUSTC_BOOTSTRAP = 1;
  };


  meta = with lib; {
    description = "A TUI to manage multiple kubectl port-forward commands, with support for UDP and K8s proxy" ;
    homepage = "https://kftray.app";
    license = lib.licenses.gpl3;
    maintainers = with maintainers; [ hcavarsan ];
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    mainProgram = "kftui";
  };
}
