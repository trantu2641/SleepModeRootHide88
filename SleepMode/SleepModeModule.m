#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

#pragma mark - Internal constants

static NSString * const SMEnabledKey = @"SleepModeEnabled";
static NSString * const SMTimeoutKey = @"SleepModeTimeout";

static NSString * const SMCommandNotification =
    @"com.trantu.sleepmode.command";

static NSString * const SMStateChangedNotification =
    @"com.trantu.sleepmode.stateChanged";

static NSString * const SMModuleIdentifier =
    @"com.trantu.sleepmode";

#pragma mark - Shared settings

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
    NSUserDefaults *defaults = SMDefaults();

    [defaults setBool:enabled forKey:SMEnabledKey];
    [defaults synchronize];

    NSDictionary *info = @{
        @"enabled": @(enabled)
    };

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SMCommandNotification
        object:nil
        userInfo:info];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SMStateChangedNotification
        object:nil];
}

static NSTimeInterval SMCurrentTimeout(void)
{
    NSTimeInterval timeout =
        [SMDefaults() doubleForKey:SMTimeoutKey];

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

    NSUserDefaults *defaults = SMDefaults();

    [defaults setDouble:timeout forKey:SMTimeoutKey];
    [defaults synchronize];

    NSDictionary *info = @{
        @"timeout": @(timeout)
    };

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SMCommandNotification
        object:nil
        userInfo:info];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SMStateChangedNotification
        object:nil];
}

static void SMResetTimer(void)
{
    [[NSNotificationCenter defaultCenter]
        postNotificationName:SMCommandNotification
        object:nil
        userInfo:@{
            @"reset": @YES
        }];
}

#pragma mark - Window helpers

static UIWindow *SMFindActiveWindow(void)
{
    UIApplication *application =
        [UIApplication sharedApplication];

    if (!application) {
        return nil;
    }

    NSArray *scenes =
        [application.connectedScenes allObjects];

    UIWindow *fallbackWindow = nil;

    for (UIScene *scene in scenes) {

        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }

        UIWindowScene *windowScene =
            (UIWindowScene *)scene;

        if (windowScene.activationState !=
            UISceneActivationStateForegroundActive) {
            continue;
        }

        NSArray *windows = windowScene.windows;

        for (UIWindow *window in windows) {

            if (!window.hidden &&
                window.alpha > 0.01 &&
                window.windowLevel == UIWindowLevelNormal) {

                if (window.isKeyWindow) {
                    return window;
                }

                if (!fallbackWindow) {
                    fallbackWindow = window;
                }
            }
        }
    }

    return fallbackWindow;
}

static UIViewController *SMTopViewController(
    UIViewController *controller)
{
    if (!controller) {
        return nil;
    }

    UIViewController *presented =
        controller.presentedViewController;

    if (presented &&
        !presented.isBeingDismissed) {

        return SMTopViewController(presented);
    }

    if ([controller isKindOfClass:
         [UINavigationController class]]) {

        UINavigationController *navigation =
            (UINavigationController *)controller;

        UIViewController *visible =
            navigation.visibleViewController;

        if (visible) {
            return SMTopViewController(visible);
        }
    }

    if ([controller isKindOfClass:
         [UITabBarController class]]) {

        UITabBarController *tabs =
            (UITabBarController *)controller;

        UIViewController *selected =
            tabs.selectedViewController;

        if (selected) {
            return SMTopViewController(selected);
        }
    }

    return controller;
}

#pragma mark - Timeout menu

static void SMShowTimeoutMenu(id self)
{
    UIWindow *window = SMFindActiveWindow();

    if (!window) {
        return;
    }

    UIViewController *root =
        window.rootViewController;

    UIViewController *controller =
        SMTopViewController(root);

    if (!controller) {
        return;
    }

    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:@"Thời gian tự khóa"
            message:@"Chọn thời gian chờ"
            preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray *items = @[
        @{
            @"title": @"15 giây",
            @"value": @(15.0)
        },
        @{
            @"title": @"1 phút",
            @"value": @(60.0)
        },
        @{
            @"title": @"5 phút",
            @"value": @(300.0)
        },
        @{
            @"title": @"15 phút",
            @"value": @(900.0)
        },
        @{
            @"title": @"30 phút",
            @"value": @(1800.0)
        },
        @{
            @"title": @"1 giờ",
            @"value": @(3600.0)
        },
        @{
            @"title": @"2 giờ",
            @"value": @(7200.0)
        }
    ];

    NSTimeInterval current =
        SMCurrentTimeout();

    for (NSDictionary *item in items) {

        NSString *title =
            item[@"title"];

        NSNumber *value =
            item[@"value"];

        BOOL selected =
            fabs(value.doubleValue - current) < 0.5;

        NSString *buttonTitle =
            selected
                ? [NSString stringWithFormat:@"✓ %@", title]
                : title;

        UIAlertAction *action =
            [UIAlertAction
                actionWithTitle:buttonTitle
                style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {

                    SMSetTimeout(value.doubleValue);

                    if (SMIsEnabled()) {
                        SMResetTimer();
                    }
                }];

        [alert addAction:action];
    }

    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"Hủy"
            style:UIAlertActionStyleCancel
            handler:nil]];

    UIPopoverPresentationController *popover =
        alert.popoverPresentationController;

    if (popover) {

        popover.sourceView = window;

        popover.sourceRect =
            CGRectMake(
                CGRectGetMidX(window.bounds),
                CGRectGetMidY(window.bounds),
                1.0,
                1.0
            );

        popover.permittedArrowDirections =
            UIPopoverArrowDirectionAny;
    }

    [controller presentViewController:alert
                             animated:YES
                           completion:nil];
}

