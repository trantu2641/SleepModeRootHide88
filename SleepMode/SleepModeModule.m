#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma mark - Constants

static NSString * const SMEnabledKey =
    @"SleepModeEnabled";

static NSString * const SMTimeoutKey =
    @"SleepModeTimeout";

static NSString * const SMCommandNotification =
    @"com.trantu.sleepmode.command";

static NSString * const SMStateChangedNotification =
    @"com.trantu.sleepmode.stateChanged";

static NSString * const SMModuleIdentifier =
    @"com.trantu.sleepmode";

#pragma mark - Settings

static NSUserDefaults *SMDefaults(void)
{
    return [NSUserDefaults standardUserDefaults];
}

static BOOL SMIsEnabled(void)
{
    return [SMDefaults() boolForKey:SMEnabledKey];
}

static void SMSetEnabled(BOOL enabled)
{
    NSUserDefaults *defaults =
        SMDefaults();

    [defaults setBool:enabled
               forKey:SMEnabledKey];

    [defaults synchronize];

    NSDictionary *info = @{
        @"enabled": @(enabled)
    };

    [[NSNotificationCenter defaultCenter]
        postNotificationName:
            SMCommandNotification
        object:nil
        userInfo:info];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:
            SMStateChangedNotification
        object:nil];
}

static NSTimeInterval SMCurrentTimeout(void)
{
    NSTimeInterval timeout =
        [SMDefaults()
            doubleForKey:SMTimeoutKey];

    if (timeout <= 0.0) {
        timeout = 15.0;
    }

    return timeout;
}

static void SMSetTimeout(NSTimeInterval timeout)
{
    if (timeout < 1.0) {
        timeout = 1.0;
    }

    NSUserDefaults *defaults =
        SMDefaults();

    [defaults setDouble:timeout
                  forKey:SMTimeoutKey];

    [defaults synchronize];

    NSDictionary *info = @{
        @"timeout": @(timeout)
    };

    [[NSNotificationCenter defaultCenter]
        postNotificationName:
            SMCommandNotification
        object:nil
        userInfo:info];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:
            SMStateChangedNotification
        object:nil];
}

static void SMResetTimer(void)
{
    [[NSNotificationCenter defaultCenter]
        postNotificationName:
            SMCommandNotification
        object:nil
        userInfo:@{
            @"reset": @YES
        }];
}

#pragma mark - Window

static UIWindow *SMFindActiveWindow(void)
{
    UIApplication *application =
        [UIApplication sharedApplication];

    if (!application) {
        return nil;
    }

    NSArray *scenes =
        [application.connectedScenes allObjects];

    UIWindow *fallback = nil;

    for (UIScene *scene in scenes) {

        if (![scene isKindOfClass:
              [UIWindowScene class]]) {

            continue;
        }

        UIWindowScene *windowScene =
            (UIWindowScene *)scene;

        if (windowScene.activationState !=
            UISceneActivationStateForegroundActive) {

            continue;
        }

        for (UIWindow *window
             in windowScene.windows) {

            if (window.hidden ||
                window.alpha <= 0.01) {

                continue;
            }

            if (window.windowLevel !=
                UIWindowLevelNormal) {

                continue;
            }

            if (window.isKeyWindow) {
                return window;
            }

            if (!fallback) {
                fallback = window;
            }
        }
    }

    return fallback;
}

static UIViewController *
SMTopViewController(
    UIViewController *controller)
{
    if (!controller) {
        return nil;
    }

    UIViewController *presented =
        controller.presentedViewController;

    if (presented &&
        !presented.isBeingDismissed) {

        return SMTopViewController(
            presented
        );
    }

    if ([controller isKindOfClass:
         [UINavigationController class]]) {

        UINavigationController *nav =
            (UINavigationController *)controller;

        if (nav.visibleViewController) {

            return SMTopViewController(
                nav.visibleViewController
            );
        }
    }

    if ([controller isKindOfClass:
         [UITabBarController class]]) {

        UITabBarController *tabs =
            (UITabBarController *)controller;

        if (tabs.selectedViewController) {

            return SMTopViewController(
                tabs.selectedViewController
            );
        }
    }

    return controller;
}

#pragma mark - Timeout menu

