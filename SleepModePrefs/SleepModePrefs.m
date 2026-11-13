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

    if (self) {
        self.title =
            @"SleepMode";
    }

    return self;
}


#pragma mark - Specifiers


- (NSArray *)specifiers
{
    if (_specifiers == nil) {

        NSMutableArray *items =
            [NSMutableArray array];


        PSSpecifier *group =
            [PSSpecifier groupSpecifierWithName:
                @"SLEEPMODE"];


        [group setProperty:
            @"Tự động khóa iPhone và đóng ứng dụng sau thời gian không sử dụng."
            forKey:@"footerText"];


        [items addObject:group];


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
            @YES
            forKey:@"default"];


        [enabled setProperty:
            @YES
            forKey:@"enabled"];


        [items addObject:enabled];


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


        _specifiers =
            [items mutableCopy];
    }


    return _specifiers;
}


#pragma mark - Settings


- (NSDictionary *)loadSettings
{
    NSDictionary *settings =
        [NSDictionary dictionaryWithContentsOfFile:
            kPrefsPath];


    if (![settings isKindOfClass:
            [NSDictionary class]]) {

        return @{};
    }


    return settings;
}


- (id)readPreferenceValue:
        (PSSpecifier *)specifier
{
    NSString *key =
        [specifier propertyForKey:
            @"key"];


    if (key.length == 0) {
        return nil;
    }


    NSDictionary *settings =
        [self loadSettings];


    id value =
        settings[key];


    if (value != nil) {
        return value;
    }


    return [specifier propertyForKey:
        @"default"];
}


- (void)setPreferenceValue:
        (id)value
    specifier:
        (PSSpecifier *)specifier
{
    NSString *key =
        [specifier propertyForKey:
            @"key"];


    if (key.length == 0) {
        return;
    }


    NSMutableDictionary *settings =
        [[self loadSettings]
            mutableCopy];


    if (settings == nil) {

        settings =
            [NSMutableDictionary dictionary];
    }


    if (value != nil) {

        settings[key] =
            value;

    } else {

        [settings removeObjectForKey:
            key];
    }


    [settings writeToFile:
        kPrefsPath
        atomically:YES];


    /*
     * Core SleepMode nhận thay đổi ngay lập tức.
     */
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge CFStringRef)
            kChangedNotification,
        NULL,
        NULL,
        YES
    );


    [self reloadSpecifier:
        specifier];
}


- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title =
        @"SleepMode";
}


@end
