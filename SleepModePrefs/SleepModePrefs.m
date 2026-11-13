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

        /*
         * QUAN TRỌNG:
         * Load trực tiếp Root.plist từ chính PreferenceBundle.
         * Không tự tạo PSLinkListCell bằng code nữa.
         */
        NSBundle *bundle = self.bundle;

        if (bundle == nil) {
            bundle = [NSBundle bundleForClass:[self class]];
        }

        _specifiers =
            [self loadSpecifiersFromPlistName:@"Root"
                                       target:self
                                       bundle:bundle];

        if (_specifiers == nil) {
            _specifiers =
                [NSMutableArray array];
        }
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
        [defaults setObject:value
                     forKey:key];
    } else {
        [defaults removeObjectForKey:key];
    }

    [defaults synchronize];

    /*
     * Báo cho SleepManager áp dụng ngay.
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
