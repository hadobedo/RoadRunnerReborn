#!/usr/bin/env bash
set -euo pipefail

: "${EXPECTED_ARCH:?EXPECTED_ARCH is required}"
: "${EXPECTED_VERSION:?EXPECTED_VERSION is required}"
: "${PACKAGE_SCHEME:?PACKAGE_SCHEME is required}"

packages=(packages/*.deb)
test "${#packages[@]}" -eq 1 || {
    printf 'expected exactly one package, found %s\n' "${#packages[@]}" >&2
    exit 1
}
package=${packages[0]}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/control" "$tmp/data"

package_abs=$(cd "$(dirname "$package")" && pwd)/$(basename "$package")
(
    cd "$tmp"
    ar x "$package_abs" >/dev/null
)
control_archive=$(find "$tmp" -maxdepth 1 -name 'control.tar.*' -print -quit)
data_archive=$(find "$tmp" -maxdepth 1 -name 'data.tar.*' -print -quit)
test -n "$control_archive" -a -n "$data_archive"
tar -xf "$control_archive" -C "$tmp/control"
tar -xf "$data_archive" -C "$tmp/data"

control_file="$tmp/control/control"
package_field() {
    awk -F': ' -v key="$1" '$1 == key { print substr($0, length(key) + 3); exit }' "$control_file"
}

actual_package=$(package_field Package)
actual_version=$(package_field Version)
actual_arch=$(package_field Architecture)
test "$actual_package" = com.nicksworks.roadrunnerreborn
test "$actual_version" = "$EXPECTED_VERSION"
test "$actual_arch" = "$EXPECTED_ARCH"
grep -F 'Depends: ' "$control_file" | grep -F 'ellekit' >/dev/null
grep -F 'Depends: ' "$control_file" | grep -F 'preferenceloader' >/dev/null
grep -F 'Depends: ' "$control_file" | grep -F 'com.opa334.altlist' >/dev/null
grep -F 'Conflicts: ' "$control_file" | grep -F 'com.nick.keepthepartygoing' >/dev/null
grep -F 'Replaces: ' "$control_file" | grep -F 'com.nick.keepthepartygoing' >/dev/null
grep -F 'Homepage: https://github.com/hadobedo/RoadRunnerReborn' "$control_file" >/dev/null
grep -F 'SileoDepiction: https://hadobedo.github.io/repo/depictions/com.nicksworks.roadrunnerreborn.json' "$control_file" >/dev/null
grep -F 'Depiction: https://hadobedo.github.io/repo/depictions/com.nicksworks.roadrunnerreborn.html' "$control_file" >/dev/null

if [ "$PACKAGE_SCHEME" = roothide ]; then
    test -d "$tmp/data/Library/MobileSubstrate/DynamicLibraries"
    test ! -e "$tmp/data/var/jb"
    expected_load='@loader_path/.jbroot/Library/Frameworks/AltList.framework/AltList'
else
    test -d "$tmp/data/var/jb/Library/MobileSubstrate/DynamicLibraries"
    expected_load='@rpath/AltList.framework/AltList'
fi

dylib=$(find "$tmp/data" -name RoadRunnerReborn.dylib -type f -print -quit)
daemon_dylib=$(find "$tmp/data" -name RoadRunnerRebornDaemon.dylib -type f -print -quit)
prefs=$(find "$tmp/data" -name RoadRunnerRebornPrefs -type f -print -quit)
test -n "$dylib" -a -n "$daemon_dylib" -a -n "$prefs"

require_architecture() {
    local file_path=$1
    local expected=$2
    local description=$3
    local output
    output=$(file "$file_path")
    case "$expected" in
        iphoneos-arm64)
            printf '%s\n' "$output" | grep -F 'Mach-O universal binary with 2 architectures:' >/dev/null || return 1
            printf '%s\n' "$output" | grep -F '[arm64:' >/dev/null || return 1
            printf '%s\n' "$output" | grep -F 'arm64e (caps:' >/dev/null || return 1
            return 0
            ;;
        iphoneos-arm64e)
            printf '%s\n' "$output" | grep -F 'Mach-O 64-bit arm64e (caps:' >/dev/null || return 1
            ! printf '%s\n' "$output" | grep -F 'universal binary' >/dev/null
            return 0
            ;;
    esac
    echo "$description has unexpected architecture: $output" >&2
    return 1
}
require_architecture "$dylib" "$EXPECTED_ARCH" RoadRunnerReborn
require_architecture "$daemon_dylib" "$EXPECTED_ARCH" RoadRunnerRebornDaemon
require_architecture "$prefs" "$EXPECTED_ARCH" RoadRunnerRebornPrefs

strings "$dylib" "$daemon_dylib" "$prefs" | grep -E 'RocketBootstrap|AppList\.framework|RBProcessManager.*executeTerminateRequest|RBSXPCMessage|posix_spawn|posix_spawnp|killpg' && {
    echo 'prohibited runtime reference found' >&2
    exit 1
} || true

otool_bin=${OTOOL:-$(command -v otool || true)}
if [ -z "$otool_bin" ] && [ -n "${THEOS:-}" ] && [ -x "$THEOS/toolchain/linux/iphone/bin/otool" ]; then
    otool_bin="$THEOS/toolchain/linux/iphone/bin/otool"
fi
test -n "$otool_bin" || { echo 'otool is required for Mach-O validation' >&2; exit 1; }
"$otool_bin" -L "$prefs" | grep -F "$expected_load" >/dev/null

# The runningboardd dylib is Foundation-only: UIKit/SpringBoard code must not
# load into a critical daemon.
if "$otool_bin" -L "$daemon_dylib" | grep -E 'UIKit|SpringBoard' >/dev/null; then
    echo 'daemon dylib must not reference UIKit/SpringBoard' >&2
    exit 1
fi

# Narrow filters: the SpringBoard dylib loads only into SpringBoard; the
# daemon dylib only into runningboardd.
sb_filter=$(find "$tmp/data" -path '*DynamicLibraries/RoadRunnerReborn.plist' -print -quit)
daemon_filter=$(find "$tmp/data" -path '*DynamicLibraries/RoadRunnerRebornDaemon.plist' -print -quit)
test -n "$sb_filter" -a -n "$daemon_filter"
grep -F 'com.apple.springboard' "$sb_filter" >/dev/null
! grep -F 'runningboardd' "$sb_filter" >/dev/null
grep -F 'runningboardd' "$daemon_filter" >/dev/null
! grep -F 'com.apple.springboard' "$daemon_filter" >/dev/null

postinst="$tmp/control/postinst"
postrm="$tmp/control/postrm"
test -x "$postinst" -a -x "$postrm"
grep -F 'finish:usreboot' "$postinst" >/dev/null
grep -F 'finish:usreboot' "$postrm" >/dev/null
! grep -F 'killall runningboardd' "$postinst" "$postrm" >/dev/null

echo "verified $package ($actual_package $actual_version $actual_arch, $PACKAGE_SCHEME)"
