#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "SleepManager.h"
#import "SleepControlCenter.h"


%group SleepModeGroup


#pragma mark - SpringBoard

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application
{
    %orig;

    NSLog(@"[SleepMode] SpringBoard started");

    [SleepManager sharedInstance];
    [SleepControlCenter sharedInstance];

    NSLog(@"[SleepMode] Control Center initialized");
}


- (void)sendEvent:(UIEvent *)event
{
    /*
     * Bắt touch ở cấp SpringBoard.
     *
     * Tweak chỉ inject vào SpringBoard nên:
     *
     * - Home Screen vẫn nhận được
     * - Control Center vẫn nhận được
     * - Lock Screen không chạy timer
     * - Không cần inject vào từng app
     */

    if (event != nil &&
        event.type == UIEventTypeTouches) {

        NSSet *touches =
            [event allTouches];

        if (touches != nil &&
            touches.count > 0) {

            BOOL realTouch = NO;

            for (UITouch *touch in touches) {

                if (touch == nil) {
                    continue;
                }

                UITouchPhase phase =
                    touch.phase;

                if (phase == UITouchPhaseBegan ||
                    phase == UITouchPhaseMoved ||
                    phase == UITouchPhaseEnded ||
                    phase == UITouchPhaseStationary) {

                    realTouch = YES;
                    break;
                }
            }

            if (realTouch) {

                NSLog(@"[SleepMode] User interaction detected");

                [[SleepManager sharedInstance]
                    userDidInteract];
            }
        }
    }

    %orig;
}


%end


#pragma mark - System Idle Timer

%hook SBIdleTimerGlobalCoordinator

- (void)resetIdleTimer
{
    %orig;

    NSLog(@"[SleepMode] System idle timer reset");

    [[SleepManager sharedInstance]
        userDidInteract];
}

%end


#pragma mark - Lock / Unlock

%hook SBLockScreenManager

/*
 * Được gọi khi hệ thống thực hiện lock.
 */
- (void)lockFromSource:(int)source
{
    NSLog(@"[SleepMode] lockFromSource: %d",
          source);

    %orig;

    /*
     * Dừng timer ngay khi thiết bị bị khóa.
     */
    [[SleepManager sharedInstance]
        deviceDidLock];
}


/*
 * Được gọi sau khi unlock UI.
 */
- (void)unlockUIFromSource:(int)source
              withOptions:(id)options
{
    NSLog(@"[SleepMode] unlockUIFromSource:withOptions:");

    %orig;

    /*
     * Sau khi unlock:
     *
     * - timer bắt đầu lại
     * - thời gian tính lại từ 0
     * - không dùng thời gian trước khi khóa
     */
    [[SleepManager sharedInstance]
        deviceDidUnlock];
}

%end


#pragma mark - Constructor

%ctor
{
    NSString *bundleID =
        [[NSBundle mainBundle]
            bundleIdentifier];

    /*
     * Chỉ chạy trong SpringBoard.
     */
    if ([bundleID
            isEqualToString:
                @"com.apple.springboard"]) {

        NSLog(@"[SleepMode] Injected into SpringBoard");

        %init(SleepModeGroup);

        [SleepManager sharedInstance];

        [SleepControlCenter sharedInstance];

        NSLog(@"[SleepMode] Core + Control Center ready");

        return;
    }
}

%end
