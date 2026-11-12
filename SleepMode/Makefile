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


SUBPROJECTS += SleepModePrefs


include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
include $(THEOS_MAKE_PATH)/package.mk


after-stage::
	@mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences

	@cp ../SleepModePrefs/entry.plist \
		$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/SleepModePrefs.plist

	@echo ""
	@echo "===== SLEEPMODE PREFS ====="

	@find $(THEOS_STAGING_DIR)/Library/PreferenceBundles \
		-maxdepth 2 \
		-type f \
		-print 2>/dev/null || true

	@echo ""
	@echo "===== PREFERENCELOADER ====="

	@ls -lh \
		$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/ \
		2>/dev/null || true
