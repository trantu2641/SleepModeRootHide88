#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <CoreFoundation/CoreFoundation.h>

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

- (NSArray *)specifiers
{
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root"
                                                 target:self];
    }

    return _specifiers;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"SleepMode";
}

- (void)setPreferenceValue:(id)value
                  specifier:(PSSpecifier *)specifier
{
    [super setPreferenceValue:value
                    specifier:specifier];

    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.trantu.sleepmode.settingsChanged"),
        NULL,
        NULL,
        YES
    );
}

@end
