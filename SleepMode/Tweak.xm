#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "SleepManager.h"
#import "SleepControlCenter.h"

static void SleepModeApplySavedSettings(void)
{
    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    SleepManager *manager =
        [SleepManager sharedInstance];

    BOOL enabled =
        [defaults boolForKey:SleepModeEnabledKey];

    NSTimeInterval timeout =
        [defaults doubleForKey:SleepModeTimeoutKey];

    if (timeout <= 0.0)
        timeout = 15.0;

    manager.timeout = timeout;
    manager.enabled = enabled;

    if (enabled) {
        [manager start];
    } else {
        [manager stop];
    }
}

static void SleepModeHandleCommand(NSNotification *notification)
{
    SleepManager *manager =
        [SleepManager sharedInstance];

    NSDictionary *info =
        notification.userInfo;

    NSNumber *enabledNumber =
        info[@"enabled"];

    NSNumber *timeoutNumber =
        info[@"timeout"];

    NSNumber *resetNumber =
        info[@"reset"];

    if (timeoutNumber != nil) {

        NSTimeInterval timeout =
            [timeoutNumber doubleValue];

        if (timeout < 1.0)
            timeout = 1.0;

        manager.timeout = timeout;
    }

    if (enabledNumber != nil) {

        BOOL enabled =
            [enabledNumber boolValue];

        manager.enabled = enabled;

        if (enabled) {
            [manager start];
        } else {
            [manager stop];
        }
    }

    if ([resetNumber boolValue]) {
        [manager resetTimer];
    }

    /*
     * Nếu chỉ đổi timeout mà chế độ đang bật,
     * khởi động lại timer với timeout mới.
     */
    if (timeoutNumber != nil &&
        enabledNumber == nil &&
        manager.enabled) {

        [manager resetTimer];
    }

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SleepModeStateChangedNotification
                      object:nil];
}

#pragma mark - Touch Reset

%hook UIApplication

- (void)sendEvent:(UIEvent *)event
{
    if (event.type == UIEventTypeTouches) {

        SleepManager *manager =
            [SleepManager sharedInstance];

        if (manager.enabled) {
            [manager resetTimer];
        }
    }

    %orig;
}

%end

#pragma mark - SpringBoard

%hook SpringBoard

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
    %orig;

    /*
     * Nhận lệnh từ Control Center.
     */
    [[NSNotificationCenter defaultCenter]
        addObserverForName:SleepModeCommandNotification
                    object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *notification) {

        SleepModeHandleCommand(notification);
    }];

    /*
     * Load trạng thái đã lưu.
     */
    SleepModeApplySavedSettings();
}

%end

#pragma mark - Constructor

%ctor
{
    /*
     * Tweak chỉ inject SpringBoard
     * theo SleepMode.plist.
     */
}
