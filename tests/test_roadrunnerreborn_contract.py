#!/usr/bin/env python3
"""Contract checks for the shipping policy, preferences, package, and UI surface."""

from __future__ import annotations

import plistlib
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def run_policy_probe(project: Path) -> str:
    """Compile production RRRPolicy.m rather than maintaining a Python model."""
    if sys.platform != "darwin":
        return "runtime policy probe unavailable (Foundation probe requires macOS)"
    clang = shutil.which("clang")
    if not clang:
        return "runtime policy probe unavailable (clang not found)"
    probe = r'''
#import "RRRPolicy.h"
int main(void) {
    NSSet *listed = [NSSet setWithObject:@"com.example.Audio"];
    NSSet *universe = [NSSet setWithObjects:@"com.example.Audio", @"com.example.Other", nil];
    RRRPreferencesSnapshot *blacklist = [[RRRPreferencesSnapshot alloc]
        initWithEnabled:YES preserveNowPlaying:NO preserveOtherApps:YES whitelist:NO
        loggingEnabled:NO listedApps:listed appUniverse:universe];
    if (!RRRValidBundleID(@"com.example.Audio") || RRRValidBundleID(@"bad")) return 1;
    if (![blacklist preservesBundleIdentifier:@"com.example.Other"]) return 2;
    if ([blacklist preservesBundleIdentifier:@"com.example.Audio"]) return 3;
    if ([blacklist preservesBundleIdentifier:@"com.apple.InCallService"]) return 4;
    RRRPreferencesSnapshot *media = [[RRRPreferencesSnapshot alloc]
        initWithEnabled:YES preserveNowPlaying:YES preserveOtherApps:NO whitelist:YES
        loggingEnabled:NO listedApps:[NSSet set] appUniverse:[NSSet set]];
    if ([media preservesBundleIdentifier:@"com.example.Audio"]) return 5;
    return 0;
}
'''
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        source = root / "policy_probe.m"
        binary = root / "policy_probe"
        source.write_text(probe, encoding="utf-8")
        command = [clang, "-fobjc-arc", "-framework", "Foundation", "-I", str(project),
                   str(source), str(project / "RRRPolicy.m"), "-o", str(binary)]
        compile_result = subprocess.run(command, cwd=project, text=True, capture_output=True)
        if compile_result.returncode:
            raise AssertionError(f"policy probe compile failed:\n{compile_result.stderr}")
        run_result = subprocess.run([str(binary)], cwd=project, text=True, capture_output=True)
        if run_result.returncode:
            raise AssertionError(f"policy probe failed with {run_result.returncode}: {run_result.stderr}")
    return "compiled and ran production RRRPolicy.m probe"


