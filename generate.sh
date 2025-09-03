#!/usr/bin/env bash
set -uo pipefail
# Temporarily disable -e to debug where script is exiting

# Script to generate all hashes needed for kftray and kftui packages

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Package details
OWNER="hcavarsan"
REPO="kftray"
VERSION="0.23.2"
TAG="v${VERSION}"
KFTRAY_SOURCE_DIR="/Users/henrique/repos/kftray"

echo "🔍 Generating hashes for kftray and kftui packages..."
echo
echo -e "${YELLOW}📦 Package details:${NC}"
echo "  Owner: $OWNER"
echo "  Repo: $REPO"
echo "  Version: $VERSION"
echo "  Tag: $TAG"
echo "  Source dir: $KFTRAY_SOURCE_DIR"
echo

# Check if we need to restore placeholder hashes
echo -e "${YELLOW}🔧 Checking package files...${NC}"

# Only restore if files have corrupted hashes (not standard sha256- format)
KFTRAY_NEEDS_RESTORE=0
KFTUI_NEEDS_RESTORE=0

if grep -q "🦀\|📦" pkgs/by-name/kf/kftray/package.nix 2>/dev/null; then
    KFTRAY_NEEDS_RESTORE=1
fi

if grep -q "🦀" pkgs/by-name/kf/kftui/package.nix 2>/dev/null; then
    KFTUI_NEEDS_RESTORE=1
fi

if [[ $KFTRAY_NEEDS_RESTORE -gt 0 || $KFTUI_NEEDS_RESTORE -gt 0 ]]; then
    echo -e "${YELLOW}🔧 Restoring placeholder hashes...${NC}"
    
    # Restore kftray package.nix only if corrupted
    cat > pkgs/by-name/kf/kftray/package.nix << 'EOF'
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
  librsvg,
  libxdo,
  makeBinaryWrapper,
  nodejs,
  openssl,
  pkg-config,
  pnpm,
  webkitgtk_4_1,
  wrapGAppsHook4,
  xdg-utils,
}:

rustPlatform.buildRustPackage rec {
  pname = "kftray";
  version = "v0.23.2";

  src = fetchFromGitHub {
    owner = "hcavarsan";
    repo = "kftray";
    rev = "v${version}";
    hash = "sha256-DoDp5NQhk75t6wQAoVpU/+niBCNU5YG+E0WRiegIk7g=";
  };

  cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

  pnpmDeps = pnpm.fetchDeps {
    inherit src;
    hash = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
  };

  nativeBuildInputs = [
    cargo-tauri.hook
    desktop-file-utils
    jq
    nodejs
    pkg-config
    pnpm.configHook
    wrapGAppsHook4
  ] ++ lib.optional stdenv.isDarwin makeBinaryWrapper;

  buildInputs = [
    cacert
    openssl
    libxdo
  ] ++ lib.optionals stdenv.isLinux [
    glib-networking
    libayatana-appindicator
    librsvg
    webkitgtk_4_1
    xdg-utils
  ];

  env = {
    RUSTC_BOOTSTRAP = 1;
    VITE_ENV = "production";
    TAURI_DEBUG = "false";
  };

  postInstall = ''
    install -Dm644 $src/icon.png $out/share/icons/hicolor/512x512/apps/kftray.png
    install -Dm644 $src/crates/kftray-tauri/icons/tray-light.png $out/share/icons/hicolor/scalable/status/kftray-tray.png

    makeWrapper $out/bin/kftray $out/bin/kftray-wrapped \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]}

    install -Dm644 - $out/share/applications/kftray.desktop <<EOF
    [Desktop Entry]
    Name=KFtray
    Comment=A simple tray application to manage your Kubernetes port-forwards.
    Exec=kftray-wrapped
    Icon=kftray
    Terminal=false
    Type=Application
    Categories=Network;System;
    EOF
  '';

  meta = with lib; {
    description = "A simple tray application to manage your Kubernetes port-forwards.";
    homepage = "https://github.com/hcavarsan/kftray";
    license = lib.licenses.gpl3;
    maintainers = with maintainers; [ hcavarsan ];
    platforms = platforms.all;
    mainProgram = "kftray";
  };
}
EOF

# Restore kftui package.nix
cat > pkgs/by-name/kf/kftui/package.nix << 'EOF'
{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  openssl,
}:

rustPlatform.buildRustPackage rec {
  pname = "kftui";
  version = "v0.23.2";

  src = fetchFromGitHub {
    owner = "hcavarsan";
    repo = "kftray";
    rev = "v${version}";
    hash = "sha256-DoDp5NQhk75t6wQAoVpU/+niBCNU5YG+E0WRiegIk7g=";
  };

  cargoHash = "sha256-CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=";
  buildInputs = [ openssl ];

  env = {
    RUSTC_BOOTSTRAP = 1;
  };

  meta = with lib; {
    description = "A TUI and CLI to manage kubectl port-forwards" ;
    homepage = "https://kftray.app";
    license = lib.licenses.gpl3;
    maintainers = with maintainers; [ hcavarsan ];
    platforms = platforms.all;
    mainProgram = "kftui";
  };
}
EOF

    echo -e "${GREEN}✅ Package files restored${NC}"
else
    echo -e "${GREEN}✅ Package files are clean${NC}"
fi
echo

