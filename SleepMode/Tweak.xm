#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "SleepManager.h"

#pragma mark - SpringBoard Group

%group SpringBoardGroup

/*
 * SpringBoard là nơi quản lý toàn bộ giao diện hệ thống.
 *
 * Vì SleepMode chỉ inject vào SpringBoard nên:
 *
 *   Home Screen       -> bắt được
 *   App đang chạy     -> SpringBoard vẫn nhận lifecycle/event liên quan
 *   Control Center    -> bắt được
 *   Lock Screen       -> không chạy timer
 *   App Library       -> bắt được
 *
 * Không cần inject SleepMode vào từng app.
 */

%hook SpringBoard

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
 * Đây là điểm bắt sự kiện ở tầng SpringBoard.
 */
- (void)sendEvent:(UIEvent *)event
{
    if (event != nil) {

        UIEventType type = event.type;

        /*
         * Touch event
         */
        if (type == UIEventTypeTouches) {

            NSSet *touches = [event allTouches];

            if (touches.count > 0) {

                BOOL hasRealTouch = NO;

                for (UITouch *touch in touches) {

                    if (touch == nil) {
                        continue;
                    }

                    /*
                     * Chỉ tính những touch thực sự
                     * đang tương tác với màn hình.
                     */
                    UITouchPhase phase =
                        touch.phase;

                    if (phase == UITouchPhaseBegan ||
                        phase == UITouchPhaseMoved ||
                        phase == UITouchPhaseEnded ||
                        phase == UITouchPhaseStationary) {

                        hasRealTouch = YES;
                        break;
                    }
                }

                if (hasRealTouch) {

                    [[SleepManager sharedInstance]
                        userDidInteract];
                }
            }
        }

        /*
         * Một số thao tác phần cứng / hệ thống
         * có thể đi qua Press event.
         */
        else if (type == UIEventTypePresses) {

            NSSet *presses =
                [event allPresses];

            if (presses.count > 0) {

                [[SleepManager sharedInstance]
                    userDidInteract];
            }
        }
    }

    %orig;
}

%end


/*
 * Giữ lại hook này như một lớp dự phòng.
 *
 * SpringBoard có thể reset idle timer khi hệ thống
 * nhận biết hoạt động của người dùng.
 */
%hook SBIdleTimerGlobalCoordinator

- (void)resetIdleTimer
{
    %orig;

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

    if ([bundleID
            isEqualToString:
                @"com.apple.springboard"]) {

        NSLog(@"[SleepMode] Injected into SpringBoard");

        %init(SpringBoardGroup);

        /*
         * Tạo manager ngay sau khi SpringBoard
         * được inject.
         */
        [SleepManager sharedInstance];

        return;
    }
}
