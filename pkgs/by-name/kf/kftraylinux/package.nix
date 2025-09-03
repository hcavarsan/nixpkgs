{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  makeWrapper,
  autoPatchelfHook,
  # Tauri v2 dependencies from wiki
  at-spi2-atk,
  atkmm,
  cairo,
  gdk-pixbuf,
  glib,
  gtk3,
  harfbuzz,
  libayatana-appindicator,
  libcanberra-gtk3,
  librsvg,
  libsoup_3,
  libthai,
  openssl,
  pango,
  webkitgtk_4_1,
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

  buildInputs = [
    glib
    libayatana-appindicator
    libcanberra-gtk3
  ];

  extraPkgs = pkgs: with pkgs; [
    # Tauri v2 dependencies (following wiki recommendations)
    at-spi2-atk
    atkmm
    cairo
    gdk-pixbuf
    glib
    gtk3
    harfbuzz
    libayatana-appindicator
    libcanberra-gtk3
    librsvg
    libsoup_3
    libthai
    openssl
    pango
    webkitgtk_4_1
  ];

  multiArch = true;

  extraInstallCommands = ''
    # List what's actually in the bin directory for debugging
    echo "Contents of $out/bin/:"
    ls -la $out/bin/
    
    # The binary should be named just 'kftraylinux' with appimageTools.wrapType2
    # Install desktop file and icon (following working v1 example)
    install -Dm444 ${appimageContents}/kftray.desktop $out/share/applications/kftraylinux.desktop
    install -Dm444 ${appimageContents}/kftray.png $out/share/pixmaps/kftraylinux.png
    
    # Fix desktop file to point to our binary
    substituteInPlace $out/share/applications/kftraylinux.desktop \
      --replace 'Exec=AppRun' "Exec=$out/bin/${pname}" \
      --replace 'Name=kftray' 'Name=KFtray Linux' \
      --replace 'Icon=kftray' 'Icon=kftraylinux'

    # Wrap with proper library paths and Wayland/X11 support
    wrapProgram $out/bin/kftraylinux \
      --set WEBKIT_DISABLE_COMPOSITING_MODE 1 \
      --unset GTK_MODULES \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libayatana-appindicator glib ]}" \
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