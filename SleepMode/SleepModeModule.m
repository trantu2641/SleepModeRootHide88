#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>

#pragma mark - Constants

static NSString * const kSleepModeEnabledKey = @"SleepModeEnabled";
static NSString * const kSleepModeTimeoutKey = @"SleepModeTimeout";

static NSString * const kSleepModeCommandNotification =
    @"com.trantu.sleepmode.command";

static NSString * const kSleepModeStateChangedNotification =
    @"com.trantu.sleepmode.stateChanged";

#pragma mark - Runtime helpers

static Class SleepModeLoadCCUIToggleModule(void)
{
    Class cls = NSClassFromString(@"CCUIToggleModule");

    if (cls) {
        return cls;
    }

    /*
     * CCUIToggleModule nằm trong ControlCenterUI private framework.
     * Không link trực tiếp để tránh lỗi undefined symbol khi build.
     */
    void *handle = dlopen(
        "/System/Library/PrivateFrameworks/ControlCenterUI.framework/ControlCenterUI",
        RTLD_LAZY
    );

    if (handle) {
        cls = NSClassFromString(@"CCUIToggleModule");
    }

    return cls;
}

#pragma mark - Runtime Module

static id SleepModeModuleInit(id self, SEL _cmd)
{
    self = ((id (*)(id, SEL))objc_msgSend)(
        self,
        sel_registerName("init")
    );

    return self;
}

static BOOL SleepModeModuleIsSelected(id self, SEL _cmd)
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    return [defaults boolForKey:kSleepModeEnabledKey];
}

static void SleepModeModuleSetSelected(id self, SEL _cmd, BOOL selected)
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    [defaults setBool:selected forKey:kSleepModeEnabledKey];
    [defaults synchronize];

    NSDictionary *info = @{
        @"enabled": @(selected)
    };

    [[NSNotificationCenter defaultCenter]
        postNotificationName:kSleepModeCommandNotification
        object:nil
        userInfo:info];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:kSleepModeStateChangedNotification
        object:nil];
}

static void SleepModeModuleSetSelectedState(id self, SEL _cmd, BOOL selected)
{
    SleepModeModuleSetSelected(self, _cmd, selected);
}

static void SleepModeModuleHandlePress(id self, SEL _cmd)
{
    BOOL current =
        SleepModeModuleIsSelected(self, _cmd);

    SleepModeModuleSetSelected(
        self,
        sel_registerName("setSelected:"),
        !current
    );
}

#pragma mark - Module Creation

static void SleepModeCreateModuleClass(void)
{
    /*
     * Nếu class đã tồn tại thì không tạo lại.
     */
    if (NSClassFromString(@"SleepModeModule")) {
        return;
    }

    Class baseClass = SleepModeLoadCCUIToggleModule();

    if (!baseClass) {
        NSLog(@"[SleepMode] CCUIToggleModule not found");
        return;
    }

    /*
     * Tạo:
     *
     * SleepModeModule : CCUIToggleModule
     *
     * hoàn toàn bằng runtime.
     *
     * Vì vậy linker không cần:
     * _OBJC_CLASS_$_CCUIToggleModule
     */
    Class moduleClass =
        objc_allocateClassPair(
            baseClass,
            "SleepModeModule",
            0
        );

    if (!moduleClass) {
        NSLog(@"[SleepMode] Failed to allocate SleepModeModule");
        return;
    }

    class_addMethod(
        moduleClass,
        sel_registerName("init"),
        (IMP)SleepModeModuleInit,
        "@@:"
    );

    class_addMethod(
        moduleClass,
        sel_registerName("isSelected"),
        (IMP)SleepModeModuleIsSelected,
        "c@:"
    );

    class_addMethod(
        moduleClass,
        sel_registerName("setSelected:"),
        (IMP)SleepModeModuleSetSelected,
        "v@:c"
    );

    class_addMethod(
        moduleClass,
        sel_registerName("setSelectedState:"),
        (IMP)SleepModeModuleSetSelectedState,
        "v@:c"
    );

    class_addMethod(
        moduleClass,
        sel_registerName("handlePress"),
        (IMP)SleepModeModuleHandlePress,
        "v@:"
    );

    objc_registerClassPair(moduleClass);

    NSLog(@"[SleepMode] SleepModeModule registered");
}

#pragma mark - Bootstrap

@interface SleepModeModuleBootstrap : NSObject
@end

@implementation SleepModeModuleBootstrap

+ (void)load
{
    SleepModeCreateModuleClass();
}

@end
