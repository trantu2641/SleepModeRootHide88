#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "SleepControlCenter.h"

/*
 * Theos iPhoneOS16.5 SDK không cung cấp:
 *
 *     ControlCenterUI/CCUIToggleModule.h
 *
 * nhưng class CCUIToggleModule tồn tại trên iOS.
 *
 * Khai báo tối thiểu để compiler có thể build.
 */
@interface CCUIToggleModule : NSObject

- (instancetype)init;

- (BOOL)isSelected;
- (void)setSelected:(BOOL)selected;

- (void)toggleState;

- (NSString *)displayName;
- (NSString *)title;

- (UIImage *)iconGlyph;
- (UIImage *)selectedIconGlyph;

- (UIViewController *)contentViewController;

@end


@interface SleepModeModule : CCUIToggleModule
@end


@implementation SleepModeModule

#pragma mark - Init

- (instancetype)init
{
    self = [super init];

    if (self) {
        /*
         * Không gọi setSelected: ở đây.
         * Trạng thái thật sẽ được Control Center hỏi qua isSelected.
         */
    }

    return self;
}


#pragma mark - State

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


    /*
     * Gửi lệnh cho SleepManager đang chạy trong SpringBoard.
     */
    [[NSNotificationCenter defaultCenter]
        postNotificationName:SleepModeCommandNotification
                      object:nil
                    userInfo:info];


    [[NSNotificationCenter defaultCenter]
        postNotificationName:SleepModeStateChangedNotification
                      object:nil];
}


#pragma mark - Toggle

- (void)toggleState
{
    BOOL newState = ![self isSelected];

    [self setSelected:newState];
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
    NSBundle *bundle =
        [NSBundle bundleForClass:[self class]];

    UIImage *image =
        [UIImage imageNamed:@"icon"
                  inBundle:bundle
             compatibleWithTraitCollection:nil];

    return image;
}


- (UIImage *)selectedIconGlyph
{
    NSBundle *bundle =
        [NSBundle bundleForClass:[self class]];

    UIImage *image =
        [UIImage imageNamed:@"icon"
                  inBundle:bundle
             compatibleWithTraitCollection:nil];

    return image;
}


#pragma mark - Content View Controller

- (UIViewController *)contentViewController
{
    /*
     * Module 1×1 không cần một giao diện mở rộng riêng.
     *
     * Trả nil để Control Center dùng giao diện toggle mặc định.
     */
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


    NSTimeInterval currentTimeout =
        [[NSUserDefaults standardUserDefaults]
            doubleForKey:SleepModeTimeoutKey];


    for (NSDictionary *item in timeouts) {

        NSString *title =
            item[@"title"];

        NSTimeInterval value =
            [item[@"value"] doubleValue];


        NSString *displayTitle =
            title;


        if (fabs(currentTimeout - value) < 0.1) {

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
                postNotificationName:
                    SleepModeCommandNotification
                              object:nil
                            userInfo:info];


            [[NSNotificationCenter defaultCenter]
                postNotificationName:
                    SleepModeStateChangedNotification
                              object:nil];
        }];


        [alert addAction:action];
    }


    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"Hủy"
                     style:UIAlertActionStyleCancel
                   handler:nil]];


    /*
     * Tìm ViewController hiện tại của SpringBoard/Control Center.
     */
    UIApplication *application =
        [UIApplication sharedApplication];


    UIViewController *presentingController = nil;


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

@end
