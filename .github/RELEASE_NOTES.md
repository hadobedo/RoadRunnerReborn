## What's new in 1.1.1

- Apps that are meant to survive are captured more reliably.
- Survivor handoff data is now stored properly in a plist instead of the temp directory.
- Invalid survivor records are ignored instead of being restored.
- SpringBoard and runningboardd coordinate so they do not overwrite each other’s changes.
- Blacklist mode keeps its existing app list when iOS temporarily cannot provide a valid app list.
- Missing process information no longer causes SpringBoard to crash randomly.

## Install

A userspace reboot is required after installing or updating.

## Release files

- `com.nicksworks.roadrunnerreborn_1.1.1_iphoneos-arm64.deb` — rootless (arm64 + arm64e)
- `com.nicksworks.roadrunnerreborn_1.1.1_iphoneos-arm64e.deb` — RootHide (arm64e)
- `SHA256SUMS` — checksums for both packages
