#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>

#pragma mark - Shared constants

static NSString * const SleepModeEnabledKey =
    @"SleepModeEnabled";

static NSString * const SleepModeTimeoutKey =
    @"SleepModeTimeout";

static NSString * const SleepModeCommandNotification =
    @"com.trantu.sleepmode.command";

#pragma mark - Helpers

static BOOL SleepModeEnabled(void)
{
    return [[NSUserDefaults standardUserDefaults]
            boolForKey:SleepModeEnabledKey];
}

static void SleepModeSetEnabled(BOOL enabled)
{
    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    [defaults setBool:enabled
               forKey:SleepModeEnabledKey];

    [defaults synchronize];

    NSDictionary *info = @{
        @"enabled": @(enabled)
    };

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SleepModeCommandNotification
                      object:nil
                    userInfo:info];
}

#pragma mark - Find CCUIToggleModule

static Class SleepModeFindCCUIToggleModule(void)
{
    Class cls = NSClassFromString(@"CCUIToggleModule");

    if (cls != Nil)
        return cls;

    void *handle = dlopen(
        "/System/Library/PrivateFrameworks/ControlCenterUI.framework/ControlCenterUI",
        RTLD_LAZY
    );

    if (handle != NULL)
    {
        cls = NSClassFromString(@"CCUIToggleModule");
        dlclose(handle);
    }

    return cls;
}

#pragma mark - Control Center methods

static BOOL SleepModeIsSelected(id self, SEL _cmd)
{
    return SleepModeEnabled();
}

static void SleepModeSetSelected(
    id self,
    SEL _cmd,
    BOOL selected
)
{
    SleepModeSetEnabled(selected);
}

static void SleepModeHandlePress(
    id self,
    SEL _cmd
)
{
    BOOL enabled = SleepModeEnabled();

    SleepModeSetEnabled(!enabled);
}

static void SleepModeRefreshState(
    id self,
    SEL _cmd
)
{
    /*
     * State được đọc trực tiếp từ NSUserDefaults.
     */
}

#pragma mark - Register module

static void SleepModeRegisterModule(void)
{
    /*
     * Không đăng ký lại nếu class đã tồn tại.
     */
    if (NSClassFromString(@"SleepModeModule") != Nil)
        return;

    Class baseClass =
        SleepModeFindCCUIToggleModule();

    if (baseClass == Nil)
    {
        NSLog(@"[SleepMode] CCUIToggleModule not found");
        return;
    }

    Class moduleClass =
        objc_allocateClassPair(
            baseClass,
            "SleepModeModule",
            0
        );

    if (moduleClass == Nil)
    {
        NSLog(@"[SleepMode] Failed to create class");
        return;
    }

    /*
     * -isSelected
     */
    class_addMethod(
        moduleClass,
        @selector(isSelected),
        (IMP)SleepModeIsSelected,
        "c@:"
    );

    /*
     * -setSelected:
     */
    class_addMethod(
        moduleClass,
        @selector(setSelected:),
        (IMP)SleepModeSetSelected,
        "v@:c"
    );

    /*
     * -handlePress
     */
    class_addMethod(
        moduleClass,
        @selector(handlePress),
        (IMP)SleepModeHandlePress,
        "v@:"
    );

    /*
     * -refreshState
     */
    class_addMethod(
        moduleClass,
        @selector(refreshState),
        (IMP)SleepModeRefreshState,
        "v@:"
    );

    objc_registerClassPair(moduleClass);

    NSLog(@"[SleepMode] SleepModeModule registered");
}

#pragma mark - Constructor

__attribute__((constructor))
static void SleepModeModuleInit(void)
{
    /*
     * Không dùng SleepControlCenter ở đây.
     * Bundle hoàn toàn độc lập với tweak binary.
     */
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SleepModeRegisterModule();
        }
    );
}
