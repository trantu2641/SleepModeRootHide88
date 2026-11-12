TARGET := iphone:clang:16.5:16.0

ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = roothide

include $(THEOS)/makefiles/common.mk


BUNDLE_NAME = SleepModePrefs

SleepModePrefs_FILES = \
    SleepModePrefs.m

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
    Resources

include $(THEOS_MAKE_PATH)/bundle.mk
include $(THEOS_MAKE_PATH)/package.mk
