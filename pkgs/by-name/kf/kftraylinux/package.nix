{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  makeWrapper,
  autoPatchelfHook,
  nix-update-script,
}:

let
  pname = "kftraylinux";
  version = "0.23.2";

  # Select AppImage based on architecture
  sources = {
    x86_64-linux = {
      url = "https://github.com/hcavarsan/kftray/releases/download/v${version}/kftray_${version}_amd64.AppImage";
      hash = "sha256-GfHWyWo0sd4ruwEcmm0jEhih0e5ST/yVRKzjIyfLVxI=";
    };
    aarch64-linux = {
      url = "https://github.com/hcavarsan/kftray/releases/download/v${version}/kftray_${version}_aarch64.AppImage";
      hash = "sha256-ySTr7Wjiq8vP2KdODjuGbNpgWFrlQXzc2cUySPbsGow=";
    };
  };

  src = fetchurl (sources.${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}"));

  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };

in appimageTools.wrapType2 {
  inherit pname version src;

  nativeBuildInputs = [ 
    makeWrapper 
    autoPatchelfHook 
  ];

  extraPkgs = pkgs: with pkgs; [
    # Minimal runtime dependencies
    libcanberra-gtk3
  ];

  extraInstallCommands = ''
    # Install desktop file and icon
    install -m 444 -D ${appimageContents}/kftray.desktop $out/share/applications/kftraylinux.desktop
    install -m 444 -D ${appimageContents}/kftray.png \
      $out/share/icons/hicolor/512x512/apps/kftraylinux.png
    
    # Fix desktop file
    substituteInPlace $out/share/applications/kftraylinux.desktop \
      --replace-warn 'Exec=kftray' 'Exec=${pname}' \
      --replace-warn 'Name=kftray' 'Name=KFtray Linux' \
      --replace-warn 'Icon=kftray' 'Icon=kftraylinux'

    # Wrap with proper Wayland/X11 support following Caido pattern
    wrapProgram $out/bin/kftraylinux \
      --set WEBKIT_DISABLE_COMPOSITING_MODE 1 \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "kubectl port-forward manager (AppImage version) with traffic inspection, udp support, and proxy connections through k8s clusters";
    longDescription = ''
      kubectl port-forward manager with a user-friendly interface for managing multiple port-forward configurations.
      Supports traffic inspection, UDP forwarding, and proxy connections through Kubernetes clusters.
      
      This is the AppImage version of kftray, packaged for easy deployment without building from source.
      Built with Tauri v2 for improved performance and modern web technologies.
    '';
    homepage = "https://github.com/hcavarsan/kftray";
    downloadPage = "https://github.com/hcavarsan/kftray/releases";
    changelog = "https://github.com/hcavarsan/kftray/releases/tag/v${version}";
    license = lib.licenses.gpl3;
    maintainers = with lib.maintainers; [ hcavarsan ];
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "kftraylinux";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}