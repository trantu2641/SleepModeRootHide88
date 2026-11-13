#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <CoreFoundation/CoreFoundation.h>

static NSString * const kSleepModeDomain =
    @"com.trantu.sleepmode";

static NSString * const kSleepModeChangedNotification =
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

- (NSArray *)specifiers
{
    if (_specifiers == nil) {

        NSMutableArray *items =
            [NSMutableArray array];


        /*
         * ==================================================
         * GROUP
         * ==================================================
         */

        PSSpecifier *group =
            [PSSpecifier groupSpecifierWithName:@"SleepMode"];

        [group setProperty:
            @"Tự động khóa và đóng ứng dụng sau thời gian không sử dụng."
            forKey:@"footerText"];

        [items addObject:group];


        /*
         * ==================================================
         * ENABLE
         * ==================================================
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
            kSleepModeDomain
            forKey:@"defaults"];

        [enabled setProperty:
            @YES
            forKey:@"default"];

        [enabled setProperty:
            kSleepModeChangedNotification
            forKey:@"PostNotification"];

        [items addObject:enabled];


        /*
         * ==================================================
         * TIMEOUT
         * ==================================================
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
            kSleepModeDomain
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
            kSleepModeChangedNotification
            forKey:@"PostNotification"];

        [items addObject:timeout];


        _specifiers = [items mutableCopy];

        NSLog(
            @"[SleepModePrefs] loaded %lu specifiers",
            (unsigned long)_specifiers.count
        );
    }

    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier
{
    NSString *key =
        [specifier propertyForKey:@"key"];

    NSUserDefaults *defaults =
        [[NSUserDefaults alloc]
            initWithSuiteName:kSleepModeDomain];

    id value =
        [defaults objectForKey:key];

    if (value == nil) {
        value =
            [specifier propertyForKey:@"default"];
    }

    return value;
}

- (void)setPreferenceValue:(id)value
                  specifier:(PSSpecifier *)specifier
{
    NSString *key =
        [specifier propertyForKey:@"key"];

    if (!key) {
        return;
    }

    NSUserDefaults *defaults =
        [[NSUserDefaults alloc]
            initWithSuiteName:kSleepModeDomain];

    if (value != nil) {
        [defaults setObject:value forKey:key];
    } else {
        [defaults removeObjectForKey:key];
    }

    [defaults synchronize];

    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge CFStringRef)
            kSleepModeChangedNotification,
        NULL,
        NULL,
        YES
    );

    [self reloadSpecifier:specifier];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"SleepMode";
}

@end
