#!/usr/bin/env bash
# Prepare a release: bump control, rename the release-notes header and
# release-file names, run the project checks, commit, and tag locally.
# Pushing is left to the operator (see the printed steps).
# Usage: scripts/release.sh 1.1.3
set -euo pipefail

cd "$(dirname "$0")/.."

new_version=${1:?usage: $0 <version>}
tag="v$new_version"

test -z "$(git status --porcelain)" || {
    echo 'working tree must be clean before a release' >&2
    exit 1
}
branch=$(git branch --show-current)
case "$branch" in
    development|main) ;;
    *) echo "refusing to release from branch '$branch' (expected development or main)" >&2
       exit 1 ;;
esac

old_version=$(awk '$1 == "Version:" && NF == 2 { print $2 }' control)
test -n "$old_version"
[ "$old_version" != "$new_version" ] || {
    echo "control is already at $new_version" >&2
    exit 1
}

sed -i "s/^Version: .*/Version: $new_version/" control
sed -i "s/^## $old_version$/## $new_version/" .github/RELEASE_NOTES.md
sed -i "s/_${old_version}_iphoneos-arm64/_${new_version}_iphoneos-arm64/g" .github/RELEASE_NOTES.md
sed -i "s/_${old_version}_iphoneos-arm64e/_${new_version}_iphoneos-arm64e/g" .github/RELEASE_NOTES.md

python3 scripts/release_notes.py .github/RELEASE_NOTES.md --expected-version "$new_version"
python3 tests/test_roadrunnerreborn_contract.py >/dev/null

git add control .github/RELEASE_NOTES.md
git commit -m "Prepare RoadRunner Reborn $new_version release"
git tag -a "$tag" -m "RoadRunner Reborn $new_version"

cat <<EOF
Release $new_version prepared and tagged as $tag (not pushed).

If the changelog bullets in .github/RELEASE_NOTES.md are not final yet,
amend the commit before pushing. When ready:

  git push origin development
  git push origin development:main
  git push origin $tag
EOF
