
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#pragma mark - Control Center private interface

@interface CCUIToggleModule : NSObject
@end

@interface SleepModeModule : CCUIToggleModule
- (BOOL)isSelected;
- (void)setSelected:(BOOL)selected;
- (NSString *)identifier;
- (NSString *)title;
- (void)setTitle:(NSString *)title;
- (UIImage *)iconImage;
- (UIImage *)selectedIconImage;
- (NSString *)iconGlyph;
- (NSString *)selectedIconGlyph;
- (void)setSelectedGlyphColor:(UIColor *)color;
- (BOOL)hasContent;
- (UIViewController *)contentViewController;
- (void)handleTap;
- (void)handleLongPress;
@end

#pragma mark - Constants

static NSString * const SMEnabledKey = @"SleepModeEnabled";
static NSString * const SMTimeoutKey = @"SleepModeTimeout";

static NSString * const SMCommandNotification =
    @"com.trantu.sleepmode.command";

static NSString * const SMStateChangedNotification =
    @"com.trantu.sleepmode.stateChanged";

static NSString * const SMModuleIdentifier =
    @"com.trantu.sleepmode.module";

#pragma mark - Settings

static BOOL SMIsEnabled(void)
{
    return [[NSUserDefaults standardUserDefaults]
            boolForKey:SMEnabledKey];
}

static NSTimeInterval SMCurrentTimeout(void)
{
    NSTimeInterval timeout =
        [[NSUserDefaults standardUserDefaults]
            doubleForKey:SMTimeoutKey];

    return timeout > 0.0 ? timeout : 15.0;
}

static void SMSetEnabled(BOOL enabled)
{
    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    [defaults setBool:enabled forKey:SMEnabledKey];
    [defaults synchronize];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SMCommandNotification
        object:nil
        userInfo:@{@"enabled": @(enabled)}];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SMStateChangedNotification
        object:nil];
}

static void SMSetTimeout(NSTimeInterval timeout)
{
    if (timeout < 1.0) timeout = 1.0;
    if (timeout > 86400.0) timeout = 86400.0;

    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    [defaults setDouble:timeout forKey:SMTimeoutKey];
    [defaults synchronize];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SMCommandNotification
        object:nil
        userInfo:@{@"timeout": @(timeout)}];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SMStateChangedNotification
        object:nil];
}

#pragma mark - Safe view controller lookup

static UIWindow *SMFindActiveWindow(void)
{
    UIApplication *application =
        [UIApplication sharedApplication];

    if (!application) return nil;

    UIWindow *fallback = nil;

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in application.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]])
                continue;

            UIWindowScene *windowScene = (UIWindowScene *)scene;

            if (windowScene.activationState !=
                UISceneActivationStateForegroundActive)
                continue;

            for (UIWindow *window in windowScene.windows) {
                if (window.hidden || window.alpha <= 0.01)
                    continue;

                if (window.isKeyWindow)
                    return window;

                if (!fallback)
                    fallback = window;
            }
        }
    }

    if (fallback)
        return fallback;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    for (UIWindow *window in application.windows) {
        if (window.hidden || window.alpha <= 0.01)
            continue;

        if (window.isKeyWindow)
            return window;

        if (!fallback)
            fallback = window;
    }
#pragma clang diagnostic pop

    return fallback;
}

static UIViewController *SMGetTopController(
    UIViewController *controller)
{
    if (!controller) return nil;

    if (controller.presentedViewController &&
        !controller.presentedViewController.isBeingDismissed) {
        return SMGetTopController(
            controller.presentedViewController
        );
    }

    if ([controller isKindOfClass:
         [UINavigationController class]]) {
        UINavigationController *nav =
            (UINavigationController *)controller;

        if (nav.visibleViewController)
            return SMGetTopController(nav.visibleViewController);
    }

    if ([controller isKindOfClass:
         [UITabBarController class]]) {
        UITabBarController *tabs =
            (UITabBarController *)controller;

        if (tabs.selectedViewController)
            return SMGetTopController(tabs.selectedViewController);
    }

    return controller;
}

#pragma mark - Timeout menu

static void SMShowTimeoutMenu(void)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = SMFindActiveWindow();

        if (!window || !window.rootViewController)
            return;

        UIViewController *controller =
            SMGetTopController(window.rootViewController);

        if (!controller ||
            controller.isBeingDismissed ||
            controller.presentedViewController) {
            return;
        }

        UIAlertController *alert =
            [UIAlertController
                alertControllerWithTitle:@"Thời gian tự khóa"
                message:@"Chọn thời gian chờ"
                preferredStyle:UIAlertControllerStyleActionSheet];

        NSArray *items = @[
            @{@"title": @"15 giây", @"value": @15.0},
            @{@"title": @"1 phút",   @"value": @60.0},
            @{@"title": @"5 phút",  @"value": @300.0},
            @{@"title": @"15 phút", @"value": @900.0},
            @{@"title": @"30 phút", @"value": @1800.0},
            @{@"title": @"1 giờ",   @"value": @3600.0},
            @{@"title": @"2 giờ",   @"value": @7200.0}
        ];

        NSTimeInterval current = SMCurrentTimeout();

        for (NSDictionary *item in items) {
            NSString *title = item[@"title"];
            NSNumber *value = item[@"value"];

            if (fabs(current - value.doubleValue) < 0.5) {
                title = [NSString stringWithFormat:@"✓ %@", title];
            }

            [alert addAction:
                [UIAlertAction
                    actionWithTitle:title
                    style:UIAlertActionStyleDefault
                    handler:^(__unused UIAlertAction *action) {
                        SMSetTimeout(value.doubleValue);
                    }]
            ];
        }

        [alert addAction:
            [UIAlertAction
                actionWithTitle:@"Hủy"
                style:UIAlertActionStyleCancel
                handler:nil]
        ];

        UIPopoverPresentationController *popover =
            alert.popoverPresentationController;

        if (popover) {
            popover.sourceView = window;
            popover.sourceRect = CGRectMake(
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
    });
}

#pragma mark - SleepModeModule

@implementation SleepModeModule

- (BOOL)isSelected
{
    return SMIsEnabled();
}

- (void)setSelected:(BOOL)selected
{
    SMSetEnabled(selected);
}

- (NSString *)identifier
{
    return SMModuleIdentifier;
}

- (NSString *)title
{
    return @"Chế độ ngủ";
}

- (void)setTitle:(NSString *)title
{
    (void)title;
}

- (UIImage *)iconImage
{
    return [UIImage systemImageNamed:@"moon.fill"];
}

- (UIImage *)selectedIconImage
{
    return [UIImage systemImageNamed:@"moon.fill"];
}

- (NSString *)iconGlyph
{
    return @"moon.fill";
}

- (NSString *)selectedIconGlyph
{
    return @"moon.fill";
}

- (void)setSelectedGlyphColor:(UIColor *)color
{
    (void)color;
}

- (BOOL)hasContent
{
    return NO;
}

- (UIViewController *)contentViewController
{
    return nil;
}

- (void)handleTap
{
    SMSetEnabled(!SMIsEnabled());
}

- (void)handleLongPress
{
    SMShowTimeoutMenu();
}

@end
