#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>

static NSString * const SleepModeEnabledKey =
    @"SleepModeEnabled";

static NSString * const SleepModeTimeoutKey =
    @"SleepModeTimeout";

static NSString * const SleepModeCommandNotification =
    @"com.trantu.sleepmode.command";

#pragma mark - State

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

#pragma mark - ControlCenterUI

static Class SleepModeGetCCUIToggleModule(void)
{
    Class cls = NSClassFromString(@"CCUIToggleModule");

    if (cls != Nil)
        return cls;

    void *handle = dlopen(
        "/System/Library/PrivateFrameworks/ControlCenterUI.framework/ControlCenterUI",
        RTLD_NOW | RTLD_GLOBAL
    );

    if (handle != NULL)
    {
        cls = NSClassFromString(@"CCUIToggleModule");
    }

    /*
     * Không dlclose ở đây.
     *
     * ControlCenterUI là framework chứa class cha mà
     * SleepModeModule kế thừa runtime. Giữ framework đã load
     * trong process giúp class luôn tồn tại.
     */
    return cls;
}

#pragma mark - CCUIToggleModule methods

static BOOL SleepModeModuleIsSelected(id self, SEL _cmd)
{
    return SleepModeEnabled();
}

static void SleepModeModuleSetSelected(
    id self,
    SEL _cmd,
    BOOL selected
)
{
    SleepModeSetEnabled(selected);
}

static void SleepModeModuleHandlePress(id self, SEL _cmd)
{
    BOOL enabled = SleepModeEnabled();

    SleepModeSetEnabled(!enabled);
}

static void SleepModeModuleRefreshState(id self, SEL _cmd)
{
    /*
     * Trạng thái thật được đọc trực tiếp từ NSUserDefaults
     * mỗi lần Control Center hỏi isSelected.
     *
     * Không cần làm gì ở đây.
     */
}

#pragma mark - Runtime class

static Class SleepModeCreateModuleClass(void)
{
    Class existing =
        NSClassFromString(@"SleepModeModule");

    if (existing != Nil)
        return existing;

    Class baseClass =
        SleepModeGetCCUIToggleModule();

    if (baseClass == Nil)
    {
        NSLog(
            @"[SleepMode] CCUIToggleModule chưa sẵn sàng"
        );

        return Nil;
    }

    Class moduleClass =
        objc_allocateClassPair(
            baseClass,
            "SleepModeModule",
            0
        );

    if (moduleClass == Nil)
    {
        NSLog(
            @"[SleepMode] objc_allocateClassPair failed"
        );

        return Nil;
    }

    /*
     * isSelected
     */
    class_addMethod(
        moduleClass,
        @selector(isSelected),
        (IMP)SleepModeModuleIsSelected,
        "c@:"
    );

    /*
     * setSelected:
     */
    class_addMethod(
        moduleClass,
        @selector(setSelected:),
        (IMP)SleepModeModuleSetSelected,
        "v@:c"
    );

    /*
     * handlePress
     */
    class_addMethod(
        moduleClass,
        @selector(handlePress),
        (IMP)SleepModeModuleHandlePress,
        "v@:"
    );

    /*
     * refreshState
     */
    class_addMethod(
        moduleClass,
        @selector(refreshState),
        (IMP)SleepModeModuleRefreshState,
        "v@:"
    );

    objc_registerClassPair(moduleClass);

    NSLog(
        @"[SleepMode] SleepModeModule runtime class created"
    );

    return moduleClass;
}

#pragma mark - Delayed registration

static void SleepModeRegisterModule(void)
{
    Class moduleClass =
        SleepModeCreateModuleClass();

    if (moduleClass != Nil)
    {
        NSLog(
            @"[SleepMode] SleepModeModule registered successfully"
        );
    }
}

static void SleepModeRetryRegistration(void)
{
    /*
     * Control Center có thể chưa load ControlCenterUI
     * ngay lúc bundle được nạp.
     *
     * Thử lại một vài lần sau khi main run loop hoạt động.
     */

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            SleepModeRegisterModule();

            dispatch_after(
                dispatch_time(
                    DISPATCH_TIME_NOW,
                    (int64_t)(0.5 * NSEC_PER_SEC)
                ),
                dispatch_get_main_queue(),
                ^{
                    if (NSClassFromString(@"SleepModeModule") == Nil)
                    {
                        SleepModeRegisterModule();
                    }
                }
            );

            dispatch_after(
                dispatch_time(
                    DISPATCH_TIME_NOW,
                    (int64_t)(1.5 * NSEC_PER_SEC)
                ),
                dispatch_get_main_queue(),
                ^{
                    if (NSClassFromString(@"SleepModeModule") == Nil)
                    {
                        SleepModeRegisterModule();
                    }
                }
            );

            dispatch_after(
                dispatch_time(
                    DISPATCH_TIME_NOW,
                    (int64_t)(3.0 * NSEC_PER_SEC)
                ),
                dispatch_get_main_queue(),
                ^{
                    if (NSClassFromString(@"SleepModeModule") == Nil)
                    {
                        SleepModeRegisterModule();
                    }
                }
            );
        }
    );
}

#pragma mark - Entry

__attribute__((constructor))
static void SleepModeModuleInit(void)
{
    NSLog(
        @"[SleepMode] SleepModeModule.bundle loaded"
    );

    SleepModeRetryRegistration();
}
