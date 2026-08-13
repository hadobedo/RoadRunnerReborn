TARGET = iphone:clang:latest:15.0
ARCHS ?= arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = RoadRunnerRebornPrefs
RoadRunnerRebornPrefs_FILES = RRRRootListController.m RRRApplicationListController.m RRRLinksListController.m RRRCreditCells.m RRRModeSegmentCell.m RRRAdvancedListController.m ../RRRPolicy.m ../RRRPreferences.m
RoadRunnerRebornPrefs_INSTALL_PATH = /Library/PreferenceBundles
RoadRunnerRebornPrefs_FRAMEWORKS = UIKit
# Preferences is a private framework and is not shipped in the clean RootHide
# Theos checkout. Its symbols are resolved by the preference host at runtime.
RoadRunnerRebornPrefs_CFLAGS = -fobjc-arc -I$(THEOS)/vendor/include -I$(THEOS_PROJECT_DIR)/vendor/include -Wno-deprecated-declarations
# AltList is a runtime dependency, not vendored into this package. The project
# keeps only its public superclass header and a tiny linker stub so clean CI
# builds do not depend on an AltList SDK installed into Theos.
ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
RoadRunnerRebornPrefs_LDFLAGS = -undefined dynamic_lookup -F$(THEOS_PROJECT_DIR)/vendor/lib/iphone/roothide -framework AltList
else
RoadRunnerRebornPrefs_LDFLAGS = -undefined dynamic_lookup -F$(THEOS_PROJECT_DIR)/vendor/lib/iphone/rootless -framework AltList
endif

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/RoadRunnerReborn.plist$(ECHO_END)
