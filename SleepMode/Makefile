TARGET := iphone:clang:16.5:16.0

include $(THEOS)/makefiles/common.mk


# ==========================================
# SleepMode TWEAK
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
# Control Center MODULE
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


# ==========================================
# BUILD
# ==========================================

include $(THEOS_MAKE_PATH)/tweak.mk

include $(THEOS_MAKE_PATH)/bundle.mk

ARCHS = arm64

include $(THEOS_MAKE_PATH)/package.mk

THEOS_PACKAGE_SCHEME = roothide
