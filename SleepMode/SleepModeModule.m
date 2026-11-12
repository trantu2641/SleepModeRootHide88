#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/*
 * Khai báo interface tối thiểu của ControlCenter.
 * Không cần link bằng @interface trực tiếp tới framework
 * ở phần header của Theos.
 */
@interface CCUIToggleModule : NSObject
- (BOOL)isSelected;
- (void)setSelected:(BOOL)selected;
- (void)handlePress;
- (void)refreshState;
@end

@interface SleepModeModule : CCUIToggleModule
@end

static NSString * const SleepModeEnabledKey =
    @"SleepModeEnabled";

static NSString * const SleepModeCommandNotification =
    @"com.trantu.sleepmode.command";

@implementation SleepModeModule

- (BOOL)isSelected
{
    return [[NSUserDefaults standardUserDefaults]
            boolForKey:SleepModeEnabledKey];
}

- (void)setSelected:(BOOL)selected
{
    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    [defaults setBool:selected
               forKey:SleepModeEnabledKey];

    [defaults synchronize];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SleepModeCommandNotification
                      object:nil
                    userInfo:@{
                        @"enabled": @(selected)
                    }];
}

- (void)handlePress
{
    BOOL selected = [self isSelected];

    [self setSelected:!selected];
}

- (void)refreshState
{
    /*
     * Control Center sẽ gọi isSelected:
     * nên không cần lưu state riêng trong module.
     */
}

@end
