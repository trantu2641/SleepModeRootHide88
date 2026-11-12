#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

#pragma mark - Shared constants

static NSString * const SMEnabledKey =
    @"SleepModeEnabled";

static NSString * const SMTimeoutKey =
    @"SleepModeTimeout";

static NSString * const SMCommandNotification =
    @"com.trantu.sleepmode.command";

static NSString * const SMStateChangedNotification =
    @"com.trantu.sleepmode.stateChanged";

static NSString * const SMIdentifier =
    @"com.trantu.sleepmode";


#pragma mark - Control actions

static void SMSetEnabled(BOOL enabled)
{
    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    [defaults setBool:enabled
               forKey:SMEnabledKey];

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


static BOOL SMIsEnabled(void)
{
    return [[NSUserDefaults standardUserDefaults]
        boolForKey:SMEnabledKey];
}


static void SMSetTimeout(NSTimeInterval timeout)
{
    if (timeout < 1.0) {
        timeout = 1.0;
    }

    if (timeout > 7200.0) {
        timeout = 7200.0;
    }

    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    [defaults setDouble:timeout
                 forKey:SMTimeoutKey];

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


static void SMResetTimer(void)
{
    [[NSNotificationCenter defaultCenter]
        postNotificationName:SMCommandNotification
        object:nil
        userInfo:@{
            @"reset": @YES
        }];
}


#pragma mark - Find active window

/*
 * Không dùng:
 *
 * UIApplication.windows
 * UIApplication.keyWindow
 *
 * vì cả hai đã deprecated từ iOS 13/15.
 *
 * ControlCenter/SpringBoard vẫn có thể có nhiều
 * UIWindowScene, nên duyệt scene hiện tại.
 */

static UIWindow *SMFindActiveWindow(void)
{
    UIApplication *application =
        [UIApplication sharedApplication];

    NSArray *scenes =
        application.connectedScenes.allObjects;

    UIWindow *fallbackWindow = nil;

    for (UIScene *scene in scenes) {

        if (![scene isKindOfClass:[UIWindowScene class]]) {
            continue;
        }

        UIWindowScene *windowScene =
            (UIWindowScene *)scene;

        NSArray *windows =
            windowScene.windows;

        for (UIWindow *window in windows) {

            if (!fallbackWindow) {
                fallbackWindow = window;
            }

            if (window.hidden) {
                continue;
            }

            if (window.alpha <= 0.0) {
                continue;
            }

            if (window.windowLevel != UIWindowLevelNormal) {
                continue;
            }

            if (window.rootViewController) {
                return window;
            }
        }
    }

    /*
     * Nếu không có window level Normal,
     * trả về window đầu tiên còn dùng được.
     */
    return fallbackWindow;
}


#pragma mark - Find top view controller

static UIViewController *
SMTopViewController(UIViewController *controller)
{
    if (!controller) {
        return nil;
    }

    UIViewController *presented =
        controller.presentedViewController;

    if (presented) {
        return SMTopViewController(presented);
    }

    if ([controller
            isKindOfClass:
                [UINavigationController class]]) {

        UINavigationController *navigation =
            (UINavigationController *)controller;

        return SMTopViewController(
            navigation.visibleViewController
        );
    }

    if ([controller
            isKindOfClass:
                [UITabBarController class]]) {

        UITabBarController *tab =
            (UITabBarController *)controller;

        return SMTopViewController(
            tab.selectedViewController
        );
    }

    return controller;
}


#pragma mark - Timeout menu

static void SMShowTimeoutMenu(id self)
{
    NSTimeInterval current =
        SMCurrentTimeout();

    NSString *currentText = nil;

    if (current < 60.0) {

        currentText =
            [NSString stringWithFormat:
                @"%.0f giây",
                current];

    }
    else if (current < 3600.0) {

        currentText =
            [NSString stringWithFormat:
                @"%.0f phút",
                current / 60.0];

    }
    else {

        currentText =
            [NSString stringWithFormat:
                @"%.0f giờ",
                current / 3600.0];
    }


    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:@"Chế độ ngủ"
            message:
                [NSString stringWithFormat:
                    @"Thời gian hiện tại: %@",
                    currentText]
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


    for (NSDictionary *item in items) {

        NSString *title =
            item[@"title"];

        NSNumber *value =
            item[@"value"];

        BOOL selected =
            fabs(
                [value doubleValue] - current
            ) < 0.5;

        NSString *finalTitle =
            selected
                ? [NSString stringWithFormat:
                    @"✓ %@",
                    title]
                : title;


        UIAlertAction *action =
            [UIAlertAction
                actionWithTitle:finalTitle
                style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {

                    SMSetTimeout(
                        [value doubleValue]
                    );

                }];


        [alert addAction:action];
    }


    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"Hủy"
            style:UIAlertActionStyleCancel
            handler:nil]];


    UIWindow *window =
        SMFindActiveWindow();

    if (!window) {
        return;
    }


    UIViewController *vc =
        SMTopViewController(
            window.rootViewController
        );

    if (!vc) {
        return;
    }


    /*
     * Nếu đang ở iPad / ControlCenter và
     * action sheet cần sourceView thì thiết lập
     * để tránh crash.
     */
    if (alert.popoverPresentationController) {

        alert.popoverPresentationController.sourceView =
            vc.view;

        alert.popoverPresentationController.sourceRect =
            CGRectMake(
                CGRectGetMidX(vc.view.bounds),
                CGRectGetMidY(vc.view.bounds),
                1.0,
                1.0
            );

        alert.popoverPresentationController.permittedArrowDirections =
            0;
    }


    [vc presentViewController:alert
                     animated:YES
                   completion:nil];
}


