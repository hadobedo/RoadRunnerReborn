## 1.2.1

- Fixes preferences being silently discarded. Settings were written two ways to the same plist: the main toggles with `-writeToFile:` and the new simultaneous-audio settings through `CFPreferences`. cfprefsd keeps its own cache of the domain, so the next audio write flushed that cache over the file and wiped `enabled`, `preserveNowPlaying`, `isWhitelist` and the app list. Both features then behaved as "off".
- All preference reads and writes now go through `CFPreferences`, so every process (SpringBoard, runningboardd, mediaserverd, audiomxd, apps) sees the same values.
- If you upgraded to 1.2.0, your toggles were reset; set them once after installing 1.2.1.

## 1.2.0

- Adds an optional **Allow Simultaneous Audio** setting with an independent per-app whitelist or blacklist so eligible third-party media apps can remain audible together.
- Preserves native Lock Screen and Control Center Now Playing ownership for long-form media such as YouTube and Spotify.
- Replaces the standalone ProBrainRot package; the feature is now built into RoadRunner Reborn and disabled by default.

## Install

A userspace reboot is required after installing or updating. Restart affected media apps after changing the simultaneous-audio setting.

## Release files

- `com.nicksworks.roadrunnerreborn_1.2.1_iphoneos-arm64.deb` — rootless (arm64 + arm64e)
- `com.nicksworks.roadrunnerreborn_1.2.1_iphoneos-arm64e.deb` — RootHide (arm64 + arm64e)
- `SHA256SUMS` — checksums for both packages
