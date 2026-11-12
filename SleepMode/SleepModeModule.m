#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>

#pragma mark - Constants

static NSString * const SleepModeEnabledKey =
    @"SleepModeEnabled";

static NSString * const SleepModeCommandNotification =
    @"com.trantu.sleepmode.command";


#pragma mark - State

static BOOL SleepModeIsEnabled(void)
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

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SleepModeCommandNotification
                      object:nil
                    userInfo:@{
                        @"enabled": @(enabled)
                    }];
}


#pragma mark - Find CCUIToggleModule

static Class SleepModeGetBaseClass(void)
{
    Class cls = NSClassFromString(@"CCUIToggleModule");

    if (cls != Nil)
        return cls;

    void *handle = dlopen(
        "/System/Library/PrivateFrameworks/ControlCenterUI.framework/ControlCenterUI",
        RTLD_LAZY | RTLD_GLOBAL
    );

    if (handle == NULL)
    {
        NSLog(@"[SleepMode] Cannot load ControlCenterUI");
        return Nil;
    }

    cls = NSClassFromString(@"CCUIToggleModule");

    NSLog(
        @"[SleepMode] CCUIToggleModule = %@",
        cls
    );

    /*
     * Không dlclose().
     * Giữ framework đã load trong process.
     */
    return cls;
}


#pragma mark - Module methods

static BOOL SleepModeModuleIsSelected(
    id self,
    SEL _cmd
)
{
    return SleepModeIsEnabled();
}


static void SleepModeModuleSetSelected(
    id self,
    SEL _cmd,
    BOOL selected
)
{
    SleepModeSetEnabled(selected);
}


static void SleepModeModuleHandlePress(
    id self,
    SEL _cmd
)
{
    BOOL enabled = SleepModeIsEnabled();

    SleepModeSetEnabled(!enabled);
}


static void SleepModeModuleRefreshState(
    id self,
    SEL _cmd
)
{
    /*
     * Trạng thái được đọc trực tiếp từ
     * NSUserDefaults trong isSelected.
     *
     * Không tạo timer, không gọi SpringBoard,
     * không reload Control Center ở đây.
     */
}


#pragma mark - Create runtime class

static BOOL SleepModeCreateModuleClass(void)
{
    /*
     * Nếu class đã tồn tại thì tuyệt đối không tạo lại.
     */
    if (NSClassFromString(@"SleepModeModule") != Nil)
    {
        NSLog(
            @"[SleepMode] SleepModeModule already exists"
        );

        return YES;
    }

    Class baseClass =
        SleepModeGetBaseClass();

    if (baseClass == Nil)
    {
        NSLog(
            @"[SleepMode] CCUIToggleModule not available"
        );

        return NO;
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
            @"[SleepMode] Failed to allocate SleepModeModule"
        );

        return NO;
    }

    /*
     * Không override init.
     *
     * CCUIToggleModule tự xử lý initializer.
     * Việc tự gọi init bằng objc_msgSend trước đây
     * có thể gây recursion và respring.
     */

    class_addMethod(
        moduleClass,
        @selector(isSelected),
        (IMP)SleepModeModuleIsSelected,
        "c@:"
    );

    class_addMethod(
        moduleClass,
        @selector(setSelected:),
        (IMP)SleepModeModuleSetSelected,
        "v@:c"
    );

    class_addMethod(
        moduleClass,
        @selector(handlePress),
        (IMP)SleepModeModuleHandlePress,
        "v@:"
    );

    class_addMethod(
        moduleClass,
        @selector(refreshState),
        (IMP)SleepModeModuleRefreshState,
        "v@:"
    );

    objc_registerClassPair(moduleClass);

    NSLog(
        @"[SleepMode] SleepModeModule registered"
    );

    return YES;
}


#pragma mark - Entry

__attribute__((constructor))
static void SleepModeModuleInit(void)
{
    /*
     * Chỉ đăng ký class.
     *
     * Không tạo UI.
     * Không gọi SpringBoard.
     * Không post notification.
     * Không thao tác UIApplication.
     * Không gọi init.
     *
     * Mục tiêu là tránh respring/crash khi Control Center
     * đang load bundle.
     */

    NSLog(
        @"[SleepMode] Bundle loaded"
    );

    SleepModeCreateModuleClass();
}
