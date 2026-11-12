#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>

#import "../SleepControlCenter.h"

#pragma mark - Runtime helpers

static Class SleepModeFindCCUIToggleModule(void)
{
    Class cls = NSClassFromString(@"CCUIToggleModule");

    if (cls != Nil)
        return cls;

    /*
     * ControlCenterUI là nơi chứa CCUIToggleModule trên các bản iOS
     * hiện đại. Chỉ load nếu framework đã tồn tại.
     */
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

static BOOL SleepModeIsSelected(id self, SEL _cmd)
{
    return [SleepControlCenter sharedInstance].enabled;
}

static void SleepModeSetSelected(id self, SEL _cmd, BOOL selected)
{
    SleepControlCenter *control = [SleepControlCenter sharedInstance];

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
     * State được lưu trong SleepControlCenter.
     * Không cần làm gì thêm ở đây.
     */
}

#pragma mark - Register module

static void SleepModeRegisterModule(void)
{
    /*
     * Nếu class đã tồn tại thì không đăng ký lại.
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
     * Tạo:
     *
     *     SleepModeModule : CCUIToggleModule
     *
     * bằng runtime.
     *
     * Không có reference trực tiếp tới CCUIToggleModule
     * trong linker.
     */
    Class moduleClass = objc_allocateClassPair(
        baseClass,
        "SleepModeModule",
        0
    );

    if (moduleClass == Nil)
    {
        /*
         * Có thể class đã được tạo bởi lần load trước.
         */
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
     * Một số phiên bản ControlCenter gọi handlePress.
     */
    class_addMethod(
        moduleClass,
        @selector(handlePress),
        (IMP)SleepModeHandlePress,
        "v@:"
    );

    /*
     * Một số phiên bản gọi refreshState khi cập nhật module.
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

#pragma mark - Bundle load

__attribute__((constructor))
static void SleepModeModuleInit(void)
{
    /*
     * ControlCenterUI phải được load trước khi tìm CCUIToggleModule.
     */
    dispatch_async(dispatch_get_main_queue(), ^{
        SleepModeRegisterModule();
    });
}
