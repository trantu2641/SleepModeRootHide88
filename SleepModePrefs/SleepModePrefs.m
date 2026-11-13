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

#pragma mark - Init

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
         * ----------------------------------------------------
         * GROUP
         * ----------------------------------------------------
         */

        PSSpecifier *group =
            [PSSpecifier groupSpecifierWithName:@"SleepMode"];

        if (group) {
            [group setProperty:
                @"Tự động khóa và đóng ứng dụng sau thời gian không sử dụng."
                forKey:@"footerText"];

            [specifiers addObject:group];
        }


        /*
         * ----------------------------------------------------
         * ENABLE SWITCH
         * ----------------------------------------------------
         */

        PSSpecifier *enabled =
            [PSSpecifier preferenceSpecifierNamed:
                @"Bật SleepMode"
                target:self
                set:@selector(setPreferenceValue:specifier:)
                get:@selector(readPreferenceValue:)
                detail:nil
                cell:PSLinkListCell
                edit:nil];

        if (enabled) {

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
                @"com.trantu.sleepmode.settingsChanged"
                forKey:@"PostNotification"];

            [enabled setProperty:
                @(PSSwitchCell)
                forKey:@"cell"];

            [specifiers addObject:enabled];
        }


        /*
         * ----------------------------------------------------
         * TIMEOUT
         * ----------------------------------------------------
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

        if (timeout) {

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
                @"com.trantu.sleepmode.settingsChanged"
                forKey:@"PostNotification"];

            [specifiers addObject:timeout];
        }


        /*
         * ----------------------------------------------------
         * SAFETY CHECK
         * ----------------------------------------------------
         */

        if ([specifiers count] == 0) {

            NSLog(
                @"[SleepModePrefs] ERROR: no specifiers created"
            );

        } else {

            NSLog(
                @"[SleepModePrefs] created %lu specifiers",
                (unsigned long)[specifiers count]
            );
        }

        _specifiers = [specifiers mutableCopy];
    }

    return _specifiers;
}

#pragma mark - Preference Read

- (id)readPreferenceValue:(PSSpecifier *)specifier
{
    NSString *key =
        [specifier propertyForKey:@"key"];

    if (!key) {
        return nil;
    }

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

#pragma mark - Preference Write

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

    if (value) {
        [defaults setObject:value forKey:key];
    } else {
        [defaults removeObjectForKey:key];
    }

    [defaults synchronize];

    /*
     * Notify SleepManager immediately.
     */
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge CFStringRef)kSleepModeChangedNotification,
        NULL,
        NULL,
        YES
    );

    /*
     * Reload the changed row.
     */
    [self reloadSpecifier:specifier];
}

#pragma mark - View

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"SleepMode";
}

@end
