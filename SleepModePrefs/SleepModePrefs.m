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
    if (_specifiers == nil) {

        _specifiers =
            [self loadSpecifiersFromPlistName:@"Root"
                                       target:self];
    }

    return _specifiers;
}


#pragma mark - Immediate Settings update

- (void)setPreferenceValue:(id)value
                 specifier:(PSSpecifier *)specifier
{
    /*
     * Preferences.framework ghi giá trị vào:
     *
     * com.trantu.sleepmode
     */
    [super setPreferenceValue:value
                    specifier:specifier];

    /*
     * Báo ngay cho SleepManager trong SpringBoard.
     *
     * Không respring.
     */
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR("com.trantu.sleepmode.settingsChanged"),
        NULL,
        NULL,
        YES
    );
}


- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"SleepMode";
}


@end
