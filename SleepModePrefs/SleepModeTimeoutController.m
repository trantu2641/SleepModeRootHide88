#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <CoreFoundation/CoreFoundation.h>


static NSString * const kSleepModeDomain =
    @"com.trantu.sleepmode";

static NSString * const kSleepModeChangedNotification =
    @"com.trantu.sleepmode.settingsChanged";


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


        // ==========================================
        // GROUP
        // ==========================================

        PSSpecifier *group =
            [PSSpecifier groupSpecifierWithName:@"THỜI GIAN"];

        [group setProperty:
            @"Chọn thời gian không có thao tác trước khi SleepMode khóa iPhone."
            forKey:@"footerText"];

        [items addObject:group];


        // ==========================================
        // 1 PHÚT
        // ==========================================

        PSSpecifier *oneMinute =
            [PSSpecifier preferenceSpecifierNamed:
                @"1 phút"
                target:self
                set:nil
                get:nil
                detail:nil
                cell:PSLinkCell
                edit:nil];

        [oneMinute setProperty:
            @60
            forKey:@"timeoutValue"];

        [items addObject:oneMinute];


        // ==========================================
        // 5 PHÚT
        // ==========================================

        PSSpecifier *fiveMinutes =
            [PSSpecifier preferenceSpecifierNamed:
                @"5 phút"
                target:self
                set:nil
                get:nil
                detail:nil
                cell:PSLinkCell
                edit:nil];

        [fiveMinutes setProperty:
            @300
            forKey:@"timeoutValue"];

        [items addObject:fiveMinutes];


        // ==========================================
        // 15 PHÚT
        // ==========================================

        PSSpecifier *fifteenMinutes =
            [PSSpecifier preferenceSpecifierNamed:
                @"15 phút"
                target:self
                set:nil
                get:nil
                detail:nil
                cell:PSLinkCell
                edit:nil];

        [fifteenMinutes setProperty:
            @900
            forKey:@"timeoutValue"];

        [items addObject:fifteenMinutes];


        // ==========================================
        // 30 PHÚT
        // ==========================================

        PSSpecifier *thirtyMinutes =
            [PSSpecifier preferenceSpecifierNamed:
                @"30 phút"
                target:self
                set:nil
                get:nil
                detail:nil
                cell:PSLinkCell
                edit:nil];

        [thirtyMinutes setProperty:
            @1800
            forKey:@"timeoutValue"];

        [items addObject:thirtyMinutes];


        // ==========================================
        // 1 GIỜ
        // ==========================================

        PSSpecifier *oneHour =
            [PSSpecifier preferenceSpecifierNamed:
                @"1 giờ"
                target:self
                set:nil
                get:nil
                detail:nil
                cell:PSLinkCell
                edit:nil];

        [oneHour setProperty:
            @3600
            forKey:@"timeoutValue"];

        [items addObject:oneHour];


        // ==========================================
        // 2 GIỜ
        // ==========================================

        PSSpecifier *twoHours =
            [PSSpecifier preferenceSpecifierNamed:
                @"2 giờ"
                target:self
                set:nil
                get:nil
                detail:nil
                cell:PSLinkCell
                edit:nil];

        [twoHours setProperty:
            @7200
            forKey:@"timeoutValue"];

        [items addObject:twoHours];


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

    if (timeout != nil &&
        [timeout integerValue] == [self currentTimeout]) {

        cell.accessoryType =
            UITableViewCellAccessoryCheckmark;

    } else {

        cell.accessoryType =
            UITableViewCellAccessoryNone;
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
