# Project map

## Shipping surface

| File | Responsibility |
| --- | --- |
| `RoadRunnerReborn.plist` | Narrow ElleKit filter for SpringBoard; `RoadRunnerRebornDaemon.plist` separately filters `runningboardd`. |
| `Tweak.xm` | SpringBoard entry and conditional Now Playing eligibility override. |
| `RRRSpringBoard.xm` | Media tracking, settings changes, state/notify publication, survivor consumption, FrontBoard reattachment, and media restoration. |
| `RRRRunningBoard.xm` | Sole `RBProcess -terminateWithContext:` survival boundary. |
| `RRRPreferences.*` | Validated independent settings snapshot and atomic writer. |
| `RRRState.*` | New clean-break Now Playing state plist. |
| `RRRIdentity.*` | Optional process-start identity lookup. |
| `RRRSurvivors.*` | Secure, generation/revision-stamped root/hosted-child record transport under the mobile preferences directory. |
| `RRRLog.*` | `/var/mobile/roadrunnerreborn.log` and `/tmp/roadrunnerreborn.log`. |
| `Preferences/` | RoadRunnerReborn PreferenceLoader/AltList main page and direct credits. |
| `layout/DEBIAN/postinst` | Sileo-only userspace reboot request. |

## Namespaces

```text
package:       com.nicksworks.roadrunnerreborn
preferences:   com.nicksworks.roadrunnerreborn.preferences.plist
state:         com.nicksworks.roadrunnerreborn.state.plist
survivors:     /var/mobile/Library/Preferences/com.nicksworks.roadrunnerreborn.survivors.plist
notifications: com.nicksworks.roadrunnerreborn.*
```

The old package/domain is not read or migrated. `control` declares `Conflicts` and `Replaces` so both tweak filters cannot remain installed.

## Preference semantics

`enabled` defaults on and is the master preservation gate. `preserveNowPlaying` defaults on and controls only media tuple publication, media flags, restoration notifications, and the iOS 16–17 eligibility override. `preserveOtherApps` defaults off and controls whitelist/blacklist preservation of embedded application roots. The mode/list rows are disabled while Preserve Other Apps is off without deleting saved values.

The AltList parent row uses `defaults=com.nicksworks.roadrunnerreborn.preferences` and `key=listedApps`, with no array-valued `get` or `default` preview. This keeps the root row at normal height while the child controller owns selection state.

## Attribution

RoadRunner by Nosskirneh is the original reference and source of the survival architecture. RoadRunner Reborn is a modern rootless port/rewrite by Nick's Works. `RoadRunner/` is reference-only and is not packaged.