# Function to extract hash from nix build output
extract_hash_from_build() {
    local package_name="$1"
    local build_output
    
    echo -e "${YELLOW}🔍 Building $package_name to extract hash...${NC}"
    
    # Capture build output with more verbose error handling
    echo "Running: nix-build -A $package_name ." >&2
    build_output=$(nix-build -A "$package_name" . 2>&1 || true)
    local exit_code=$?
    
    echo -e "${YELLOW}Build exit code: $exit_code${NC}" >&2
    echo -e "${YELLOW}Build output (first 10 lines):${NC}" >&2
    echo "$build_output" | head -10 >&2
    echo -e "${YELLOW}Build output (last 10 lines):${NC}" >&2
    echo "$build_output" | tail -10 >&2
    
    # Extract hash from output - look for "got: sha256-..." or "expected: sha256-..." or similar patterns
    local hash
    hash=$(echo "$build_output" | grep -o -E "(got|expected):[[:space:]]*sha256-[A-Za-z0-9+/=]*" | head -1 | sed 's/.*:[[:space:]]*//')
    
    if [[ -z "$hash" ]]; then
        # Try alternative patterns
        hash=$(echo "$build_output" | grep -o "sha256-[A-Za-z0-9+/=]*" | head -1)
    fi
    
    if [[ -n "$hash" && "$hash" =~ ^sha256- ]]; then
        echo -e "${GREEN}✅ Extracted hash: $hash${NC}" >&2
        echo "$hash"
        return 0
    else
        echo -e "${RED}❌ Could not extract hash from build output${NC}" >&2
        echo -e "${YELLOW}Searched for patterns: got:/expected: + sha256-${NC}" >&2
        return 1
    fi
}

# Function to update hash in package.nix
update_hash() {
    local file="$1"
    local old_hash="$2"
    local new_hash="$3"
    
    if [[ -n "$new_hash" && "$new_hash" != "$old_hash" && "$new_hash" =~ ^sha256- ]]; then
        sed -i.bak "s|$old_hash|$new_hash|g" "$file"
        echo -e "${GREEN}✅ Updated $file with hash: $new_hash${NC}"
        return 0
    else
        echo -e "${RED}❌ Invalid or same hash: $new_hash${NC}"
        return 1
    fi
}

# Function to check if hash needs updating
needs_hash_update() {
    local file="$1"
    local pattern="$2"
    
    if grep -q "$pattern" "$file"; then
        return 0  # needs update
    else
        return 1  # doesn't need update
    fi
}

# Step 1: Generate cargoHash for kftray
echo -e "${YELLOW}🔍 Checking if kftray cargoHash needs update...${NC}"
if needs_hash_update "pkgs/by-name/kf/kftray/package.nix" "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; then
    echo -e "${YELLOW}🦀 Step 1: Generating cargoHash for kftray...${NC}"
    echo "About to call extract_hash_from_build..."
    KFTRAY_CARGO_HASH=$(extract_hash_from_build "kftray")
    echo "extract_hash_from_build returned: '$KFTRAY_CARGO_HASH'"
    if [[ -n "$KFTRAY_CARGO_HASH" ]]; then
        echo "Calling update_hash..."
        update_hash "pkgs/by-name/kf/kftray/package.nix" "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" "$KFTRAY_CARGO_HASH"
    else
        echo "KFTRAY_CARGO_HASH is empty"
    fi
else
    echo -e "${GREEN}✅ kftray cargoHash already set${NC}"
fi
echo "Finished Step 1"
echo

# Step 2: Generate pnpmDeps hash for kftray 
if needs_hash_update "pkgs/by-name/kf/kftray/package.nix" "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="; then
    echo -e "${YELLOW}📦 Step 2: Generating pnpmDeps hash for kftray...${NC}"
    KFTRAY_PNPM_HASH=$(extract_hash_from_build "kftray")
    if [[ -n "$KFTRAY_PNPM_HASH" ]]; then
        update_hash "pkgs/by-name/kf/kftray/package.nix" "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=" "$KFTRAY_PNPM_HASH"
    fi
else
    echo -e "${GREEN}✅ kftray pnpmDeps hash already set${NC}"
fi
echo

# Step 3: Generate cargoHash for kftui
if needs_hash_update "pkgs/by-name/kf/kftui/package.nix" "sha256-CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC="; then
    echo -e "${YELLOW}🦀 Step 3: Generating cargoHash for kftui...${NC}"
    KFTUI_CARGO_HASH=$(extract_hash_from_build "kftui")
    if [[ -n "$KFTUI_CARGO_HASH" ]]; then
        update_hash "pkgs/by-name/kf/kftui/package.nix" "sha256-CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=" "$KFTUI_CARGO_HASH"
    fi
else
    echo -e "${GREEN}✅ kftui cargoHash already set${NC}"
fi
echo

echo -e "${GREEN}🎉 Hash generation process completed!${NC}"
echo
echo -e "${YELLOW}📋 Summary:${NC}"
echo "  Source hash: sha256-DoDp5NQhk75t6wQAoVpU/+niBCNU5YG+E0WRiegIk7g="
[[ -n "${KFTRAY_CARGO_HASH:-}" ]] && echo "  kftray cargo hash: $KFTRAY_CARGO_HASH"
[[ -n "${KFTRAY_PNPM_HASH:-}" ]] && echo "  kftray pnpm hash: $KFTRAY_PNPM_HASH"
[[ -n "${KFTUI_CARGO_HASH:-}" ]] && echo "  kftui cargo hash: $KFTUI_CARGO_HASH"
echo
echo -e "${YELLOW}💡 To test the packages run:${NC}"
echo -e "${GREEN}  nix-build -A kftray${NC}"
echo -e "${GREEN}  nix-build -A kftui${NC}"
echo
echo -e "${YELLOW}📝 Note: You may need to run this script multiple times.${NC}"
echo -e "${YELLOW}   Each run will reveal and fix the next missing hash.${NC}"