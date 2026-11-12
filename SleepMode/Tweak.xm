#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "SleepManager.h"

#pragma mark - SpringBoard Group

%group SpringBoardGroup

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
}

/*
 * Bắt touch event ở tầng SpringBoard.
 *
 * Không dùng allPresses vì SDK iOS 16.5
 * không expose selector này trên UIEvent.
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

                NSLog(@"[SleepMode] Touch detected");

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
 * Đây là tín hiệu bổ sung của hệ thống.
 *
 * Khi SpringBoard reset idle timer do hoạt động
 * của người dùng, SleepMode cũng reset timer.
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
     * Không inject vào app người dùng.
     */
    if ([bundleID
            isEqualToString:
                @"com.apple.springboard"]) {

        NSLog(
            @"[SleepMode] Injected into SpringBoard"
        );

        %init(SpringBoardGroup);

        /*
         * Tạo SleepManager.
         */
        [SleepManager sharedInstance];

        return;
    }
}
