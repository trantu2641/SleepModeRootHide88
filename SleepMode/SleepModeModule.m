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

static BOOL SMIsEnabled(void)
{
    return [[NSUserDefaults standardUserDefaults]
        boolForKey:SMEnabledKey];
}

static void SMSetEnabled(BOOL enabled)
{
    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    [defaults setBool:enabled
               forKey:SMEnabledKey];

    [defaults synchronize];

    NSLog(
        @"[SleepMode] Set enabled = %d",
        enabled
    );

    [[NSNotificationCenter defaultCenter]
        postNotificationName:
            SMCommandNotification
        object:nil
        userInfo:@{
            @"enabled": @(enabled)
        }];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:
            SMStateChangedNotification
        object:nil];
}

static NSTimeInterval SMCurrentTimeout(void)
{
    NSTimeInterval timeout =
        [[NSUserDefaults standardUserDefaults]
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
        [NSUserDefaults standardUserDefaults];

    [defaults setDouble:timeout
                  forKey:SMTimeoutKey];

    [defaults synchronize];

    NSLog(
        @"[SleepMode] Set timeout = %.0f",
        timeout
    );

    [[NSNotificationCenter defaultCenter]
        postNotificationName:
            SMCommandNotification
        object:nil
        userInfo:@{
            @"timeout": @(timeout)
        }];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:
            SMStateChangedNotification
        object:nil];
}

static void SMResetTimer(void)
{
    NSLog(
        @"[SleepMode] Reset timer"
    );

    [[NSNotificationCenter defaultCenter]
        postNotificationName:
            SMCommandNotification
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
        NSLog(
            @"[SleepMode] Không lấy được UIApplication"
        );

        return nil;
    }

    UIWindow *fallbackWindow = nil;

    for (UIScene *scene
         in application.connectedScenes) {

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

            if (!fallbackWindow) {
                fallbackWindow = window;
            }
        }
    }

    return fallbackWindow;
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

        UINavigationController *navigation =
            (UINavigationController *)controller;

        UIViewController *visible =
            navigation.visibleViewController;

        if (visible) {

            return SMTopViewController(
                visible
            );
        }
    }

    if ([controller isKindOfClass:
         [UITabBarController class]]) {

        UITabBarController *tabs =
            (UITabBarController *)controller;

        UIViewController *selected =
            tabs.selectedViewController;

        if (selected) {

            return SMTopViewController(
                selected
            );
        }
    }

    return controller;
}


#pragma mark - Timeout menu

