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
        // ENABLE
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
        // TIMEOUT
        // ==================================================

        PSSpecifier *timeout =
            [PSSpecifier preferenceSpecifierNamed:
                @"Tự động khóa sau"
                target:self
                set:@selector(setPreferenceValue:specifier:)
                get:@selector(readPreferenceValue:)
                detail:NSClassFromString(@"PSListItemsController")
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
            @YES
            forKey:@"enabled"];

        // --------------------------------------------------
        // Giá trị
        // --------------------------------------------------

        NSArray *values = @[
            @60,
            @300,
            @900,
            @1800,
            @3600,
            @7200
        ];

        // --------------------------------------------------
        // Tên hiển thị
        // --------------------------------------------------

        NSArray *titles = @[
            @"1 phút",
            @"5 phút",
            @"15 phút",
            @"30 phút",
            @"1 giờ",
            @"2 giờ"
        ];

        // PSLinkListCell / PSListItemsController
        // dùng validValues + validTitles.
        [timeout setProperty:
            values
            forKey:@"validValues"];

        [timeout setProperty:
            titles
            forKey:@"validTitles"];

        [timeout setProperty:
            kSleepModeChangedNotification
            forKey:@"PostNotification"];

        [items addObject:timeout];


        // ==================================================
        // FINISH
        // ==================================================

        _specifiers =
            [items mutableCopy];
    }

    return _specifiers;
}


#pragma mark - Read Preference

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


#pragma mark - Write Preference

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

        [defaults setObject:value
                     forKey:key];

    } else {

        [defaults removeObjectForKey:key];
    }

    [defaults synchronize];


    // ------------------------------------------------------
    // Báo cho SleepManager reload ngay lập tức
    // ------------------------------------------------------

    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge CFStringRef)
            kSleepModeChangedNotification,
        NULL,
        NULL,
        YES
    );


    // Cập nhật dòng đang hiển thị
    [self reloadSpecifier:specifier];
}


#pragma mark - View

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"SleepMode";
}

@end
