TARGET := iphone:clang:16.5:16.0

ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = roothide

include $(THEOS)/makefiles/common.mk

# The 1.1.0 core is shipped as a prebuilt, untouched binary.
# This helper only forwards Settings changes into the live SleepManager.
TWEAK_NAME = SleepModeSettingsBridge

SleepModeSettingsBridge_FILES = \
    Tweak.xm

SleepModeSettingsBridge_CFLAGS = \
    -fobjc-arc \
    -Wno-deprecated-declarations

SleepModeSettingsBridge_FRAMEWORKS = \
    UIKit \
    Foundation \
    CoreFoundation

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/package.mk

after-stage::
	@mkdir -p $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries
	@cp prebuilt/SleepMode.dylib $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/SleepMode.dylib
	@cp prebuilt/SleepMode.plist $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/SleepMode.plist

	@mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences
	@cp ../SleepModePrefs/entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/SleepModePrefs.plist
