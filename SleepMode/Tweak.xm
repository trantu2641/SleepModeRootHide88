#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "SleepManager.h"

#pragma mark - Activity

static void SleepModeRegisterActivity(void)
{
    [[SleepManager sharedInstance]
        userDidInteract];
}

#pragma mark - Lock State Notifications

static void SleepModeRegisterLockNotifications(void)
{
    NSNotificationCenter *center =
        [NSNotificationCenter defaultCenter];

    /*
     * Lock notification.
     */
    [center addObserverForName:
                @"SBLockScreenManagerDidLockNotification"

            object:nil

             queue:[NSOperationQueue mainQueue]

        usingBlock:
        ^(NSNotification *notification) {

            NSLog(
                @"[SleepMode] System lock detected"
            );

            [[SleepManager sharedInstance]
                deviceDidLock];
        }];

    /*
     * Unlock notification.
     */
    [center addObserverForName:
                @"SBLockScreenManagerDidUnlockNotification"

            object:nil

             queue:[NSOperationQueue mainQueue]

        usingBlock:
        ^(NSNotification *notification) {

            NSLog(
                @"[SleepMode] System unlock detected"
            );

            [[SleepManager sharedInstance]
                deviceDidUnlock];
        }];
}

#pragma mark - SpringBoard Group

%group SpringBoardGroup

/*
 * SpringBoard idle timer.
 *
 * Đây vẫn được giữ lại vì nó là một trong
 * các activity signal gần với Auto-Lock.
 */
%hook SBIdleTimerGlobalCoordinator

- (void)resetIdleTimer
{
    %orig;

    SleepModeRegisterActivity();
}

%end


/*
 * SpringBoard lifecycle.
 */
%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application
{
    %orig;

    NSLog(
        @"[SleepMode] SpringBoard started"
    );

    [SleepManager sharedInstance];

    SleepModeRegisterLockNotifications();
}

%end

%end

#pragma mark - Constructor

%ctor
{
    NSString *bundleID =
        [[NSBundle mainBundle]
            bundleIdentifier];

    /*
     * Chỉ chạy trong SpringBoard.
     *
     * Không inject vào:
     *
     * Safari
     * YouTube
     * Facebook
     * game
     * v.v.
     */
    if ([bundleID
            isEqualToString:
                @"com.apple.springboard"]) {

        NSLog(
            @"[SleepMode] Injected into SpringBoard"
        );

        %init(SpringBoardGroup);
    }
}
