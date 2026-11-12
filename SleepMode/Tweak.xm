#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "SleepManager.h"

#pragma mark - SpringBoard Group

%group SpringBoardGroup


#pragma mark - SpringBoard

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application
{
    %orig;

    NSLog(@"[SleepMode] SpringBoard started");

    [SleepManager sharedInstance];
}


/*
 * Bắt touch event ở tầng SpringBoard.
 *
 * SleepMode chỉ inject vào SpringBoard.
 *
 * Vì vậy không cần inject vào từng app.
 */
- (void)sendEvent:(UIEvent *)event
{
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

                [[SleepManager sharedInstance]
                    userDidInteract];
            }
        }
    }

    %orig;
}

%end


#pragma mark - SpringBoard Idle Timer

/*
 * Tín hiệu bổ sung từ hệ thống idle timer.
 */
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

/*
 * iOS 16.x:
 *
 * Lock:
 *     lockFromSource:
 *
 * Unlock:
 *     unlockUIFromSource:withOptions:
 *
 * Đây là điểm quan trọng.
 *
 * Bản trước dùng:
 *
 *     unlockUIFromSource:
 *
 * nên không được gọi trên iOS 16.4.
 */

%hook SBLockScreenManager


/*
 * Thiết bị chuyển sang trạng thái LOCK.
 */
- (void)lockFromSource:(int)source
{
    NSLog(
        @"[SleepMode] lockFromSource: %d",
        source
    );

    %orig;

    [[SleepManager sharedInstance]
        deviceDidLock];
}


/*
 * Thiết bị vừa unlock.
 *
 * Selector thực tế có thêm withOptions:
 */
- (void)unlockUIFromSource:(int)source
               withOptions:(id)options
{
    NSLog(
        @"[SleepMode] unlockUIFromSource:withOptions:"
    );

    %orig;

    /*
     * Reset toàn bộ chu kỳ.
     *
     * Timer sẽ bắt đầu lại từ 0.
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

        NSLog(
            @"[SleepMode] Injected into SpringBoard"
        );

        %init(SpringBoardGroup);

        /*
         * Khởi tạo SleepManager.
         */
        [SleepManager sharedInstance];

        return;
    }
}

%end
