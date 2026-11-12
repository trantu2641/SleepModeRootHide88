#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>

static NSString * const SleepModeEnabledKey =
    @"SleepModeEnabled";

static NSString * const SleepModeCommandNotification =
    @"com.trantu.sleepmode.command";


#pragma mark - Settings

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

    NSDictionary *info = @{
        @"enabled": @(enabled)
    };

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SleepModeCommandNotification
                      object:nil
                    userInfo:info];
}


#pragma mark - Find ControlCenter module class

static Class SleepModeFindToggleClass(void)
{
    Class cls = NSClassFromString(@"CCUIToggleModule");

    if (cls != Nil)
        return cls;

    void *handle = dlopen(
        "/System/Library/PrivateFrameworks/ControlCenterUI.framework/ControlCenterUI",
        RTLD_NOW | RTLD_GLOBAL
    );

    if (handle == NULL)
    {
        NSLog(
            @"[SleepMode] Cannot load ControlCenterUI"
        );

        return Nil;
    }

    cls = NSClassFromString(@"CCUIToggleModule");

    NSLog(
        @"[SleepMode] CCUIToggleModule = %@",
        cls
    );

    /*
     * Không dlclose().
     * Giữ framework sống trong process Control Center.
     */
    return cls;
}


#pragma mark - Runtime methods

static BOOL SleepModeIsSelected(id self, SEL _cmd)
{
    return SleepModeIsEnabled();
}

static void SleepModeSetSelected(
    id self,
    SEL _cmd,
    BOOL selected
)
{
    SleepModeSetEnabled(selected);
}

static void SleepModeHandlePress(id self, SEL _cmd)
{
    BOOL enabled = SleepModeIsEnabled();

    SleepModeSetEnabled(!enabled);
}

static void SleepModeRefreshState(id self, SEL _cmd)
{
}


#pragma mark - Create module

static BOOL SleepModeCreateModule(void)
{
    if (NSClassFromString(@"SleepModeModule") != Nil)
    {
        NSLog(
            @"[SleepMode] SleepModeModule already exists"
        );

        return YES;
    }

    Class baseClass =
        SleepModeFindToggleClass();

    if (baseClass == Nil)
    {
        NSLog(
            @"[SleepMode] CCUIToggleModule unavailable"
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
            @"[SleepMode] objc_allocateClassPair failed"
        );

        return NO;
    }


    class_addMethod(
        moduleClass,
        @selector(isSelected),
        (IMP)SleepModeIsSelected,
        "c@:"
    );


    class_addMethod(
        moduleClass,
        @selector(setSelected:),
        (IMP)SleepModeSetSelected,
        "v@:c"
    );


    class_addMethod(
        moduleClass,
        @selector(handlePress),
        (IMP)SleepModeHandlePress,
        "v@:"
    );


    class_addMethod(
        moduleClass,
        @selector(refreshState),
        (IMP)SleepModeRefreshState,
        "v@:"
    );


    objc_registerClassPair(moduleClass);

    NSLog(
        @"[SleepMode] SleepModeModule created successfully"
    );

    return YES;
}


#pragma mark - Delayed startup

static void SleepModeTryCreate(void)
{
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            if (SleepModeCreateModule())
                return;


            /*
             * Control Center có thể chưa load
             * ControlCenterUI tại thời điểm bundle
             * được load.
             */

            dispatch_after(
                dispatch_time(
                    DISPATCH_TIME_NOW,
                    (int64_t)(0.5 * NSEC_PER_SEC)
                ),
                dispatch_get_main_queue(),
                ^{
                    if (SleepModeCreateModule())
                        return;


                    dispatch_after(
                        dispatch_time(
                            DISPATCH_TIME_NOW,
                            (int64_t)(1.0 * NSEC_PER_SEC)
                        ),
                        dispatch_get_main_queue(),
                        ^{
                            if (SleepModeCreateModule())
                                return;


                            dispatch_after(
                                dispatch_time(
                                    DISPATCH_TIME_NOW,
                                    (int64_t)(2.0 * NSEC_PER_SEC)
                                ),
                                dispatch_get_main_queue(),
                                ^{
                                    SleepModeCreateModule();
                                }
                            );
                        }
                    );
                }
            );
        }
    );
}


#pragma mark - Bundle entry

__attribute__((constructor))
static void SleepModeModuleInit(void)
{
    NSLog(
        @"[SleepMode] SleepModeModule.bundle loaded"
    );

    SleepModeTryCreate();
}
