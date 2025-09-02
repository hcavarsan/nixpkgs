#!/usr/bin/env nix-shell
#!nix-shell -i bash -p bash nix-update common-updater-scripts nix jq

set -euo pipefail

BASEDIR="$(dirname "$0")/../../../.."

currentVersion=$(nix-instantiate --eval -E "with import $BASEDIR {}; kftray.version or (lib.getVersion kftray)" | tr -d '"')
latestVersion=$(curl ${GITHUB_TOKEN:+-u ":$GITHUB_TOKEN"} -sL https://api.github.com/repos/hcavarsan/kftray/releases/latest | jq --raw-output .tag_name | sed 's/^v//')

if [[ "$currentVersion" == "$latestVersion" ]]; then
    echo "package is up-to-date: $currentVersion"
    exit 0
fi

update-source-version kftray $latestVersion || true

for system in \
    x86_64-linux \
    aarch64-linux \
    x86_64-darwin \
    aarch64-darwin; do
    hash=$(nix --extra-experimental-features nix-command hash convert --to sri --hash-algo sha256 $(nix-prefetch-url $(nix-instantiate --eval -E "with import $BASEDIR {}; kftray.src.url" --system "$system" | tr -d '"')))
    (cd $BASEDIR && update-source-version kftray $latestVersion $hash --system=$system --ignore-same-version)
done