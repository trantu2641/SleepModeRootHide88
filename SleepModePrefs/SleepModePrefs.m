#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <CoreFoundation/CoreFoundation.h>

#import "SleepModeTimeoutController.h"

static NSString * const kPrefsPath =
    @"/var/mobile/Library/Preferences/com.trantu.sleepmode.plist";
static NSString * const kChangedNotification =
    @"com.trantu.sleepmode.settingsChanged";

@interface SleepModePrefsListController : PSListController
@end

@implementation SleepModePrefsListController

- (instancetype)init
{
    self = [super init];
    if (self) self.title = @"SleepMode";
    return self;
}

- (NSArray *)specifiers
{
    if (_specifiers == nil) {
        NSMutableArray *items = [NSMutableArray array];

        PSSpecifier *group =
            [PSSpecifier groupSpecifierWithName:@"SLEEPMODE"];
        [group setProperty:
            @"Tự động đóng ứng dụng và khóa iPhone khi không có thao tác chạm."
            forKey:@"footerText"];
        [items addObject:group];

        PSSpecifier *enabled =
            [PSSpecifier preferenceSpecifierNamed:@"Bật SleepMode"
                target:self
                set:@selector(setPreferenceValue:specifier:)
                get:@selector(readPreferenceValue:)
                detail:nil
                cell:PSSwitchCell
                edit:nil];
        [enabled setProperty:@"SleepModeEnabled" forKey:@"key"];
        [enabled setProperty:@YES forKey:@"default"];
        [enabled setProperty:@YES forKey:@"enabled"];
        [items addObject:enabled];

        PSSpecifier *timeout =
            [PSSpecifier preferenceSpecifierNamed:@"Tự động khóa sau"
                target:self
                set:nil
                get:nil
                detail:[SleepModeTimeoutController class]
                cell:PSLinkCell
                edit:nil];
        [timeout setProperty:@YES forKey:@"enabled"];
        [timeout setProperty:@YES forKey:@"isController"];
        [items addObject:timeout];

        _specifiers = [items mutableCopy];
    }
    return _specifiers;
}

- (NSDictionary *)loadSettings
{
    NSDictionary *settings =
        [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    return [settings isKindOfClass:[NSDictionary class]] ? settings : @{};
}

- (id)readPreferenceValue:(PSSpecifier *)specifier
{
    NSString *key = [specifier propertyForKey:@"key"];
    if (key.length == 0) return nil;
    id value = [self loadSettings][key];
    return value ?: [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier
{
    NSString *key = [specifier propertyForKey:@"key"];
    if (key.length == 0) return;

    NSMutableDictionary *settings = [[self loadSettings] mutableCopy];
    if (!settings) settings = [NSMutableDictionary dictionary];

    if (value) settings[key] = value;
    else [settings removeObjectForKey:key];

    if (![settings writeToFile:kPrefsPath atomically:YES]) {
        NSLog(@"[SleepModePrefs] Failed to write preferences");
        return;
    }

    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge CFStringRef)kChangedNotification,
        NULL, NULL, YES
    );

    [self reloadSpecifier:specifier];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"SleepMode";
}

@end