static void SMShowTimeoutMenu(void)
{
    NSLog(
        @"[SleepMode] Mở menu thời gian"
    );

    UIWindow *window =
        SMFindActiveWindow();

    if (!window) {

        NSLog(
            @"[SleepMode] ERROR: "
             "Không tìm thấy active window"
        );

        return;
    }

    UIViewController *controller =
        SMTopViewController(
            window.rootViewController
        );

    if (!controller) {

        NSLog(
            @"[SleepMode] ERROR: "
             "Không tìm thấy view controller"
        );

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

    NSArray *items = @[
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
         in items) {

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


#pragma mark - Module methods

static BOOL
SMIsSelected(id self,
             SEL _cmd)
{
    (void)self;
    (void)_cmd;

    BOOL enabled =
        SMIsEnabled();

    NSLog(
        @"[SleepMode] isSelected -> %d",
        enabled
    );

    return enabled;
}

static void
SMSetSelected(id self,
              SEL _cmd,
              BOOL selected)
{
    (void)self;
    (void)_cmd;

    NSLog(
        @"[SleepMode] setSelected -> %d",
        selected
    );

    SMSetEnabled(selected);
}

static NSString *
SMIdentifier(id self,
             SEL _cmd)
{
    (void)self;
    (void)_cmd;

    NSLog(
        @"[SleepMode] identifier -> %@",
        SMModuleIdentifier
    );

    return SMModuleIdentifier;
}

static NSString *
SMTitle(id self,
        SEL _cmd)
{
    (void)self;
    (void)_cmd;

    return @"Chế độ ngủ";
}

static void
SMSetTitle(id self,
           SEL _cmd,
           NSString *title)
{
    (void)self;
    (void)_cmd;
    (void)title;

    NSLog(
        @"[SleepMode] setTitle: %@",
        title
    );
}

static UIImage *
SMIconImage(id self,
            SEL _cmd)
{
    (void)self;
    (void)_cmd;

    if (@available(iOS 13.0, *)) {

        UIImageSymbolConfiguration *config =
            [UIImageSymbolConfiguration
                configurationWithPointSize:24.0
                weight:UIImageSymbolWeightMedium];

        UIImage *image =
            [UIImage
                systemImageNamed:
                    @"moon.fill"
                withConfiguration:
                    config];

        NSLog(
            @"[SleepMode] iconImage -> %@",
            image
        );

        return image;
    }

    return nil;
}

static UIImage *
SMSelectedIconImage(id self,
                    SEL _cmd)
{
    return SMIconImage(
        self,
        _cmd
    );
}

static NSString *
SMIconGlyph(id self,
            SEL _cmd)
{
    (void)self;
    (void)_cmd;

    return @"moon.fill";
}

static NSString *
SMSelectedIconGlyph(id self,
                    SEL _cmd)
{
    (void)self;
    (void)_cmd;

    return @"moon.fill";
}

static void
SMSetSelectedGlyphColor(
    id self,
    SEL _cmd,
    UIColor *color)
{
    (void)self;
    (void)_cmd;
    (void)color;
}

static BOOL
SMHasContent(id self,
             SEL _cmd)
{
    (void)self;
    (void)_cmd;

    return NO;
}

static UIViewController *
SMContentViewController(id self,
                        SEL _cmd)
{
    (void)self;
    (void)_cmd;

    return nil;
}

static void
SMHandleTap(id self,
            SEL _cmd)
{
    (void)self;
    (void)_cmd;

    BOOL newState =
        !SMIsEnabled();

    NSLog(
        @"[SleepMode] handleTap -> %d",
        newState
    );

    SMSetEnabled(newState);
}

static void
SMHandleLongPress(id self,
                  SEL _cmd)
{
    (void)self;
    (void)_cmd;

    NSLog(
        @"[SleepMode] handleLongPress"
    );

    SMShowTimeoutMenu();
}


#pragma mark - Runtime module creation

static Class
SMCreateModuleClass(void)
{
    NSLog(
        @"[SleepMode] "
         "SMCreateModuleClass() bắt đầu"
    );

    Class existing =
        NSClassFromString(
            @"SleepModeModule"
        );

    if (existing) {

        NSLog(
            @"[SleepMode] "
             "SleepModeModule đã tồn tại: %@",
            existing
        );

        return existing;
    }

    Class base =
        NSClassFromString(
            @"CCUIToggleModule"
        );

    NSLog(
        @"[SleepMode] "
         "CCUIToggleModule = %@",
        base
    );

    if (!base) {

        NSLog(
            @"[SleepMode] ERROR: "
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
            @"[SleepMode] ERROR: "
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
        @selector(setTitle:),
        (IMP)SMSetTitle,
        "v@:@"
    );

    class_addMethod(
        module,
        @selector(iconImage),
        (IMP)SMIconImage,
        "@@:"
    );

    class_addMethod(
        module,
        @selector(selectedIconImage),
        (IMP)SMSelectedIconImage,
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
        @selector(setSelectedGlyphColor:),
        (IMP)SMSetSelectedGlyphColor,
        "v@:@"
    );

    class_addMethod(
        module,
        @selector(hasContent),
        (IMP)SMHasContent,
        "c@:"
    );

    class_addMethod(
        module,
        @selector(contentViewController),
        (IMP)SMContentViewController,
        "@@:"
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

    objc_registerClassPair(
        module
    );

    NSLog(
        @"[SleepMode] "
         "SleepModeModule REGISTERED: %@",
        module
    );

    return module;
}


#pragma mark - Bootstrap

@interface SleepModeBootstrap : NSObject
@end

@implementation SleepModeBootstrap

+ (void)load
{
    NSLog(
        @"[SleepMode] "
         "SleepModeModule +load()"
    );

    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

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

    NSLog(
        @"[SleepMode] Defaults: "
         "enabled=%d timeout=%.0f",
        SMIsEnabled(),
        SMCurrentTimeout()
    );

    Class moduleClass =
        SMCreateModuleClass();

    NSLog(
        @"[SleepMode] Bootstrap moduleClass = %@",
        moduleClass
    );
}

@end
