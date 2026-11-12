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


#pragma mark - Immediate notification

- (void)setPreferenceValue:(id)value
                  specifier:(PSSpecifier *)specifier
{
    [super setPreferenceValue:value
                    specifier:specifier];

    /*
     * PreferenceLoader đã ghi giá trị vào
     * com.trantu.sleepmode.
     *
     * Darwin notification giúp SpringBoard
     * nhận thay đổi ngay lập tức.
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
