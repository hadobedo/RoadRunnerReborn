## What's new in 1.1.0

- Apps that are meant to survive a respring are captured more reliably.
- The Phone app, call UI, and Spotlight are no longer kept alive, so they should not get stuck after a respring.
- Blacklist mode only preserves apps shown in the app list, except for apps you blacklisted.
- Stale Now Playing entries are cleared instead of reused.
- SpringBoard and runningboardd now use separate, smaller hooks, with better logging when loading or capturing goes wrong.

## Install

A userspace reboot is required after installing or updating.

## Release files

- `com.nicksworks.roadrunnerreborn_1.1.0_iphoneos-arm64.deb` — rootless (arm64 + arm64e)
- `com.nicksworks.roadrunnerreborn_1.1.0_iphoneos-arm64e.deb` — RootHide (arm64e)
- `SHA256SUMS` — checksums for both packages
