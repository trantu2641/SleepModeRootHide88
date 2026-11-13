#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <CoreFoundation/CoreFoundation.h>

static NSString * const kSleepModeDomain =
    @"com.trantu.sleepmode";

static NSString * const kSleepModeChangedNotification =
    @"com.trantu.sleepmode.settingsChanged";


#pragma mark -
#pragma mark Timeout Controller


@interface SleepModeTimeoutController : PSListController
@end


@implementation SleepModeTimeoutController

- (instancetype)init
{
    self = [super init];

    if (self) {
        self.title = @"Tự động khóa sau";
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
            [PSSpecifier groupSpecifierWithName:@"THỜI GIAN"];

        [group setProperty:
            @"Chọn thời gian không có thao tác trước khi SleepMode khóa iPhone."
            forKey:@"footerText"];

        [items addObject:group];


        // ==================================================
        // 1 PHÚT
        // ==================================================

        PSSpecifier *oneMinute =
            [PSSpecifier preferenceSpecifierNamed:
                @"1 phút"
                target:self
                set:@selector(setTimeoutValue:specifier:)
                get:@selector(getTimeoutValue:specifier:)
                detail:nil
                cell:PSSwitchCell
                edit:nil];

        [oneMinute setProperty:
            @60
            forKey:@"timeoutValue"];

        [oneMinute setProperty:
            @NO
            forKey:@"enabled"];

        [items addObject:oneMinute];


        // ==================================================
        // 5 PHÚT
        // ==================================================

        PSSpecifier *fiveMinutes =
            [PSSpecifier preferenceSpecifierNamed:
                @"5 phút"
                target:self
                set:@selector(setTimeoutValue:specifier:)
                get:@selector(getTimeoutValue:specifier:)
                detail:nil
                cell:PSSwitchCell
                edit:nil];

        [fiveMinutes setProperty:
            @300
            forKey:@"timeoutValue"];

        [fiveMinutes setProperty:
            @NO
            forKey:@"enabled"];

        [items addObject:fiveMinutes];


        // ==================================================
        // 15 PHÚT
        // ==================================================

        PSSpecifier *fifteenMinutes =
            [PSSpecifier preferenceSpecifierNamed:
                @"15 phút"
                target:self
                set:@selector(setTimeoutValue:specifier:)
                get:@selector(getTimeoutValue:specifier:)
                detail:nil
                cell:PSSwitchCell
                edit:nil];

        [fifteenMinutes setProperty:
            @900
            forKey:@"timeoutValue"];

        [fifteenMinutes setProperty:
            @NO
            forKey:@"enabled"];

        [items addObject:fifteenMinutes];


        // ==================================================
        // 30 PHÚT
        // ==================================================

        PSSpecifier *thirtyMinutes =
            [PSSpecifier preferenceSpecifierNamed:
                @"30 phút"
                target:self
                set:@selector(setTimeoutValue:specifier:)
                get:@selector(getTimeoutValue:specifier:)
                detail:nil
                cell:PSSwitchCell
                edit:nil];

        [thirtyMinutes setProperty:
            @1800
            forKey:@"timeoutValue"];

        [thirtyMinutes setProperty:
            @NO
            forKey:@"enabled"];

        [items addObject:thirtyMinutes];


        // ==================================================
        // 1 GIỜ
        // ==================================================

        PSSpecifier *oneHour =
            [PSSpecifier preferenceSpecifierNamed:
                @"1 giờ"
                target:self
                set:@selector(setTimeoutValue:specifier:)
                get:@selector(getTimeoutValue:specifier:)
                detail:nil
                cell:PSSwitchCell
                edit:nil];

        [oneHour setProperty:
            @3600
            forKey:@"timeoutValue"];

        [oneHour setProperty:
            @NO
            forKey:@"enabled"];

        [items addObject:oneHour];


        // ==================================================
        // 2 GIỜ
        // ==================================================

        PSSpecifier *twoHours =
            [PSSpecifier preferenceSpecifierNamed:
                @"2 giờ"
                target:self
                set:@selector(setTimeoutValue:specifier:)
                get:@selector(getTimeoutValue:specifier:)
                detail:nil
                cell:PSSwitchCell
                edit:nil];

        [twoHours setProperty:
            @7200
            forKey:@"timeoutValue"];

        [twoHours setProperty:
            @NO
            forKey:@"enabled"];

        [items addObject:twoHours];


        _specifiers =
            [items mutableCopy];
    }

    return _specifiers;
}


#pragma mark - Read Timeout

- (id)getTimeoutValue:(PSSpecifier *)specifier
{
    NSNumber *timeout =
        [specifier propertyForKey:@"timeoutValue"];

    if (timeout == nil) {
        return @NO;
    }


    NSUserDefaults *defaults =
        [[NSUserDefaults alloc]
            initWithSuiteName:kSleepModeDomain];

    NSNumber *current =
        [defaults objectForKey:@"SleepModeTimeout"];

    if (current == nil) {
        current = @300;
    }


    if ([current integerValue] ==
        [timeout integerValue]) {

        return @YES;
    }


    return @NO;
}


#pragma mark - Set Timeout

- (void)setTimeoutValue:(id)value
              specifier:(PSSpecifier *)specifier
{
    NSNumber *timeout =
        [specifier propertyForKey:@"timeoutValue"];

    if (timeout == nil) {
        return;
    }


    NSUserDefaults *defaults =
        [[NSUserDefaults alloc]
            initWithSuiteName:kSleepModeDomain];

    [defaults setObject:
        timeout
        forKey:@"SleepModeTimeout"];

    [defaults synchronize];


    // ==================================================
    // BÁO CHO SLEEPMANAGER RELOAD NGAY
    // ==================================================

    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge CFStringRef)
            kSleepModeChangedNotification,
        NULL,
        NULL,
        YES
    );


    // Cập nhật trạng thái các dòng
    [self reloadSpecifiers];


    // Quay lại trang SleepMode
    [self.navigationController
        popViewControllerAnimated:YES];
}

@end



#pragma mark -
#pragma mark Main SleepMode Controller


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
                set:nil
                get:nil
                detail:[SleepModeTimeoutController class]
                cell:PSLinkCell
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

        [items addObject:timeout];


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

        [defaults setObject:
            value
            forKey:key];

    } else {

        [defaults removeObjectForKey:key];
    }


    [defaults synchronize];


    // ==================================================
    // BÁO CHO SLEEPMANAGER RELOAD NGAY
    // ==================================================

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