static void SMShowTimeoutMenu(void)
{
    UIWindow *window =
        SMFindActiveWindow();

    if (!window) {
        NSLog(
            @"[SleepMode] Không tìm thấy active window"
        );

        return;
    }

    UIViewController *controller =
        SMTopViewController(
            window.rootViewController
        );

    if (!controller) {
        return;
    }

    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:
                @"Thời gian tự khóa"
            message:
                @"Chọn thời gian chờ"
            preferredStyle:
                UIAlertControllerStyleActionSheet];

    NSArray *options = @[
        @{
            @"title": @"15 giây",
            @"value": @15.0
        },

        @{
            @"title": @"1 phút",
            @"value": @60.0
        },

        @{
            @"title": @"5 phút",
            @"value": @300.0
        },

        @{
            @"title": @"15 phút",
            @"value": @900.0
        },

        @{
            @"title": @"30 phút",
            @"value": @1800.0
        },

        @{
            @"title": @"1 giờ",
            @"value": @3600.0
        },

        @{
            @"title": @"2 giờ",
            @"value": @7200.0
        }
    ];

    NSTimeInterval current =
        SMCurrentTimeout();

    for (NSDictionary *item
         in options) {

        NSString *title =
            item[@"title"];

        NSNumber *value =
            item[@"value"];

        BOOL selected =
            fabs(
                current -
                value.doubleValue
            ) < 0.5;

        NSString *displayTitle =
            selected
                ? [NSString stringWithFormat:
                    @"✓ %@",
                    title]
                : title;

        UIAlertAction *action =
            [UIAlertAction
                actionWithTitle:
                    displayTitle
                style:
                    UIAlertActionStyleDefault
                handler:
                    ^(UIAlertAction *action) {

            (void)action;

            SMSetTimeout(
                value.doubleValue
            );

            if (SMIsEnabled()) {
                SMResetTimer();
            }
        }];

        [alert addAction:action];
    }

    [alert addAction:
        [UIAlertAction
            actionWithTitle:
                @"Hủy"
            style:
                UIAlertActionStyleCancel
            handler:nil]];

    UIPopoverPresentationController *
        popover =
            alert.popoverPresentationController;

    if (popover) {

        popover.sourceView =
            window;

        popover.sourceRect =
            CGRectMake(
                CGRectGetMidX(
                    window.bounds
                ),
                CGRectGetMidY(
                    window.bounds
                ),
                1.0,
                1.0
            );

        popover.permittedArrowDirections =
            UIPopoverArrowDirectionAny;
    }

    [controller
        presentViewController:
            alert
        animated:YES
        completion:nil];
}

#pragma mark - Runtime methods

static BOOL
SMIsSelected(id self, SEL _cmd)
{
    (void)self;
    (void)_cmd;

    return SMIsEnabled();
}

static void
SMSetSelected(id self,
              SEL _cmd,
              BOOL selected)
{
    (void)self;
    (void)_cmd;

    SMSetEnabled(selected);
}

static NSString *
SMIdentifier(id self, SEL _cmd)
{
    (void)self;
    (void)_cmd;

    return SMModuleIdentifier;
}

static NSString *
SMTitle(id self, SEL _cmd)
{
    (void)self;
    (void)_cmd;

    return @"Chế độ ngủ";
}

static NSString *
SMIconGlyph(id self, SEL _cmd)
{
    (void)self;
    (void)_cmd;

    return @"moon.fill";
}

static NSString *
SMSelectedIconGlyph(id self, SEL _cmd)
{
    (void)self;
    (void)_cmd;

    return @"moon.fill";
}

static BOOL
SMHasContent(id self, SEL _cmd)
{
    (void)self;
    (void)_cmd;

    return NO;
}

static void
SMHandleTap(id self, SEL _cmd)
{
    (void)self;
    (void)_cmd;

    SMSetEnabled(!SMIsEnabled());
}

static void
SMHandleLongPress(id self, SEL _cmd)
{
    (void)self;
    (void)_cmd;

    SMShowTimeoutMenu();
}

#pragma mark - Dynamic CC module

static Class SMCreateModuleClass(void)
{
    Class existing =
        NSClassFromString(
            @"SleepModeModule"
        );

    if (existing) {
        return existing;
    }

    Class base =
        NSClassFromString(
            @"CCUIToggleModule"
        );

    if (!base) {

        NSLog(
            @"[SleepMode] "
             "CCUIToggleModule không tồn tại"
        );

        return Nil;
    }

    Class module =
        objc_allocateClassPair(
            base,
            "SleepModeModule",
            0
        );

    if (!module) {

        NSLog(
            @"[SleepMode] "
             "objc_allocateClassPair thất bại"
        );

        return Nil;
    }

    class_addMethod(
        module,
        @selector(isSelected),
        (IMP)SMIsSelected,
        "c@:"
    );

    class_addMethod(
        module,
        @selector(setSelected:),
        (IMP)SMSetSelected,
        "v@:c"
    );

    class_addMethod(
        module,
        @selector(identifier),
        (IMP)SMIdentifier,
        "@@:"
    );

    class_addMethod(
        module,
        @selector(title),
        (IMP)SMTitle,
        "@@:"
    );

    class_addMethod(
        module,
        @selector(iconGlyph),
        (IMP)SMIconGlyph,
        "@@:"
    );

    class_addMethod(
        module,
        @selector(selectedIconGlyph),
        (IMP)SMSelectedIconGlyph,
        "@@:"
    );

    class_addMethod(
        module,
        @selector(hasContent),
        (IMP)SMHasContent,
        "c@:"
    );

    class_addMethod(
        module,
        @selector(handleTap),
        (IMP)SMHandleTap,
        "v@:"
    );

    class_addMethod(
        module,
        @selector(handleLongPress),
        (IMP)SMHandleLongPress,
        "v@:"
    );

    objc_registerClassPair(module);

    NSLog(
        @"[SleepMode] "
         "SleepModeModule đã đăng ký"
    );

    return module;
}

#pragma mark - Bootstrap

@interface SleepModeBootstrap : NSObject
@end

@implementation SleepModeBootstrap

+ (void)load
{
    NSUserDefaults *defaults =
        SMDefaults();

    if ([defaults objectForKey:
            SMEnabledKey] == nil) {

        [defaults setBool:NO
                   forKey:SMEnabledKey];
    }

    if ([defaults objectForKey:
            SMTimeoutKey] == nil) {

        [defaults setDouble:15.0
                     forKey:SMTimeoutKey];
    }

    [defaults synchronize];

    SMCreateModuleClass();

    NSLog(
        @"[SleepMode] Bootstrap OK "
         "enabled=%d timeout=%.0f",
        SMIsEnabled(),
        SMCurrentTimeout()
    );
}

@end
