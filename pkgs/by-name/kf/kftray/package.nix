{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  undmg,
  autoPatchelfHook,
  libappindicator-gtk3,
  gtk3,
  gsettings-desktop-schemas,
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
  let
    appimageContents = appimageTools.extractType2 { inherit pname version src; };
  in
  stdenv.mkDerivation {
    inherit pname version passthru meta;

    src = appimageContents;

    dontConfigure = true;
    dontBuild = true;

    nativeBuildInputs = [
      autoPatchelfHook
    ];

    buildInputs = [
      libappindicator-gtk3
      gtk3
    ];

    installPhase = ''
      mkdir "$out"
      cp -ar . "$out/app"
      cd "$out"

      # Remove the AppImage runner
      rm -f app/AppRun

      # Create bin directory and main executable
      mkdir bin
      
      cat > bin/kftray <<EOF
      #! $SHELL -e
      
      export XDG_DATA_DIRS="${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name}:${gtk3}/share/gsettings-schemas/${gtk3.name}:\$XDG_DATA_DIRS"
      export GTK_MODULES=""
      
      exec "$out/app/kftray" "\$@"
      EOF

      chmod +x bin/kftray

      # Install desktop file and icon if they exist
      if [ -f app/kftray.desktop ]; then
        mkdir -p share/applications
        cp app/kftray.desktop share/applications/
        substituteInPlace share/applications/kftray.desktop \
          --replace-quiet 'Exec=AppRun' 'Exec=${pname}'
      fi
      
      if [ -f app/kftray.png ]; then
        mkdir -p share/pixmaps
        cp app/kftray.png share/pixmaps/
      fi
    '';
  }
