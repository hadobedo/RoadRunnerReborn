TARGET := iphone:clang:latest:15.0
# Default to rootless; override THEOS_PACKAGE_SCHEME=roothide for roothide builds.
THEOS_PACKAGE_SCHEME ?= rootless
ARCHS ?= arm64 arm64e
SUBPROJECTS += Preferences

# RootHide's macOS toolchain needs ad-hoc codesigning for injected binaries.
ifeq ($(shell uname -s),Darwin)
TARGET_CODESIGN = /usr/bin/codesign
TARGET_CODESIGN_FLAGS = -f -s -
endif

include $(THEOS)/makefiles/common.mk

# SpringBoard dylib: media tracking, survivor restoration, and FrontBoard
# reattachment. UIKit/SpringBoard code never loads into runningboardd.
TWEAK_NAME = RoadRunnerReborn
RoadRunnerReborn_FILES = Tweak.xm RRRSpringBoard.xm RRRState.m RRRLog.m RRRPreferences.m RRRIdentity.m RRRSurvivors.m
RoadRunnerReborn_CFLAGS = -fobjc-arc -Wno-vla-extension
# Private symbols (MediaRemote constants, daemon classes) resolve at runtime
RoadRunnerReborn_LDFLAGS = -undefined dynamic_lookup

# runningboardd dylib: Foundation-only termination boundary. It is injected
# into a critical daemon, so it contains no UIKit/SpringBoard code. A respring
# cannot unload it; installing, updating, disabling, or removing requires a
# userspace reboot (requested through the Sileo finish:usreboot postinst path).
TWEAK_NAME += RoadRunnerRebornDaemon
RoadRunnerRebornDaemon_FILES = RRRRunningBoard.xm RRRState.m RRRLog.m RRRPreferences.m RRRIdentity.m RRRSurvivors.m
RoadRunnerRebornDaemon_CFLAGS = -fobjc-arc -Wno-vla-extension
RoadRunnerRebornDaemon_LDFLAGS = -undefined dynamic_lookup

# Restarting SpringBoard after install does not reload runningboardd; the
# daemon dylib is unloaded only by a userspace reboot. We never kill the
# daemon directly.
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