def main():
    project = Path(__file__).resolve().parents[1]
    policy = (project / "RRRPolicy.m").read_text()
    identity = (project / "RRRIdentity.m").read_text()
    preferences = (project / "RRRPreferences.m").read_text()
    assert "RRRValidBundleID" in policy
    assert "RRRNeverPreserveBundleID" in policy
    assert "RRRPreferencesSnapshot" in policy
    assert "[object valueForKey:" not in identity
    assert "respondsToSelector:selector" in identity
    assert "#import \"RRRPolicy.h\"" in (project / "RRRPreferences.h").read_text()
    assert "performSelector:@selector(defaultWorkspace)" in preferences
    assert "respondsToSelector:@selector(allApplications)" in preferences
    assert "respondsToSelector:@selector(bundleIdentifier)" in preferences
    assert "@catch (__unused NSException *exception)" in preferences
    assert "freshUniverse.count > 0 ? freshUniverse : RRRStoredAppUniverse(current)" in preferences
    assert "/tmp/roadrunnerreborn-survivors.plist" not in (project / "RRRSurvivors.m").read_text()
    survivors = (project / "RRRSurvivors.m").read_text()
    assert "O_EXCL | O_NOFOLLOW" in survivors
    assert "for (NSString *payloadPath in RRRSurvivorPaths())" in survivors
    assert "0600" in survivors and "fsync(fd)" in survivors
    assert '"revision"' in survivors
    assert "RRRSurvivorsFilePath" in (project / "RRRSurvivors.h").read_text()

    root = plistlib.loads((project / "Preferences/Resources/Root.plist").read_bytes())
    app_row = next(item for item in root["items"] if item.get("id") == "listedApps")
    assert app_row["cell"] == "PSLinkCell"
    assert app_row["detail"] == "RRRApplicationListController"
    assert "defaults" not in app_row and "key" not in app_row and "PostNotification" not in app_row
    mode_row = next(item for item in root["items"] if item.get("id") == "isWhitelist")
    assert mode_row["cell"] == "PSLinkCell"
    assert mode_row["cellClass"] == "RRRModeSegmentCell"
    assert mode_row["validTitles"] == ["Whitelist", "Blacklist"]
    assert mode_row["validValues"] == [True, False]
    enabled_row = next(item for item in root["items"] if item.get("id") == "enabled")
    assert enabled_row["cell"] == "PSSwitchCell" and enabled_row["default"] is True
    other_apps_footer = next(item for item in root["items"] if item.get("label") == "Other Apps")["footerText"]
    assert "Whitelist" in other_apps_footer and "Blacklist" in other_apps_footer
    assert "loggingEnabled" not in [item.get("id") for item in root["items"]]
    advanced_row = next(item for item in root["items"] if item.get("id") == "advancedMenu")
    assert advanced_row["detail"] == "RRRAdvancedListController"
    advanced = plistlib.loads((project / "Preferences/Resources/Advanced.plist").read_bytes())
    logging_row = next(item for item in advanced["items"] if item.get("id") == "loggingEnabled")
    assert logging_row["cell"] == "PSSwitchCell" and logging_row["default"] is False
    assert logging_row["key"] == "loggingEnabled"
    assert advanced["title"] == "Advanced"
    assert root["title"] == "RoadRunner Reborn"
    credits = {item.get("id"): item for item in root["items"] if item.get("id") in ("nicksWorksMenu", "originalRoadRunner")}
    assert set(credits) == {"nicksWorksMenu", "originalRoadRunner"}
    assert credits["nicksWorksMenu"]["detail"] == "RRRLinksListController"
    assert credits["nicksWorksMenu"]["cellClass"] == "RRRProfileLinkCell"
    assert credits["originalRoadRunner"]["cellClass"] == "RRROriginalLinkCell"
    assert "detail" not in credits["originalRoadRunner"]
    assert credits["nicksWorksMenu"]["subtitle"]
    assert credits["originalRoadRunner"]["subtitle"]
    controller = (project / "Preferences/RRRApplicationListController.m").read_text()
    assert "- (void)loadPreferences" in controller
    assert "- (void)savePreferences" in controller
    assert "RRRPreferencesWrite" in controller

    makefile = (project / "Makefile").read_text()
    assert "TWEAK_NAME += RoadRunnerRebornDaemon" in makefile
    assert "RRRPolicy.m" in makefile
    assert "RoadRunnerRebornDaemon_FILES" in makefile
    assert "RRRRunningBoard.xm" in makefile and "RRRSpringBoard.xm" in makefile
    # A11 devices (iPhone 8/X) execute arm64 only; arm64e-only builds must be rejected.
    assert '$(error ARCHS must include arm64' in makefile
    sb_filter = (project / "RoadRunnerReborn.plist").read_text()
    daemon_filter = (project / "RoadRunnerRebornDaemon.plist").read_text()
    assert "com.apple.springboard" in sb_filter and "runningboardd" not in sb_filter
    assert "runningboardd" in daemon_filter and "com.apple.springboard" not in daemon_filter
    assert "RRRReplaceSurvivorRecords" in (project / "RRRSurvivors.h").read_text()
    assert "RRRNeverPreserveBundleID" in (project / "RRRPreferences.h").read_text()
    for icon in ("icon_github.png", "icon_kofi.png", "icon_x.png", "icon_instagram.png", "icon_youtube.png"):
        assert (project / "Preferences/Resources" / icon).stat().st_size > 0

    notes = project / ".github/RELEASE_NOTES.md"
    assert notes.exists()
    assert "from release_notes import validate" in (project / "scripts/render_repo_depiction.py").read_text()
    depiction = (project / "scripts/render_repo_depiction.py").read_text()
    # Counters are cumulative: GitHub /total sums every release's assets
    # (all versions, rootless + RootHide) and the visitor badge is keyed
    # only by the constant page-id.
    assert "{repo}/latest/total" not in depiction
    assert 'github/downloads/{repo}/total?label=Downloads' in depiction
    assert 'badge?page_id={page}' in depiction
    assert "--release-notes" in (project / "scripts/publish_repo.sh").read_text()
    publish_script = (project / "scripts/publish_repo.sh").read_text()
    # Dev publishes render into the dev subdirectory and rewrite the dev
    # package index to point at it; the stable depiction is only touched
    # by stable publishes.
    assert 'render_depiction "$FEED_DIR/depictions"' in publish_script
    assert 'render_depiction "$repo_root/depictions"' in publish_script
    assert 'cp "$repo_root/depictions/$package.json"' not in publish_script
    assert 'https://hadobedo.github.io/repo/dev/depictions/' in publish_script
    assert "tests/**" in (project / ".github/workflows/build.yml").read_text()
    assert "tests/**" in (project / ".github/workflows/publish.yml").read_text()
    # Both variants ship universal arm64 + arm64e binaries so A11 devices
    # can load the package; the roothide deb keeps iphoneos-arm64e.
    for workflow in (project / ".github/workflows/build.yml", project / ".github/workflows/publish.yml"):
        workflow_text = workflow.read_text()
        assert 'scheme: roothide\n            archs: "arm64 arm64e"' in workflow_text
        assert 'expected_arch: iphoneos-arm64e' in workflow_text
    verify = (project / "scripts/verify_package.sh").read_text()
    assert "require_architecture" in verify
    # Every shipped Mach-O must carry both slices, regardless of package arch.
    assert '"arm64 arm64e")' in verify
    assert 'test "$architectures" = arm64e' not in verify
    publish = (project / ".github/workflows/publish.yml").read_text()
    assert "ssh-keyscan" not in publish and "github.com ssh-ed25519" in publish

    print(run_policy_probe(project))
    print("RoadRunner Reborn settings/policy/survivor/UI contract checks passed")


if __name__ == "__main__":
    main()
