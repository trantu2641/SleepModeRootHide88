#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>

#import "SleepControlCenter.h"

/*
 * CCSupport / ControlCenter
 *
 * Immortalizer sử dụng trực tiếp:
 *
 *     CCUIToggleModule
 *
 * và bundle Info.plist:
 *
 *     NSPrincipalClass = ImmortalizerCC
 *
 * SleepMode làm tương tự.
 */

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

/*
 * CCSupport dùng identifier để nhận diện module.
 */
- (NSString *)identifier
{
    return kSleepModeIdentifier;
}


/*
 * Một số phiên bản ControlCenter dùng moduleIdentifier.
 * Có cả hai để tương thích.
 */
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


#pragma mark - Selected

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


#pragma mark - Toggle

- (void)handleTap
{
    [self setSelected:![self isSelected]];
}


/*
 * CCSupport gọi activate / handleTap tùy phiên bản.
 */
- (void)activate
{
    [self handleTap];
}


#pragma mark - Icon

/*
 * Icon của tile.
 *
 * CCSupport có thể lấy icon bằng glyph hoặc UIImage.
 * Giữ cả hai cách để tương thích.
 */

- (UIImage *)iconImage
{
    NSBundle *bundle =
        [NSBundle bundleForClass:[self class]];

    NSString *path =
        [bundle pathForResource:@"SleepModeModuleIcon"
                        ofType:@"png"];

    if (!path) {
        path =
            [bundle pathForResource:@"SleepModeModuleIcon@3x"
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

/*
 * Một số bản CCSupport ưu tiên glyph.
 * Dùng SF Symbol nếu hệ thống hỗ trợ.
 */

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
     * CCSupport tự xử lý màu selected.
     * Không cần giữ state màu riêng.
     */
}


#pragma mark - State refresh

- (void)refreshModuleState
{
    /*
     * Một số phiên bản CCSupport có phương thức
     * updateState / reloadState.
     *
     * Không gọi trực tiếp private selector nếu chưa tồn tại.
     */
}


#pragma mark - Long press

/*
 * Nhấn giữ tile để chọn thời gian.
 *
 * Không tạo UIViewController riêng.
 * Immortalizer cũng sử dụng action menu trực tiếp
 * thông qua Control Center module.
 */

- (void)handleLongPress
{
    NSTimeInterval current =
        [[NSUserDefaults standardUserDefaults]
         doubleForKey:kSleepModeTimeoutKey];

    if (current <= 0) {
        current = 15.0;
    }

    /*
     * Tạo UIAlertController trên window hiện tại.
     */

    UIWindow *window = nil;

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene
             in [UIApplication sharedApplication].connectedScenes) {

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

                if (candidate.isKeyWindow) {
                    window = candidate;
                    break;
                }
            }

            if (window) {
                break;
            }
        }
    }

    if (!window) {
        window =
            [UIApplication sharedApplication].keyWindow;
    }

    if (!window) {
        return;
    }

    UIViewController *root =
        window.rootViewController;

    if (!root) {
        return;
    }

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


    [root presentViewController:
        alert
           animated:YES
         completion:nil];
}


#pragma mark - Content

/*
 * Module là toggle 1×1 nên không cần content view.
 */
- (BOOL)hasContent
{
    return NO;
}

- (UIViewController *)contentViewController
{
    return nil;
}


#pragma mark - Debug description

- (NSString *)description
{
    return @"SleepMode Control Center Module";
}


@end
