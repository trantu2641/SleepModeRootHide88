#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "SleepManager.h"
#import "SleepControlCenter.h"


#pragma mark - SleepMode Group

%group SleepModeGroup


#pragma mark - SpringBoard

%hook SpringBoard

/*
 * SpringBoard khởi động
 */
- (void)applicationDidFinishLaunching:(id)application
{
    %orig;

    NSLog(@"[SleepMode] SpringBoard started");

    /*
     * Khởi tạo SleepManager.
     */
    [SleepManager sharedInstance];

    /*
     * Khởi tạo module trung tâm điều khiển.
     */
    [SleepControlCenter sharedInstance];

    NSLog(@"[SleepMode] Control Center initialized");
}


/*
 * ============================================================
 * TOUCH DETECTION
 * ============================================================
 *
 * Bắt touch ở tầng SpringBoard.
 *
 * SleepMode chỉ inject vào SpringBoard nên:
 *
 * - Home Screen
 * - App Library
 * - Control Center
 * - các UI của SpringBoard
 *
 * đều có thể được xử lý mà không cần inject
 * SleepMode vào từng app người dùng.
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

                /*
                 * Có hoạt động cảm ứng.
                 *
                 * Reset timer của SleepManager.
                 */
                [[SleepManager sharedInstance]
                    userDidInteract];
            }
        }
    }

    /*
     * Luôn để SpringBoard xử lý event bình thường.
     */
    %orig;
}

%end


#pragma mark - SpringBoard Idle Timer

/*
 * Đây là tín hiệu bổ sung từ cơ chế idle timer
 * của SpringBoard.
 *
 * Khi hệ thống reset idle timer,
 * SleepMode cũng reset bộ đếm.
 */
%hook SBIdleTimerGlobalCoordinator

- (void)resetIdleTimer
{
    %orig;

    NSLog(
        @"[SleepMode] System idle timer reset"
    );

    [[SleepManager sharedInstance]
        userDidInteract];
}

%end


#pragma mark - Lock / Unlock

/*
 * ============================================================
 * SBLockScreenManager
 * ============================================================
 *
 * iOS 16.x:
 *
 * Lock:
 *     lockFromSource:
 *
 * Unlock:
 *     unlockUIFromSource:withOptions:
 *
 * Khi thiết bị bị khóa:
 *
 *     SleepManager -> deviceDidLock
 *
 * Khi mở khóa:
 *
 *     SleepManager -> deviceDidUnlock
 *
 * deviceDidLock:
 *     dừng timer hoàn toàn
 *
 * deviceDidUnlock:
 *     reset thời gian về 0
 *     khởi động timer mới
 */

%hook SBLockScreenManager


/*
 * Thiết bị chuyển sang trạng thái khóa.
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
 * Thiết bị được mở khóa.
 *
 * Selector quan trọng trên iOS 16.x:
 *
 * unlockUIFromSource:withOptions:
 */
- (void)unlockUIFromSource:(int)source
               withOptions:(id)options
{
    NSLog(
        @"[SleepMode] unlockUIFromSource:withOptions:"
    );

    %orig;

    /*
     * Bắt đầu chu kỳ SleepMode mới.
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
     * ========================================================
     * CHỈ INJECT SPRINGBOARD
     * ========================================================
     *
     * Không inject vào:
     *
     * - Safari
     * - Facebook
     * - YouTube
     * - Game
     * - các app người dùng
     *
     * SleepMode hoạt động tập trung tại SpringBoard.
     */
    if ([bundleID
            isEqualToString:
                @"com.apple.springboard"]) {

        NSLog(
            @"[SleepMode] Injected into SpringBoard"
        );

        %init(SleepModeGroup);

        /*
         * Khởi tạo engine.
         */
        [SleepManager sharedInstance];

        /*
         * Khởi tạo trung tâm điều khiển.
         */
        [SleepControlCenter sharedInstance];

        NSLog(
            @"[SleepMode] Core + Control Center ready"
        );

        return;
    }
}
