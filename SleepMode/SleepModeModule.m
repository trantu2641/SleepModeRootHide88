#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>

#import "SleepControlCenter.h"

@interface CCUIToggleModule : NSObject
- (instancetype)init;
@end

@interface SleepModeModule : CCUIToggleModule
@end


static NSString * const kSleepModeIdentifier =
    @"com.trantu.sleepmode";

static NSString * const kSleepModeEnabledKey =
    @"SleepModeEnabled";

static NSString * const kSleepModeTimeoutKey =
    @"SleepModeTimeout";


@implementation SleepModeModule


#pragma mark - Init

- (instancetype)init
{
    self = [super init];

    if (self) {
        NSUserDefaults *defaults =
            [NSUserDefaults standardUserDefaults];

        if ([defaults objectForKey:kSleepModeEnabledKey] == nil) {
            [defaults setBool:NO
                       forKey:kSleepModeEnabledKey];
        }

        if ([defaults objectForKey:kSleepModeTimeoutKey] == nil) {
            [defaults setDouble:15.0
                         forKey:kSleepModeTimeoutKey];
        }
    }

    return self;
}


#pragma mark - Identifier

- (NSString *)identifier
{
    return kSleepModeIdentifier;
}

- (NSString *)moduleIdentifier
{
    return kSleepModeIdentifier;
}


#pragma mark - Title

- (NSString *)displayName
{
    return @"Chế độ ngủ";
}

- (NSString *)title
{
    return @"Chế độ ngủ";
}


#pragma mark - Selected State

- (BOOL)isSelected
{
    return [[NSUserDefaults standardUserDefaults]
            boolForKey:kSleepModeEnabledKey];
}

- (BOOL)selected
{
    return [self isSelected];
}

- (void)setSelected:(BOOL)selected
{
    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    [defaults setBool:selected
               forKey:kSleepModeEnabledKey];

    [defaults synchronize];

    SleepControlCenter *control =
        [SleepControlCenter sharedInstance];

    if (selected) {
        [control enable];
    } else {
        [control disable];
    }

    [[NSNotificationCenter defaultCenter]
        postNotificationName:
            SleepModeStateChangedNotification
        object:nil];

    [self refreshModuleState];
}


#pragma mark - Tap

- (void)handleTap
{
    [self setSelected:![self isSelected]];
}

- (void)activate
{
    [self handleTap];
}


#pragma mark - Icon

- (UIImage *)iconImage
{
    NSBundle *bundle =
        [NSBundle bundleForClass:[self class]];

    NSString *path =
        [bundle pathForResource:
            @"SleepModeModuleIcon"
            ofType:@"png"];

    if (!path) {
        path =
            [bundle pathForResource:
                @"SleepModeModuleIcon@3x"
                ofType:@"png"];
    }

    if (!path) {
        return nil;
    }

    return [UIImage imageWithContentsOfFile:path];
}

- (UIImage *)selectedIconImage
{
    return [self iconImage];
}


#pragma mark - Glyph

- (NSString *)iconGlyph
{
    return @"moon.zzz.fill";
}

- (NSString *)selectedIconGlyph
{
    return @"moon.zzz.fill";
}

- (void)setSelectedGlyphColor:(UIColor *)color
{
    /*
     * CCSupport tự xử lý màu của trạng thái selected.
     */
}


#pragma mark - State

- (void)refreshModuleState
{
    /*
     * Không gọi private selector trực tiếp.
     *
     * State được lưu trong NSUserDefaults và
     * SleepControlCenter xử lý phần logic.
     */
}


#pragma mark - Long Press

- (void)handleLongPress
{
    NSTimeInterval current =
        [[NSUserDefaults standardUserDefaults]
         doubleForKey:kSleepModeTimeoutKey];

    if (current <= 0.0) {
        current = 15.0;
    }

    UIWindow *window = nil;


    /*
     * iOS 13+
     *
     * Không sử dụng UIApplication.keyWindow
     * vì API này deprecated từ iOS 13.
     */
    if (@available(iOS 13.0, *)) {

        NSSet<UIScene *> *scenes =
            [UIApplication sharedApplication].connectedScenes;

        for (UIScene *scene in scenes) {

            if (scene.activationState !=
                UISceneActivationStateForegroundActive) {
                continue;
            }

            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }

            UIWindowScene *windowScene =
                (UIWindowScene *)scene;

            for (UIWindow *candidate
                 in windowScene.windows) {

                if (candidate.hidden) {
                    continue;
                }

                if (candidate.alpha <= 0.0) {
                    continue;
                }

                if (candidate.windowLevel !=
                    UIWindowLevelNormal) {
                    continue;
                }

                if (candidate.rootViewController == nil) {
                    continue;
                }

                /*
                 * Ưu tiên key window.
                 */
                if (candidate.isKeyWindow) {
                    window = candidate;
                    break;
                }

                /*
                 * Nếu chưa tìm được key window,
                 * giữ lại window hợp lệ đầu tiên.
                 */
                if (!window) {
                    window = candidate;
                }
            }

            if (window && window.isKeyWindow) {
                break;
            }
        }

    } else {

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

        NSArray *windows =
            [UIApplication sharedApplication].windows;

        for (UIWindow *candidate in windows) {

            if (candidate.hidden) {
                continue;
            }

            if (candidate.alpha <= 0.0) {
                continue;
            }

            if (candidate.rootViewController == nil) {
                continue;
            }

            window = candidate;
            break;
        }

#pragma clang diagnostic pop
    }


    if (!window) {
        return;
    }


    UIViewController *root =
        window.rootViewController;

    if (!root) {
        return;
    }


    /*
     * Nếu đang có một ViewController khác
     * được trình bày, lấy controller ngoài cùng.
     */
    while (root.presentedViewController) {
        root = root.presentedViewController;
    }


    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:@"Chế độ ngủ"
                             message:@"Tự khóa sau"
                      preferredStyle:UIAlertControllerStyleActionSheet];


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


    for (NSDictionary *item in options) {

        NSString *title =
            item[@"title"];

        NSNumber *value =
            item[@"value"];


        BOOL isCurrent =
            (fabs([value doubleValue] - current) < 0.5);


        NSString *finalTitle =
            isCurrent
                ? [NSString stringWithFormat:
                       @"✓ %@", title]
                : title;


        UIAlertAction *action =
            [UIAlertAction
                actionWithTitle:finalTitle
                         style:UIAlertActionStyleDefault
                       handler:^(UIAlertAction *action) {

            SleepControlCenter *control =
                [SleepControlCenter sharedInstance];

            [control setTimeout:
                [value doubleValue]];

        }];


        [alert addAction:action];
    }


    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"Hủy"
                     style:UIAlertActionStyleCancel
                   handler:nil]];


    /*
     * An toàn cho cả iPhone và iPad.
     */
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
    }


    [root presentViewController:
        alert
           animated:YES
         completion:nil];
}


#pragma mark - Content

- (BOOL)hasContent
{
    return NO;
}

- (UIViewController *)contentViewController
{
    return nil;
}


#pragma mark - Description

- (NSString *)description
{
    return @"SleepMode Control Center Module";
}


@end
