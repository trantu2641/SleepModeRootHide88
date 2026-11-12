##################################################
# GLOBAL CONFIGURATION
##################################################

TARGET := iphone:clang:16.5:16.0

ARCHS = arm64 arm64e

THEOS_PACKAGE_SCHEME = roothide

include $(THEOS)/makefiles/common.mk


##################################################
# MAIN TWEAK
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
    -Wno-deprecated-declarations

SleepModeModule_FRAMEWORKS = \
    UIKit \
    Foundation

SleepModeModule_INSTALL_PATH = \
    /Library/ControlCenter/Bundles

# ĐƯỜNG DẪN ĐÚNG
# Makefile nằm trong SleepMode/
# ControlCenter nằm ngang hàng với SleepMode/

SleepModeModule_BUNDLE_RESOURCE_DIRS = \
    ../ControlCenter/SleepModeModule.bundle


##################################################
# CONTROL CENTER PROVIDER
##################################################

BUNDLE_NAME += SleepModeProvider

SleepModeProvider_BUNDLE_EXTENSION = bundle

SleepModeProvider_FILES = \
    ../SleepModeProvider/SleepModeProvider.m

SleepModeProvider_CFLAGS = \
    -fobjc-arc \
    -Wno-deprecated-declarations

SleepModeProvider_FRAMEWORKS = \
    UIKit \
    Foundation

SleepModeProvider_INSTALL_PATH = \
    /Library/ControlCenter/CCSupport_Providers

# ĐƯỜNG DẪN ĐÚNG

SleepModeProvider_BUNDLE_RESOURCE_DIRS = \
    ../ControlCenter/SleepModeProvider.bundle


##################################################
# BUILD TWEAK
##################################################

include $(THEOS_MAKE_PATH)/tweak.mk


##################################################
# BUILD BUNDLES
##################################################

include $(THEOS_MAKE_PATH)/bundle.mk


##################################################
# PACKAGE
##################################################

include $(THEOS_MAKE_PATH)/package.mk
