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

        NSMutableArray *specifiers =
            [NSMutableArray array];


        /*
         * GROUP
         */
        PSSpecifier *group =
            [PSSpecifier groupSpecifierWithName:@"SLEEPMODE"];

        [group setProperty:
            @"Tự động khóa iPhone và đóng ứng dụng sau thời gian không sử dụng."
            forKey:@"footerText"];

        [specifiers addObject:group];


        /*
         * ENABLE
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
            @YES
            forKey:@"enabled"];

        [enabled setProperty:
            kSleepModeChangedNotification
            forKey:@"PostNotification"];

        [specifiers addObject:enabled];


        /*
         * TIMEOUT
         *
         * PSLinkListCell
         * -> PSListItemsController
         *
         * Không load Root.plist.
         * Không dùng validTitles/validValues ở đây.
         * Tạo trực tiếp đúng kiểu runtime của Preferences.
         */
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


        NSArray *values = @[
            @60,
            @300,
            @900,
            @1800,
            @3600,
            @7200
        ];

        NSArray *titles = @[
            @"1 phút",
            @"5 phút",
            @"15 phút",
            @"30 phút",
            @"1 giờ",
            @"2 giờ"
        ];


        /*
         * PSListItemsController dùng values làm key
         * và titleDictionary để lấy tên hiển thị.
         */
        timeout.values =
            values;

        timeout.titleDictionary =
            [NSDictionary dictionaryWithObjects:
                titles
                forKeys:values];


        [timeout setProperty:
            kSleepModeChangedNotification
            forKey:@"PostNotification"];


        [specifiers addObject:timeout];


        _specifiers =
            [specifiers mutableCopy];
    }

    return _specifiers;
}


#pragma mark - Read preference

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


#pragma mark - Write preference

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


    /*
     * Báo ngay cho SleepManager.
     */
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