#pragma mark - Runtime CCUIToggleModule

static BOOL
SMModuleIsSelected(id self,
                   SEL _cmd)
{
    return SMIsEnabled();
}


static void
SMModuleSetSelected(id self,
                    SEL _cmd,
                    BOOL selected)
{
    SMSetEnabled(selected);
}


static NSString *
SMModuleIdentifier(id self,
                   SEL _cmd)
{
    return SMIdentifier;
}


static NSString *
SMModuleTitle(id self,
              SEL _cmd)
{
    return @"Chế độ ngủ";
}


static UIImage *
SMModuleGlyph(id self,
              SEL _cmd)
{
    NSBundle *bundle =
        [NSBundle bundleForClass:[self class]];

    NSString *path =
        [bundle pathForResource:@"icon"
                         ofType:@"png"];

    if (path) {
        return [UIImage imageWithContentsOfFile:path];
    }

    return nil;
}


static UIImage *
SMModuleSelectedGlyph(id self,
                      SEL _cmd)
{
    return SMModuleGlyph(self, _cmd);
}


static void
SMModuleSetSelectedGlyphColor(id self,
                              SEL _cmd,
                              UIColor *color)
{
    /*
     * Không cần xử lý.
     */
}


static UIViewController *
SMModuleContentViewController(id self,
                              SEL _cmd)
{
    return nil;
}


static BOOL
SMModuleHasContent(id self,
                   SEL _cmd)
{
    return NO;
}


static void
SMModuleHandleTap(id self,
                  SEL _cmd)
{
    SMSetEnabled(
        !SMIsEnabled()
    );
}


#pragma mark - Runtime class creation

static void
SMSupplyMethod(Class cls,
               SEL selector,
               const char *types,
               IMP implementation)
{
    class_addMethod(
        cls,
        selector,
        implementation,
        types
    );
}


static void
SMCreateModuleClass(void)
{
    if (NSClassFromString(@"SleepModeModule")) {
        return;
    }


    /*
     * Không link CCUIToggleModule.
     *
     * Lấy class trực tiếp từ ControlCenter
     * lúc runtime.
     */
    Class superClass =
        NSClassFromString(
            @"CCUIToggleModule"
        );

    if (!superClass) {

        NSLog(
            @"[SleepMode] Không tìm thấy CCUIToggleModule runtime"
        );

        return;
    }


    Class moduleClass =
        objc_allocateClassPair(
            superClass,
            "SleepModeModule",
            0
        );

    if (!moduleClass) {

        NSLog(
            @"[SleepMode] Không tạo được SleepModeModule"
        );

        return;
    }


    /*
     * isSelected
     */
    SMSupplyMethod(
        moduleClass,
        @selector(isSelected),
        "c@:",
        (IMP)SMModuleIsSelected
    );


    /*
     * setSelected:
     */
    SMSupplyMethod(
        moduleClass,
        @selector(setSelected:),
        "v@:c",
        (IMP)SMModuleSetSelected
    );


    /*
     * identifier
     */
    SMSupplyMethod(
        moduleClass,
        @selector(identifier),
        "@@:",
        (IMP)SMModuleIdentifier
    );


    /*
     * title
     */
    SMSupplyMethod(
        moduleClass,
        @selector(title),
        "@@:",
        (IMP)SMModuleTitle
    );


    /*
     * iconGlyph
     */
    SMSupplyMethod(
        moduleClass,
        @selector(iconGlyph),
        "@@:",
        (IMP)SMModuleGlyph
    );


    /*
     * selectedIconGlyph
     */
    SMSupplyMethod(
        moduleClass,
        @selector(selectedIconGlyph),
        "@@:",
        (IMP)SMModuleSelectedGlyph
    );


    /*
     * selected glyph color
     */
    SMSupplyMethod(
        moduleClass,
        @selector(setSelectedGlyphColor:),
        "v@:@",
        (IMP)SMModuleSetSelectedGlyphColor
    );


    /*
     * Expanded content
     */
    SMSupplyMethod(
        moduleClass,
        @selector(contentViewController),
        "@@:",
        (IMP)SMModuleContentViewController
    );


    SMSupplyMethod(
        moduleClass,
        @selector(hasContent),
        "c@:",
        (IMP)SMModuleHasContent
    );


    /*
     * Tap
     */
    SMSupplyMethod(
        moduleClass,
        @selector(handleTap),
        "v@:",
        (IMP)SMModuleHandleTap
    );


    objc_registerClassPair(
        moduleClass
    );


    NSLog(
        @"[SleepMode] Đã tạo SleepModeModule runtime"
    );
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


    if ([defaults
            objectForKey:SMEnabledKey] == nil) {

        [defaults setBool:NO
                   forKey:SMEnabledKey];
    }


    if ([defaults
            objectForKey:SMTimeoutKey] == nil) {

        [defaults setDouble:15.0
                     forKey:SMTimeoutKey];
    }


    [defaults synchronize];
}

@end
