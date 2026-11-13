#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <CoreFoundation/CoreFoundation.h>

static NSString * const kDomain =
    @"com.trantu.sleepmode";

static NSString * const kChangedNotification =
    @"com.trantu.sleepmode.settingsChanged";

@interface SleepModePrefsListController : PSListController
@end

@implementation SleepModePrefsListController

- (instancetype)init
{
    self = [super init];

    if (self) {
        self.title = @"SleepMode";
    }

    return self;
}

#pragma mark - Specifiers

- (NSArray *)specifiers
{
    if (_specifiers == nil) {

        NSMutableArray *specifiers =
            [NSMutableArray array];

        /*
         * Nhóm giới thiệu
         */
        PSSpecifier *group =
            [PSSpecifier groupSpecifierWithName:@"SleepMode"];

        [group setProperty:
            @"Tự động khóa iPhone và đóng ứng dụng sau thời gian không sử dụng."
            forKey:@"footerText"];

        [specifiers addObject:group];

        /*
         * Bật / tắt SleepMode
         */
        PSSpecifier *enabled =
            [PSSpecifier preferenceSpecifierNamed:
                @"Bật SleepMode"
                target:self
                set:@selector(setPreferenceValue:specifier:)
                get:@selector(readPreferenceValue:)
                detail:nil
                cell:PSSwitchCell
                edit:nil];

        [enabled setProperty:
            @"SleepModeEnabled"
            forKey:@"key"];

        [enabled setProperty:
            kDomain
            forKey:@"defaults"];

        [enabled setProperty:
            @YES
            forKey:@"default"];

        [enabled setProperty:
            kChangedNotification
            forKey:@"PostNotification"];

        [specifiers addObject:enabled];

        /*
         * Thời gian tự động khóa
         */
        PSSpecifier *timeout =
            [PSSpecifier preferenceSpecifierNamed:
                @"Tự động khóa sau"
                target:self
                set:@selector(setPreferenceValue:specifier:)
                get:@selector(readPreferenceValue:)
                detail:nil
                cell:PSLinkListCell
                edit:nil];

        [timeout setProperty:
            @"SleepModeTimeout"
            forKey:@"key"];

        [timeout setProperty:
            kDomain
            forKey:@"defaults"];

        [timeout setProperty:
            @300
            forKey:@"default"];

        [timeout setProperty:
            @[
                @"1 phút",
                @"5 phút",
                @"15 phút",
                @"30 phút",
                @"1 giờ",
                @"2 giờ"
            ]
            forKey:@"titles"];

        [timeout setProperty:
            @[
                @60,
                @300,
                @900,
                @1800,
                @3600,
                @7200
            ]
            forKey:@"values"];

        [timeout setProperty:
            kChangedNotification
            forKey:@"PostNotification"];

        [specifiers addObject:timeout];

        _specifiers = [specifiers mutableCopy];
    }

    return _specifiers;
}

#pragma mark - Read

- (id)readPreferenceValue:(PSSpecifier *)specifier
{
    NSString *key =
        [specifier propertyForKey:@"key"];

    if (key == nil) {
        return nil;
    }

    NSUserDefaults *defaults =
        [[NSUserDefaults alloc]
            initWithSuiteName:kDomain];

    id value =
        [defaults objectForKey:key];

    if (value == nil) {
        value =
            [specifier propertyForKey:@"default"];
    }

    return value;
}

#pragma mark - Write

- (void)setPreferenceValue:(id)value
                  specifier:(PSSpecifier *)specifier
{
    NSString *key =
        [specifier propertyForKey:@"key"];

    if (key == nil) {
        return;
    }

    NSUserDefaults *defaults =
        [[NSUserDefaults alloc]
            initWithSuiteName:kDomain];

    if (value != nil) {
        [defaults setObject:value
                     forKey:key];
    } else {
        [defaults removeObjectForKey:key];
    }

    [defaults synchronize];

    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge CFStringRef)kChangedNotification,
        NULL,
        NULL,
        YES
    );

    [self reloadSpecifier:specifier];
}

#pragma mark - View

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"SleepMode";
    
}

@end
