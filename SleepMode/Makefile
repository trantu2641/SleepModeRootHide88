TARGET := iphone:clang:16.5:16.0

ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = roothide

include $(THEOS)/makefiles/common.mk


# =====================================================
# SLEEPMODE TWEAK
# =====================================================

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


# =====================================================
# SLEEPMODE PREFERENCE BUNDLE
# =====================================================

BUNDLE_NAME = SleepModePrefs

SleepModePrefs_FILES = \
    ../SleepModePrefs/SleepModePrefs.m

SleepModePrefs_CFLAGS = \
    -fobjc-arc \
    -Wno-deprecated-declarations

SleepModePrefs_FRAMEWORKS = \
    UIKit \
    Foundation

SleepModePrefs_PRIVATE_FRAMEWORKS = \
    Preferences

SleepModePrefs_INSTALL_PATH = \
    /Library/PreferenceBundles

SleepModePrefs_RESOURCE_DIRS = \
    ../SleepModePrefs/Resources


# =====================================================
# PACKAGE
# =====================================================

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk
include $(THEOS_MAKE_PATH)/package.mk


# =====================================================
# PREFERENCELOADER ENTRY
# =====================================================

after-stage::
	@mkdir -p \
		$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences

	@cp \
		../SleepModePrefs/entry.plist \
		$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/SleepModePrefs.plist

	@echo ""
	@echo "========================================"
	@echo "SLEEPMODE PREFERENCELOADER"
	@echo "========================================"

	@ls -lh \
		$(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/SleepModePrefs.plist

	@echo ""
