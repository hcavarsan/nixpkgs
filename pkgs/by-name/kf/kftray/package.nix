{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  undmg,
  libappindicator-gtk3,
  libcanberra-gtk3,
  mesa,
  libdrm,
}:

let
  pname = "kftray";
  version = "0.23.2";

  src = fetchurl (
    {
      x86_64-linux = {
        url = "https://github.com/hcavarsan/kftray/releases/download/v${version}/kftray_${version}_amd64.AppImage";
        hash = "sha256-GfHWyWo0sd4ruwEcmm0jEhih0e5ST/yVRKzjIyfLVxI=";
      };
      aarch64-linux = {
        url = "https://github.com/hcavarsan/kftray/releases/download/v${version}/kftray_${version}_aarch64.AppImage";
        hash = "sha256-ySTr7Wjiq8vP2KdODjuGbNpgWFrlQXzc2cUySPbsGow=";
      };
      x86_64-darwin = {
        url = "https://github.com/hcavarsan/kftray/releases/download/v${version}/kftray_${version}_universal.dmg";
        hash = "sha256-0mm4gL2zJXX1OYwvpSD8b5oZl13nTvxiu6l3NZ3nIgA=";
      };
      aarch64-darwin = {
        url = "https://github.com/hcavarsan/kftray/releases/download/v${version}/kftray_${version}_universal.dmg";
        hash = "sha256-0mm4gL2zJXX1OYwvpSD8b5oZl13nTvxiu6l3NZ3nIgA=";
      };
    }.${stdenv.system} or (throw "Unsupported system: ${stdenv.system}")
  );

  meta = {
    description = "kubectl port-forward manager with traffic inspection, udp support, proxy connections through k8s clusters and state via local files or git repos";
    homepage = "https://github.com/hcavarsan/kftray";
    license = lib.licenses.gpl3;
    maintainers = with lib.maintainers; [ hcavarsan ];
    platforms = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    mainProgram = "kftray";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };

  passthru.updateScript = ./update.sh;
in

if stdenv.hostPlatform.isDarwin then
  stdenv.mkDerivation {
    inherit
      pname
      version
      src
      passthru
      meta
      ;

    sourceRoot = ".";

    nativeBuildInputs = [ undmg ];

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/Applications"
      mv kftray.app $out/Applications/
      runHook postInstall
    '';
  }
else
  appimageTools.wrapType2 {
    inherit
      pname
      version
      src
      passthru
      meta
      ;

    extraPkgs = pkgs: [
      libappindicator-gtk3
      pkgs.makeWrapper
    ];

    extraInstallCommands =
      let
        appimageContents = appimageTools.extractType2 { inherit pname version src; };
      in
      ''
        install -Dm444 ${appimageContents}/kftray.desktop $out/share/applications/kftray.desktop
        install -Dm444 ${appimageContents}/kftray.png $out/share/pixmaps/kftray.png
        
        wrapProgram $out/bin/kftray \
          --set APPIMAGE_EXTRACT_AND_RUN 1 \
          --unset GTK_MODULES
      '';
  }
