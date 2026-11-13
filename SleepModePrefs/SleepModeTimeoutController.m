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


        /*
         * 15 giây
         * 1 phút
         * 5 phút
         * 15 phút
         * 30 phút
         * 1 giờ
         * 2 giờ
         */
        NSArray *titles = @[
            @"15 giây",
            @"1 phút",
            @"5 phút",
            @"15 phút",
            @"30 phút",
            @"1 giờ",
            @"2 giờ"
        ];

        NSArray *values = @[
            @15,
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
                @YES
                forKey:@"enabled"];

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


        [tableView reloadData];


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
