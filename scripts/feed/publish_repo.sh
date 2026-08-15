#!/usr/bin/env bash
set -euo pipefail

: "${FEED_DIR:?FEED_DIR is required}"
: "${RELEASE_VERSION:?RELEASE_VERSION is required}"
: "${ROOTLESS_DEB:?ROOTLESS_DEB is required}"
: "${ROOTHIDE_DEB:?ROOTHIDE_DEB is required}"

source_root=${SOURCE_ROOT:-$(pwd)}
package=com.nicksworks.roadrunnerreborn
repo_root="$FEED_DIR"
if [ "$(basename "$FEED_DIR")" = dev ]; then
    repo_root="$(dirname "$FEED_DIR")"
fi
mkdir -p "$repo_root/assets" "$repo_root/depictions" \
    "$FEED_DIR/assets" "$FEED_DIR/depictions" \
    "$FEED_DIR/debs" "$FEED_DIR/rootless/debs" "$FEED_DIR/roothide/debs"

cp "$ROOTLESS_DEB" "$FEED_DIR/debs/"
cp "$ROOTHIDE_DEB" "$FEED_DIR/debs/"
cp "$ROOTLESS_DEB" "$FEED_DIR/rootless/debs/"
cp "$ROOTHIDE_DEB" "$FEED_DIR/roothide/debs/"

render_depiction() {
    local output_dir=$1
    mkdir -p "$output_dir"
    python3 "$source_root/scripts/feed/depiction.py" render \
    --output-dir "$output_dir" \
    --package "$package" \
    --name 'RoadRunner Reborn' \
    --version "$RELEASE_VERSION" \
    --page-id 'hadobedo.github.io/repo/depictions/com.nicksworks.roadrunnerreborn' \
    --github-repository 'hadobedo/RoadRunnerReborn' \
    --release-notes "$source_root/.github/RELEASE_NOTES.md"
}
# Dev publishes must not overwrite the stable depiction: render into the
# dev subdirectory and point the dev package index at it.
if [ "$FEED_DIR" != "$repo_root" ]; then
    render_depiction "$FEED_DIR/depictions"
else
    render_depiction "$repo_root/depictions"
fi

# Keep the existing dotto++ depiction counters current when this feed is
# published from either product's workflow.
for dotto_dir in "$repo_root" "$FEED_DIR"; do
    if [ -f "$dotto_dir/depictions/com.nicksworks.dottoplusplus.json" ] && [ -f "$dotto_dir/depictions/com.nicksworks.dottoplusplus.html" ]; then
        python3 "$source_root/scripts/feed/depiction.py" counters \
            --json "$dotto_dir/depictions/com.nicksworks.dottoplusplus.json" \
            --html "$dotto_dir/depictions/com.nicksworks.dottoplusplus.html" \
            --page-id 'hadobedo.github.io/repo/depictions/com.nicksworks.dottoplusplus' \
            --github-repository 'hadobedo/dotto-'
    fi
done

write_index() {
    local directory=$1
    local architectures=$2
    local codename=$3
    local dev_depictions=${4:-}
    (
        cd "$directory"
        dpkg-scanpackages -m debs /dev/null > Packages
        if [ -n "$dev_depictions" ]; then
            python3 "$source_root/scripts/feed/depiction.py" rewrite-dev "$package" Packages
        fi
        gzip -9c Packages > Packages.gz
        xz -9c Packages > Packages.xz
        {
            printf 'Origin: Nicks Works\n'
            printf 'Label: Nicks Works\n'
            printf 'Suite: stable\n'
            printf 'Codename: %s\n' "$codename"
            printf 'Architectures: %s\n' "$architectures"
            printf 'Components: main\n'
            printf 'Description: Nicks Works jailbreak tweaks\n'
            printf 'MD5Sum:\n'
            while read -r hash file; do
                printf ' %s %s %s\n' "$hash" "$(stat -c '%s' "$file" 2>/dev/null || stat -f '%z' "$file")" "$file"
            done < <(md5sum Packages Packages.gz Packages.xz)
            printf 'SHA256:\n'
            while read -r hash file; do
                printf ' %s %s %s\n' "$hash" "$(stat -c '%s' "$file" 2>/dev/null || stat -f '%z' "$file")" "$file"
            done < <(sha256sum Packages Packages.gz Packages.xz)
        } > Release
    )
}

if [ "$FEED_DIR" != "$repo_root" ]; then
    write_index "$FEED_DIR" 'iphoneos-arm64 iphoneos-arm64e' stable dev
    write_index "$FEED_DIR/rootless" iphoneos-arm64 rootless dev
    write_index "$FEED_DIR/roothide" iphoneos-arm64e roothide dev
else
    write_index "$FEED_DIR" 'iphoneos-arm64 iphoneos-arm64e' stable
    write_index "$FEED_DIR/rootless" iphoneos-arm64 rootless
    write_index "$FEED_DIR/roothide" iphoneos-arm64e roothide
fi

sha256sum "$FEED_DIR/rootless/debs/$(basename "$ROOTLESS_DEB")" > "$FEED_DIR/rootless/SHA256SUMS"
sha256sum "$FEED_DIR/roothide/debs/$(basename "$ROOTHIDE_DEB")" > "$FEED_DIR/roothide/SHA256SUMS"
printf '%s\n' "$RELEASE_VERSION" > "$FEED_DIR/LATEST"
