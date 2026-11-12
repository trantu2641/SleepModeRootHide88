TARGET := iphone:clang:16.5:16.0

include $(THEOS)/makefiles/common.mk


##################################################
# SLEEPMODE TWEAK
##################################################

TWEAK_NAME = SleepMode

SleepMode_FILES = \
    Tweak.xm \
    SleepManager.m \
    SleepControlCenter.m

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


##################################################
# CONTROL CENTER MODULE
##################################################

BUNDLE_NAME = SleepModeModule

SleepModeModule_BUNDLE_EXTENSION = bundle

SleepModeModule_FILES = \
    SleepModeModule.m

SleepModeModule_CFLAGS = \
    -fobjc-arc \
    -Wno-unused-function \
    -Wno-deprecated-declarations

SleepModeModule_FRAMEWORKS = \
    UIKit \
    Foundation

SleepModeModule_INSTALL_PATH = \
    /Library/ControlCenter/Bundles

SleepModeModule_BUNDLE_RESOURCE_DIRS = \
    ControlCenter/SleepModeModule.bundle


##################################################
# CONTROL CENTER PROVIDER
##################################################

BUNDLE_NAME += SleepModeProvider

SleepModeProvider_BUNDLE_EXTENSION = bundle

SleepModeProvider_FILES = \
    ../SleepModeProvider/SleepModeProvider.m

SleepModeProvider_CFLAGS = \
    -fobjc-arc \
    -Wno-unused-function \
    -Wno-deprecated-declarations

SleepModeProvider_FRAMEWORKS = \
    UIKit \
    Foundation

SleepModeProvider_INSTALL_PATH = \
    /Library/ControlCenter/CCSupport_Providers

SleepModeProvider_BUNDLE_RESOURCE_DIRS = \
    ControlCenter/SleepModeProvider.bundle


##################################################
# BUILD
##################################################

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk


##################################################
# PACKAGE
##################################################

ARCHS = arm64 arm64e

include $(THEOS_MAKE_PATH)/package.mk

THEOS_PACKAGE_SCHEME = roothide