#pragma mark - CCUIToggleModule runtime bridge

static BOOL SMModuleIsSelected(id self,
                               SEL _cmd)
{
    return SMIsEnabled();
}

static void SMModuleSetSelected(id self,
                                SEL _cmd,
                                BOOL selected)
{
    SMSetEnabled(selected);
}

static NSString *SMModuleIdentifierMethod(id self,
                                          SEL _cmd)
{
    return SMModuleIdentifier;
}

static NSString *SMModuleTitle(id self,
                               SEL _cmd)
{
    return @"Chế độ ngủ";
}

static NSString *SMModuleIconGlyph(id self,
                                   SEL _cmd)
{
    return @"moon.fill";
}

static NSString *SMModuleSelectedIconGlyph(id self,
                                           SEL _cmd)
{
    return @"moon.fill";
}

static void SMModuleSetSelectedGlyphColor(
    id self,
    SEL _cmd,
    UIColor *color)
{
    /*
     * Không cần làm gì.
     * CCSupport sẽ tự xử lý màu của module.
     */
    (void)self;
    (void)_cmd;
    (void)color;
}

static BOOL SMModuleHasContent(id self,
                               SEL _cmd)
{
    return YES;
}

static UIViewController *SMModuleContentViewController(
    id self,
    SEL _cmd)
{
    (void)self;
    (void)_cmd;

    return nil;
}

static void SMModuleHandleTap(id self,
                              SEL _cmd)
{
    /*
     * Tap bình thường:
     * bật / tắt Chế độ ngủ.
     */
    SMSetEnabled(!SMIsEnabled());
}

static void SMModuleHandleLongPress(id self,
                                    SEL _cmd)
{
    /*
     * Long press:
     * mở menu chọn thời gian.
     */
    SMShowTimeoutMenu(self);
}

#pragma mark - Runtime class creation

static Class SMCreateModuleClass(void)
{
    Class baseClass =
        NSClassFromString(@"CCUIToggleModule");

    if (!baseClass) {

        NSLog(@"[SleepMode] Không tìm thấy CCUIToggleModule");

        return Nil;
    }

    Class existing =
        NSClassFromString(@"SleepModeModule");

    if (existing) {
        return existing;
    }

    Class moduleClass =
        objc_allocateClassPair(
            baseClass,
            "SleepModeModule",
            0
        );

    if (!moduleClass) {
        NSLog(@"[SleepMode] Không tạo được SleepModeModule");
        return Nil;
    }

    class_addMethod(
        moduleClass,
        @selector(isSelected),
        (IMP)SMModuleIsSelected,
        "c@:"
    );

    class_addMethod(
        moduleClass,
        @selector(setSelected:),
        (IMP)SMModuleSetSelected,
        "v@:c"
    );

    class_addMethod(
        moduleClass,
        @selector(identifier),
        (IMP)SMModuleIdentifierMethod,
        "@@:"
    );

    class_addMethod(
        moduleClass,
        @selector(title),
        (IMP)SMModuleTitle,
        "@@:"
    );

    class_addMethod(
        moduleClass,
        @selector(iconGlyph),
        (IMP)SMModuleIconGlyph,
        "@@:"
    );

    class_addMethod(
        moduleClass,
        @selector(selectedIconGlyph),
        (IMP)SMModuleSelectedIconGlyph,
        "@@:"
    );

    class_addMethod(
        moduleClass,
        @selector(setSelectedGlyphColor:),
        (IMP)SMModuleSetSelectedGlyphColor,
        "v@:@"
    );

    class_addMethod(
        moduleClass,
        @selector(hasContent),
        (IMP)SMModuleHasContent,
        "c@:"
    );

    class_addMethod(
        moduleClass,
        @selector(contentViewController),
        (IMP)SMModuleContentViewController,
        "@@:"
    );

    class_addMethod(
        moduleClass,
        @selector(handleTap),
        (IMP)SMModuleHandleTap,
        "v@:"
    );

    /*
     * CCSupport có thể gọi selector này khi
     * người dùng nhấn giữ module.
     */
    class_addMethod(
        moduleClass,
        @selector(handleLongPress),
        (IMP)SMModuleHandleLongPress,
        "v@:"
    );

    objc_registerClassPair(moduleClass);

    NSLog(@"[SleepMode] Đã tạo SleepModeModule");

    return moduleClass;
}

#pragma mark - Bootstrap

@interface SleepModeBootstrap : NSObject
@end

@implementation SleepModeBootstrap

+ (void)load
{
    SMCreateModuleClass();

    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    if ([defaults objectForKey:SMEnabledKey] == nil) {

        [defaults setBool:NO
                   forKey:SMEnabledKey];
    }

    if ([defaults objectForKey:SMTimeoutKey] == nil) {

        [defaults setDouble:15.0
                     forKey:SMTimeoutKey];
    }

    [defaults synchronize];

    NSLog(
        @"[SleepMode] Bootstrap OK - enabled=%d timeout=%.0f",
        SMIsEnabled(),
        SMCurrentTimeout()
    );
}

@end
