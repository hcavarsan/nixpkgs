{
  lib,
  stdenv,
  fetchurl,
}:

let
  pname = "kftui";
  version = "0.23.2";

  src = fetchurl (
    {
      x86_64-linux = {
        url = "https://github.com/hcavarsan/kftray/releases/download/v${version}/kftui_linux_amd64";
        hash = "sha256-c4Qt88cKbj4hqyryTd6KDNp0+3pngzFw1LZY+L96t6w=";
      };
      aarch64-linux = {
        url = "https://github.com/hcavarsan/kftray/releases/download/v${version}/kftui_linux_arm64";
        hash = "sha256-DtQS5rtv8KaNFyicaPgJkLk1CIgxJZLyXCQqsBZEEnI=";
      };
      x86_64-darwin = {
        url = "https://github.com/hcavarsan/kftray/releases/download/v${version}/kftui_macos_universal";
        hash = "sha256-Kc7zExfu+KALnqIVB9K/9puDk1wSncESlX8McYX3PjY=";
      };
      aarch64-darwin = {
        url = "https://github.com/hcavarsan/kftray/releases/download/v${version}/kftui_macos_universal";
        hash = "sha256-Kc7zExfu+KALnqIVB9K/9puDk1wSncESlX8McYX3PjY=";
      };
    }.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}")
  );

  passthru.updateScript = ./update.sh;

  meta = {
    description = "A TUI to manage multiple kubectl port-forward commands, with support for UDP and K8s proxy";
    homepage = "https://kftray.app";
    license = lib.licenses.gpl3;
    maintainers = with lib.maintainers; [ hcavarsan ];
    platforms = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    mainProgram = "kftui";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
in

stdenv.mkDerivation {
  inherit pname version src passthru meta;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/kftui
    runHook postInstall
  '';
}
