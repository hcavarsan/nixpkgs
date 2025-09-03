{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
  at-spi2-atk,
  cairo,
  gdk-pixbuf,
  glib,
  gtk3,
  harfbuzz,
  libayatana-appindicator,
  libdrm,
  libgbm,
  librsvg,
  libsoup_3,
  mesa,
  openssl,
  pango,
  webkitgtk_4_1,
  glib-networking,
  xdotool,
  file,
  curl,
  wget,
  atkmm,
  addDriverRunpath,
  autoPatchelfHook,
  wrapGAppsHook3,
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

  appimageContents = appimageTools.extract {
    inherit pname version src;
  };

in appimageTools.wrapType2 {
  inherit pname version src;

  # Fix graphics and runtime environment
  extraBwrapArgs = [
    "--setenv GTK_PATH ${gtk3}/lib/gtk-3.0"
    "--setenv WEBKIT_DISABLE_COMPOSITING_MODE 1"
    "--setenv GDK_BACKEND x11"
  ];

  extraInstallCommands = ''
    # Install desktop file and icon
    install -m 444 -D ${appimageContents}/kftray.desktop $out/share/applications/kftraylinux.desktop
    
    # Fix desktop file
    substituteInPlace $out/share/applications/kftraylinux.desktop \
      --replace-warn 'Exec=kftray' 'Exec=${pname}' \
      --replace-warn 'Name=kftray' 'Name=KFtray Linux' \
      --replace-warn 'Icon=kftray' 'Icon=kftraylinux'

    # Install icon
    install -m 444 -D ${appimageContents}/kftray.png \
      $out/share/pixmaps/kftraylinux.png

    # Also install to hicolor theme
    for size in 16 32 48 64 128 256 512; do
      if [ -f ${appimageContents}/usr/share/icons/hicolor/''${size}x''${size}/apps/kftray.png ]; then
        install -m 444 -D ${appimageContents}/usr/share/icons/hicolor/''${size}x''${size}/apps/kftray.png \
          $out/share/icons/hicolor/''${size}x''${size}/apps/kftraylinux.png
      fi
    done

    # Install scalable icon if available
    if [ -f ${appimageContents}/usr/share/icons/hicolor/scalable/apps/kftray.svg ]; then
      install -m 444 -D ${appimageContents}/usr/share/icons/hicolor/scalable/apps/kftray.svg \
        $out/share/icons/hicolor/scalable/apps/kftraylinux.svg
    fi
  '';

  # Runtime dependencies for Tauri v2 applications
  extraPkgs = pkgs: with pkgs; [
    # Core Tauri v2 dependencies
    at-spi2-atk
    cairo
    gdk-pixbuf
    glib
    glib-networking
    gtk3
    harfbuzz
    libayatana-appindicator
    libdrm
    libgbm
    librsvg
    libsoup_3
    mesa
    mesa.drivers
    openssl
    pango
    webkitgtk_4_1
    
    # GTK modules to fix loading warnings
    libcanberra-gtk3
    polkit_gnome
    
    # Graphics and display dependencies
    xorg.libX11
    xorg.libXext
    xorg.libXrender
    xorg.libXrandr
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXfixes
    wayland
    
    # System utilities
    xdotool
    file
    curl
    wget
    atkmm
    
    # Additional runtime libraries
    stdenv.cc.cc.lib
  ];

  passthru.updateScript = nix-update-script { };

  meta = with lib; {
    description = "kubectl port-forward manager (AppImage version) with traffic inspection, udp support, and proxy connections through k8s clusters";
    longDescription = ''
      kubectl port-forward manager with a user-friendly interface for managing multiple port-forward configurations.
      Supports traffic inspection, UDP forwarding, and proxy connections through Kubernetes clusters.
      
      This is the AppImage version of kftray, packaged for easy deployment without building from source.
      Built with Tauri v2 for improved performance and modern web technologies.
      
      Note: This application may require nixGL on non-NixOS Linux distributions due to WebKit EGL context issues.
      If the application fails to start, install nixGL and run: nixGL kftraylinux
    '';
    homepage = "https://github.com/hcavarsan/kftray";
    downloadPage = "https://github.com/hcavarsan/kftray/releases";
    changelog = "https://github.com/hcavarsan/kftray/releases/tag/v${version}";
    license = licenses.gpl3;
    maintainers = with maintainers; [ hcavarsan ];
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "kftraylinux";
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}