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
    -Wno-deprecated-declarations \
    -Wno-unused-function

SleepMode_FRAMEWORKS = \
    UIKit \
    Foundation

SleepMode_PRIVATE_FRAMEWORKS = \
    SpringBoardUI \
    BackBoardServices


BUNDLE_NAME = SleepModePrefs

SleepModePrefs_BUNDLE_EXTENSION = bundle

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
    ../SleepModePrefs


include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk
include $(THEOS_MAKE_PATH)/package.mk
