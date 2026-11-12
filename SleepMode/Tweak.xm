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
 * Bắt touch ở tầng SpringBoard.
 *
 * Quan trọng:
 * SleepMode chỉ inject vào SpringBoard.
 *
 * Vì vậy:
 *
 * Home Screen       -> bắt được
 * App Library       -> bắt được
 * Control Center    -> bắt được
 * SpringBoard UI    -> bắt được
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
 * Đây là tín hiệu bổ sung của iOS.
 *
 * Khi hệ thống reset idle timer,
 * SleepMode cũng reset bộ đếm.
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
 * Bắt trạng thái khóa / mở khóa trực tiếp
 * từ SBLockScreenManager.
 *
 * Không phụ thuộc notification name.
 */

%hook SBLockScreenManager

/*
 * Thiết bị vừa khóa.
 */
- (void)lockUIFromSource:(int)source
{
    %orig;

    NSLog(@"[SleepMode] Device locked");

    [[SleepManager sharedInstance]
        deviceDidLock];
}

/*
 * Một số phiên bản SpringBoard sử dụng
 * unlockUIFromSource:
 */
- (void)unlockUIFromSource:(int)source
{
    %orig;

    NSLog(@"[SleepMode] Device unlocked");

    [[SleepManager sharedInstance]
        deviceDidUnlock];
}

/*
 * Một số đường unlock có thể đi qua
 * finishUIUnlockFromSource:
 */
- (void)finishUIUnlockFromSource:(int)source
{
    %orig;

    NSLog(@"[SleepMode] Unlock finished");

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
     * Chỉ inject vào SpringBoard.
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
