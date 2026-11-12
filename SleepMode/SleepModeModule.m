#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "SleepControlCenter.h"


/*
 * Theos iPhoneOS16.5.sdk không có:
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
         * Không cần khởi tạo timer ở đây.
         * SleepManager nằm trong SpringBoard.
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
     * Gửi trạng thái tới SleepManager.
     */
    [[NSNotificationCenter defaultCenter]
        postNotificationName:SleepModeCommandNotification
                      object:nil
                    userInfo:info];


    /*
     * Báo cho các thành phần khác của SleepMode
     * rằng trạng thái đã thay đổi.
     */
    [[NSNotificationCenter defaultCenter]
        postNotificationName:SleepModeStateChangedNotification
                      object:nil];
}


#pragma mark - Toggle

- (void)toggleState
{
    BOOL current =
        [self isSelected];

    [self setSelected:!current];
}


#pragma mark - Display name

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
     * Tile 1×1 không cần content controller riêng.
     */
    return nil;
}


#pragma mark - Long press

- (void)handleLongPress
{
    [self showTimeoutMenu];
}


#pragma mark - Timeout menu

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
     * Không dùng UIApplication.windows nữa.
     *
     * Control Center tự quản lý presentation.
     *
     * Nếu cần menu mở rộng về sau, ta sẽ dùng
     * expandedContentViewController của CCUIToggleModule
     * thay vì tự present UIAlertController.
     */
}


@end
