#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>

#import "SleepControlCenter.h"

#pragma mark - Runtime helpers

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

#pragma mark - Module methods

static BOOL SleepModeIsSelected(id self, SEL _cmd)
{
    return [SleepControlCenter sharedInstance].enabled;
}

static void SleepModeSetSelected(id self, SEL _cmd, BOOL selected)
{
    SleepControlCenter *control =
        [SleepControlCenter sharedInstance];

    if (selected)
        [control enable];
    else
        [control disable];
}

static void SleepModeHandlePress(id self, SEL _cmd)
{
    [[SleepControlCenter sharedInstance] toggle];
}

static void SleepModeRefreshState(id self, SEL _cmd)
{
    /*
     * Trạng thái thực tế được lưu bởi SleepControlCenter.
     * Không cần thực hiện thêm hành động ở đây.
     */
}

#pragma mark - Register

static void SleepModeRegisterModule(void)
{
    /*
     * Tránh đăng ký class lần thứ hai.
     */
    if (NSClassFromString(@"SleepModeModule") != Nil)
        return;

    Class baseClass = SleepModeFindCCUIToggleModule();

    if (baseClass == Nil)
    {
        NSLog(@"[SleepMode] CCUIToggleModule not found");
        return;
    }

    /*
     * Tạo runtime subclass:

        SleepModeModule : CCUIToggleModule

     * Không reference trực tiếp CCUIToggleModule lúc link.
     */
    Class moduleClass =
        objc_allocateClassPair(
            baseClass,
            "SleepModeModule",
            0
        );

    if (moduleClass == Nil)
        return;

    /*
     * isSelected
     */
    class_addMethod(
        moduleClass,
        @selector(isSelected),
        (IMP)SleepModeIsSelected,
        "c@:"
    );

    /*
     * setSelected:
     */
    class_addMethod(
        moduleClass,
        @selector(setSelected:),
        (IMP)SleepModeSetSelected,
        "v@:c"
    );

    /*
     * handlePress
     */
    class_addMethod(
        moduleClass,
        @selector(handlePress),
        (IMP)SleepModeHandlePress,
        "v@:"
    );

    /*
     * refreshState
     */
    class_addMethod(
        moduleClass,
        @selector(refreshState),
        (IMP)SleepModeRefreshState,
        "v@:"
    );

    /*
     * Đăng ký class với Objective-C runtime.
     */
    objc_registerClassPair(moduleClass);

    NSLog(@"[SleepMode] SleepModeModule registered");
}

#pragma mark - Bundle initialization

__attribute__((constructor))
static void SleepModeModuleInit(void)
{
    /*
     * Chờ main queue để ControlCenterUI có thời gian
     * load class CCUIToggleModule.
     */
    dispatch_async(dispatch_get_main_queue(), ^{
        SleepModeRegisterModule();
    });
}
