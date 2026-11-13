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


        PSSpecifier *group =
            [PSSpecifier groupSpecifierWithName:@"THỜI GIAN"];

        [group setProperty:
            @"Chọn thời gian không có thao tác trước khi SleepMode khóa iPhone."
            forKey:@"footerText"];

        [items addObject:group];


        NSArray *titles = @[
            @"1 phút",
            @"5 phút",
            @"15 phút",
            @"30 phút",
            @"1 giờ",
            @"2 giờ"
        ];

        NSArray *values = @[
            @60,
            @300,
            @900,
            @1800,
            @3600,
            @7200
        ];


        for (NSUInteger i = 0;
             i < titles.count;
             i++) {

            PSSpecifier *item =
                [PSSpecifier preferenceSpecifierNamed:
                    titles[i]
                    target:self
                    set:nil
                    get:nil
                    detail:nil
                    cell:PSLinkCell
                    edit:nil];

            [item setProperty:
                values[i]
                forKey:@"timeoutValue"];

            [items addObject:item];
        }


        _specifiers =
            [items mutableCopy];
    }

    return _specifiers;
}


#pragma mark - Current Timeout

- (NSInteger)currentTimeout
{
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc]
            initWithSuiteName:kSleepModeDomain];

    NSNumber *value =
        [defaults objectForKey:@"SleepModeTimeout"];

    if (value == nil) {
        return 300;
    }

    return [value integerValue];
}


#pragma mark - Cell

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell =
        [super tableView:tableView
   cellForRowAtIndexPath:indexPath];

    PSSpecifier *specifier =
        [self specifierAtIndexPath:indexPath];

    NSNumber *timeout =
        [specifier propertyForKey:@"timeoutValue"];

    if (timeout != nil) {

        if ([timeout integerValue] ==
            [self currentTimeout]) {

            cell.accessoryType =
                UITableViewCellAccessoryCheckmark;

        } else {

            cell.accessoryType =
                UITableViewCellAccessoryNone;
        }
    }

    return cell;
}


#pragma mark - Select

- (void)tableView:(UITableView *)tableView
 didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    PSSpecifier *specifier =
        [self specifierAtIndexPath:indexPath];

    NSNumber *timeout =
        [specifier propertyForKey:@"timeoutValue"];

    if (timeout != nil) {

        NSUserDefaults *defaults =
            [[NSUserDefaults alloc]
                initWithSuiteName:kSleepModeDomain];

        [defaults setObject:
            timeout
            forKey:@"SleepModeTimeout"];

        [defaults synchronize];


        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge CFStringRef)
                kSleepModeChangedNotification,
            NULL,
            NULL,
            YES
        );


        [tableView deselectRowAtIndexPath:
            indexPath
            animated:YES];


        [self.navigationController
            popViewControllerAnimated:YES];

        return;
    }

    [super tableView:tableView
        didSelectRowAtIndexPath:indexPath];
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


#pragma mark - Main Specifiers

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
