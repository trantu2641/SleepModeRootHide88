#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <CoreFoundation/CoreFoundation.h>

#import "SleepModeTimeoutController.h"


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


#pragma mark - Specifiers

- (NSArray *)specifiers
{
    if (_specifiers == nil) {

        NSMutableArray *items =
            [NSMutableArray array];


        // ==================================================
        // GROUP
        // ==================================================

        PSSpecifier *group =
            [PSSpecifier groupSpecifierWithName:@"SLEEPMODE"];

        [group setProperty:
            @"Tự động khóa iPhone và đóng ứng dụng sau thời gian không sử dụng."
            forKey:@"footerText"];

        [items addObject:group];


        // ==================================================
        // BẬT / TẮT
        // ==================================================

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
            @YES
            forKey:@"enabled"];

        [enabled setProperty:
            kSleepModeChangedNotification
            forKey:@"PostNotification"];

        [items addObject:enabled];


        // ==================================================
        // TỰ ĐỘNG KHÓA SAU
        // ==================================================

        PSSpecifier *timeout =
            [PSSpecifier preferenceSpecifierNamed:
                @"Tự động khóa sau"
                target:self
                set:nil
                get:nil
                detail:[SleepModeTimeoutController class]
                cell:PSLinkCell
                edit:nil];

        [timeout setProperty:
            @YES
            forKey:@"enabled"];

        [timeout setProperty:
            @YES
            forKey:@"isController"];

        [items addObject:timeout];


        // ==================================================
        // FINISH
        // ==================================================

        _specifiers =
            [items mutableCopy];
    }

    return _specifiers;
}


#pragma mark - Read

- (id)readPreferenceValue:(PSSpecifier *)specifier
{
    NSString *key =
        [specifier propertyForKey:@"key"];

    if (key.length == 0) {
        return nil;
    }


    NSUserDefaults *defaults =
        [[NSUserDefaults alloc]
            initWithSuiteName:kSleepModeDomain];

    id value =
        [defaults objectForKey:key];

    if (value != nil) {
        return value;
    }


    return [specifier propertyForKey:@"default"];
}


#pragma mark - Write

- (void)setPreferenceValue:(id)value
                  specifier:(PSSpecifier *)specifier
{
    NSString *key =
        [specifier propertyForKey:@"key"];

    if (key.length == 0) {
        return;
    }


    NSUserDefaults *defaults =
        [[NSUserDefaults alloc]
            initWithSuiteName:kSleepModeDomain];


    if (value != nil) {

        [defaults setObject:
            value
            forKey:key];

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


#pragma mark - View

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"SleepMode";
}

@end
