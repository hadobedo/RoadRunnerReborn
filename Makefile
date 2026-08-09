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

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = RoadRunnerReborn

RoadRunnerReborn_FILES = Tweak.xm RRRSpringBoard.xm RRRRunningBoard.xm RRRState.m RRRLog.m RRRPreferences.m RRRIdentity.m RRRSurvivors.m
RoadRunnerReborn_CFLAGS = -fobjc-arc -Wno-vla-extension
# Private symbols (MediaRemote constants, daemon classes) resolve at runtime
RoadRunnerReborn_LDFLAGS = -undefined dynamic_lookup

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
