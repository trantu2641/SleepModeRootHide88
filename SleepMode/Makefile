TARGET := iphone:clang:16.5:16.0

ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = roothide

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SleepMode

SleepMode_FILES = \
    Tweak.xm \
    SleepManager.m

SleepMode_CFLAGS = \
    -fobjc-arc \
    -Wno-unused-function \
    -Wno-deprecated-declarations

SleepMode_FRAMEWORKS = \
    UIKit \
    Foundation \
    CoreFoundation

SleepMode_PRIVATE_FRAMEWORKS = \
    SpringBoardUI \
    BackBoardServices \
    FrontBoardServices

include $(THEOS_MAKE_PATH)/tweak.mk

# =====================================================
# PACKAGE SETTINGS BUNDLE
# =====================================================

SleepModePrefs_PATH = ../SleepModePrefs

SleepModePrefs_MAKEFILE = $(SleepModePrefs_PATH)/Makefile

SUBPROJECTS += ../SleepModePrefs

include $(THEOS_MAKE_PATH)/aggregate.mk
include $(THEOS_MAKE_PATH)/package.mk

# =====================================================
# COPY PREFERENCELOADER ENTRY
# =====================================================

after-stage::
	@mkdir -p \
		$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences

	@cp \
		../SleepModePrefs/entry.plist \
		$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/SleepModePrefs.plist

	@echo ""
	@echo "================================"
	@echo "SLEEPMODE SETTINGS"
	@echo "================================"

	@plutil -lint \
		$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/SleepModePrefs.plist

	@echo ""
	@echo "PreferenceLoader:"
	@ls -lh \
		$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/ \
		2>/dev/null || true

	@echo ""
	@echo "PreferenceBundles:"
	@find \
		$(THEOS_STAGING_DIR)/Library/PreferenceBundles \
		-maxdepth 3 \
		-type f \
		-print 2>/dev/null || true
