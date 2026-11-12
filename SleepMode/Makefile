TARGET := iphone:clang:16.5:16.0

include $(THEOS)/makefiles/common.mk


# ==========================================
# TWEAK
# ==========================================

TWEAK_NAME = SleepMode

SleepMode_FILES = \
    Tweak.xm \
    SleepManager.m \
    SleepControlCenter.m

SleepMode_CFLAGS = \
    -fobjc-arc

SleepMode_FRAMEWORKS = \
    UIKit \
    Foundation \
    CoreFoundation

SleepMode_PRIVATE_FRAMEWORKS = \
    SpringBoardUI \
    BackBoardServices \
    FrontBoardServices


# ==========================================
# CONTROL CENTER MODULE
# ==========================================

BUNDLE_NAME = SleepModeModule

SleepModeModule_BUNDLE_EXTENSION = bundle

SleepModeModule_FILES = \
    SleepModeModule.m

SleepModeModule_CFLAGS = \
    -fobjc-arc

SleepModeModule_FRAMEWORKS = \
    UIKit \
    Foundation

SleepModeModule_INSTALL_PATH = \
    /Library/ControlCenter/Bundles

SleepModeModule_BUNDLE_RESOURCE_DIRS = \
    ../ControlCenter/SleepModeModule.bundle


# ==========================================
# BUILD
# ==========================================

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk

ARCHS = arm64 arm64e

include $(THEOS_MAKE_PATH)/package.mk

THEOS_PACKAGE_SCHEME = roothide
