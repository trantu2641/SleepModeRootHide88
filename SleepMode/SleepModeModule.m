#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "SleepControlCenter.h"

#import <ControlCenterUI/CCUIToggleModule.h>

@interface SleepModeModule : CCUIToggleModule
@end

@implementation SleepModeModule

#pragma mark - Init

- (instancetype)init
{
    self = [super init];

    if (self) {
        [self updateModuleState];
    }

    return self;
}

#pragma mark - Control Center state

- (BOOL)isSelected
{
    return [[NSUserDefaults standardUserDefaults]
            boolForKey:SleepModeEnabledKey];
}

- (void)setSelected:(BOOL)selected
{
    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    [defaults setBool:selected
               forKey:SleepModeEnabledKey];

    [defaults synchronize];

    NSDictionary *info = @{
        @"enabled": @(selected)
    };

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SleepModeCommandNotification
                      object:nil
                    userInfo:info];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SleepModeStateChangedNotification
                      object:nil];

    [self updateModuleState];
}

#pragma mark - Toggle

- (void)toggleState
{
    [self setSelected:![self isSelected]];
}

#pragma mark - Title

- (NSString *)displayName
{
    return @"Chế độ ngủ";
}

- (NSString *)title
{
    return @"Ngủ";
}

#pragma mark - Icon

- (UIImage *)iconGlyph
{
    UIImage *image =
        [UIImage imageNamed:@"icon"
                  inBundle:[NSBundle bundleForClass:[self class]]
             compatibleWithTraitCollection:nil];

    return image;
}

- (UIImage *)selectedIconGlyph
{
    UIImage *image =
        [UIImage imageNamed:@"icon"
                  inBundle:[NSBundle bundleForClass:[self class]]
             compatibleWithTraitCollection:nil];

    return image;
}

#pragma mark - Module state

- (void)updateModuleState
{
    BOOL enabled = [self isSelected];

    if ([self respondsToSelector:@selector(setSelected:)]) {
        [super setSelected:enabled];
    }
}

#pragma mark - Content View Controller

- (UIViewController *)contentViewController
{
    UIViewController *controller =
        [super contentViewController];

    if (controller) {
        return controller;
    }

    return nil;
}

#pragma mark - Long press

- (void)handleLongPress
{
    [self showTimeoutMenu];
}

- (void)showTimeoutMenu
{
    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:@"Thời gian tự khóa"
                             message:@"Chọn thời gian"
                      preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray *timeouts = @[
        @{@"title": @"15 giây", @"value": @15.0},
        @{@"title": @"1 phút",  @"value": @60.0},
        @{@"title": @"5 phút",  @"value": @300.0},
        @{@"title": @"15 phút", @"value": @900.0},
        @{@"title": @"30 phút", @"value": @1800.0},
        @{@"title": @"1 giờ",   @"value": @3600.0},
        @{@"title": @"2 giờ",   @"value": @7200.0}
    ];

    NSTimeInterval current =
        [[NSUserDefaults standardUserDefaults]
            doubleForKey:SleepModeTimeoutKey];

    for (NSDictionary *item in timeouts) {

        NSString *title = item[@"title"];
        NSTimeInterval value =
            [item[@"value"] doubleValue];

        NSString *displayTitle = title;

        if (fabs(current - value) < 0.1) {
            displayTitle =
                [NSString stringWithFormat:@"✓ %@", title];
        }

        UIAlertAction *action =
            [UIAlertAction
                actionWithTitle:displayTitle
                         style:UIAlertActionStyleDefault
                       handler:^(UIAlertAction *action) {

            NSUserDefaults *defaults =
                [NSUserDefaults standardUserDefaults];

            [defaults setDouble:value
                         forKey:SleepModeTimeoutKey];

            [defaults synchronize];

            NSDictionary *info = @{
                @"timeout": @(value)
            };

            [[NSNotificationCenter defaultCenter]
                postNotificationName:SleepModeCommandNotification
                              object:nil
                            userInfo:info];

            [[NSNotificationCenter defaultCenter]
                postNotificationName:SleepModeStateChangedNotification
                              object:nil];
        }];

        [alert addAction:action];
    }

    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"Hủy"
                     style:UIAlertActionStyleCancel
                   handler:nil]];

    UIViewController *presentingController = nil;

    UIApplication *application =
        [UIApplication sharedApplication];

    for (UIWindow *window in application.windows) {

        if (window.isKeyWindow) {
            presentingController =
                window.rootViewController;
            break;
        }
    }

    while (presentingController.presentedViewController) {
        presentingController =
            presentingController.presentedViewController;
    }

    if (presentingController) {
        [presentingController
            presentViewController:alert
                         animated:YES
                       completion:nil];
    }
}

#pragma mark - Expansion

- (BOOL)canExpand
{
    return YES;
}

- (BOOL)shouldBeginTransitionToExpandedContentModule
{
    return YES;
}

@end
