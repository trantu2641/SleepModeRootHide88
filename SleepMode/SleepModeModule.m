#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>

static NSString * const SleepModeEnabledKey =
    @"SleepModeEnabled";

static NSString * const SleepModeCommandNotification =
    @"com.trantu.sleepmode.command";

static NSString * const SleepModeStateChangedNotification =
    @"com.trantu.sleepmode.stateChanged";


#pragma mark - Load ControlCenterUI

static Class SleepModeGetCCUIToggleModule(void)
{
    Class cls = NSClassFromString(@"CCUIToggleModule");

    if (cls != Nil) {
        return cls;
    }

    void *handle = dlopen(
        "/System/Library/PrivateFrameworks/ControlCenterUI.framework/ControlCenterUI",
        RTLD_LAZY | RTLD_LOCAL
    );

    if (handle != NULL) {
        cls = NSClassFromString(@"CCUIToggleModule");
    }

    return cls;
}


#pragma mark - Runtime Methods

static BOOL SleepModeIsSelected(id self, SEL _cmd)
{
    return [[NSUserDefaults standardUserDefaults]
            boolForKey:SleepModeEnabledKey];
}


static void SleepModeSetSelected(id self, SEL _cmd, BOOL selected)
{
    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    [defaults setBool:selected
              forKey:SleepModeEnabledKey];

    [defaults synchronize];

    NSDictionary *info = @{
        @"enabled": @(selected)
    };

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SleepModeCommandNotification
        object:nil
        userInfo:info];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SleepModeStateChangedNotification
        object:nil];
}


static void SleepModeToggle(id self, SEL _cmd)
{
    BOOL selected = SleepModeIsSelected(
        self,
        sel_registerName("isSelected")
    );

    SleepModeSetSelected(
        self,
        sel_registerName("setSelected:"),
        !selected
    );
}


#pragma mark - Create Module

static void SleepModeRegisterModule(void)
{
    /*
     * Không tạo lại nếu đã tồn tại.
     */
    if (NSClassFromString(@"SleepModeModule") != Nil) {
        return;
    }

    Class baseClass = SleepModeGetCCUIToggleModule();

    if (baseClass == Nil) {
        NSLog(@"[SleepMode] ERROR: CCUIToggleModule unavailable");
        return;
    }

    /*
     * Tạo class:
     *
     * SleepModeModule : CCUIToggleModule
     *
     * bằng runtime để tránh linker dependency.
     */
    Class moduleClass =
        objc_allocateClassPair(
            baseClass,
            "SleepModeModule",
            0
        );

    if (moduleClass == Nil) {
        NSLog(@"[SleepMode] ERROR: objc_allocateClassPair failed");
        return;
    }

    class_addMethod(
        moduleClass,
        sel_registerName("isSelected"),
        (IMP)SleepModeIsSelected,
        "c@:"
    );

    class_addMethod(
        moduleClass,
        sel_registerName("setSelected:"),
        (IMP)SleepModeSetSelected,
        "v@:c"
    );

    /*
     * Một số phiên bản ControlCenter gọi:
     * handlePress
     */
    class_addMethod(
        moduleClass,
        sel_registerName("handlePress"),
        (IMP)SleepModeToggle,
        "v@:"
    );

    /*
     * Một số phiên bản gọi:
     * toggle
     */
    class_addMethod(
        moduleClass,
        sel_registerName("toggle"),
        (IMP)SleepModeToggle,
        "v@:"
    );

    objc_registerClassPair(moduleClass);

    NSLog(@"[SleepMode] SleepModeModule registered");
}


#pragma mark - Bootstrap

@interface SleepModeBootstrap : NSObject
@end

@implementation SleepModeBootstrap

+ (void)load
{
    @autoreleasepool {
        SleepModeRegisterModule();
    }
}

@end
