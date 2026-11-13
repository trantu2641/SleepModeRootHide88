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
static NSString * const kTimeoutKey = @"SleepModeTimeout";

@implementation SleepModeTimeoutController

- (instancetype)init
{
    self = [super init];
    if (self) self.title = @"Tự động khóa sau";
    return self;
}

- (NSArray *)specifiers
{
    if (_specifiers == nil) {
        NSMutableArray *items = [NSMutableArray array];

        PSSpecifier *group =
            [PSSpecifier groupSpecifierWithName:@"THỜI GIAN"];
        [group setProperty:
            @"Chọn thời gian không có thao tác trước khi SleepMode khóa iPhone."
            forKey:@"footerText"];
        [items addObject:group];

        NSArray *titles = @[
            @"15 giây", @"1 phút", @"5 phút", @"15 phút",
            @"30 phút", @"1 giờ", @"2 giờ"
        ];
        NSArray *values = @[@15, @60, @300, @900, @1800, @3600, @7200];

        for (NSUInteger i = 0; i < titles.count; i++) {
            PSSpecifier *item =
                [PSSpecifier preferenceSpecifierNamed:titles[i]
                    target:self
                    set:nil
                    get:nil
                    detail:nil
                    cell:PSLinkCell
                    edit:nil];
            [item setProperty:@YES forKey:@"enabled"];
            [item setProperty:values[i] forKey:@"timeoutValue"];
            [items addObject:item];
        }
        _specifiers = [items mutableCopy];
    }
    return _specifiers;
}

- (NSInteger)currentTimeout
{
    NSDictionary *settings =
        [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    NSNumber *value = settings[kTimeoutKey];
    NSInteger timeout = [value respondsToSelector:@selector(integerValue)]
        ? value.integerValue : 15;
    return timeout > 0 ? timeout : 15;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell =
        [super tableView:tableView cellForRowAtIndexPath:indexPath];
    PSSpecifier *specifier = [self specifierAtIndexPath:indexPath];
    NSNumber *timeout = [specifier propertyForKey:@"timeoutValue"];
    cell.accessoryType =
        (timeout && timeout.integerValue == [self currentTimeout])
            ? UITableViewCellAccessoryCheckmark
            : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView
 didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    PSSpecifier *specifier = [self specifierAtIndexPath:indexPath];
    NSNumber *timeout = [specifier propertyForKey:@"timeoutValue"];

    if (!timeout) {
        [super tableView:tableView didSelectRowAtIndexPath:indexPath];
        return;
    }

    NSDictionary *oldSettings =
        [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    NSMutableDictionary *settings =
        [oldSettings isKindOfClass:[NSDictionary class]]
            ? [oldSettings mutableCopy]
            : [NSMutableDictionary dictionary];
    settings[kTimeoutKey] = timeout;

    if (![settings writeToFile:kPrefsPath atomically:YES]) {
        NSLog(@"[SleepModePrefs] Failed to save timeout");
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }

    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge CFStringRef)kChangedNotification,
        NULL, NULL, YES
    );

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self.navigationController popViewControllerAnimated:YES];
}

@end
