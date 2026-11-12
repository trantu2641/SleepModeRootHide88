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
include $(THEOS_MAKE_PATH)/package.mk
