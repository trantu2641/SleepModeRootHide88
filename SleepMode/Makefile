TARGET := iphone:clang:16.5:16.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SleepMode

SleepMode_FILES = Tweak.xm SleepManager.m

SleepMode_CFLAGS = -fobjc-arc

SleepMode_FRAMEWORKS = UIKit Foundation CoreFoundation

SleepMode_PRIVATE_FRAMEWORKS = SpringBoardUI BackBoardServices FrontBoardServices

include $(THEOS_MAKE_PATH)/tweak.mk

ARCHS = arm64

include $(THEOS_MAKE_PATH)/package.mk

THEOS_PACKAGE_SCHEME = roothide
