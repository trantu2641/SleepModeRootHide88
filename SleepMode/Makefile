TARGET := iphone:clang:16.5:16.0

include $(THEOS)/makefiles/common.mk


############################
# MAIN TWEAK
############################

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


############################
# CONTROL CENTER MODULE
############################

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
    ControlCenter/SleepModeModule.bundle


############################
# PROVIDER
############################

BUNDLE_NAME += SleepModeProvider

SleepModeProvider_BUNDLE_EXTENSION = bundle

SleepModeProvider_FILES =

SleepModeProvider_INSTALL_PATH = \
    /Library/ControlCenter/CCSupport_Providers

SleepModeProvider_BUNDLE_RESOURCE_DIRS = \
    ControlCenter/SleepModeProvider.bundle

SleepModeProvider_LDFLAGS = \
    -rpath /Library/ControlCenter/CCSupport_Providers


############################
# BUILD
############################

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk


############################
# PACKAGE
############################

ARCHS = arm64 arm64e

include $(THEOS_MAKE_PATH)/package.mk

THEOS_PACKAGE_SCHEME = roothide


############################
# COPY ORIGINAL PROVIDER
############################

after-SleepModeProvider-stage::
	@mkdir -p $(THEOS_STAGING_DIR)/Library/ControlCenter/CCSupport_Providers/SleepModeProvider.bundle
	@cp prebuilt/SleepModeProvider \
		$(THEOS_STAGING_DIR)/Library/ControlCenter/CCSupport_Providers/SleepModeProvider.bundle/SleepModeProvider
	@chmod 755 \
		$(THEOS_STAGING_DIR)/Library/ControlCenter/CCSupport_Providers/SleepModeProvider.bundle/SleepModeProvider
