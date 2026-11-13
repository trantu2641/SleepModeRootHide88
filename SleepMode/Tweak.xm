#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "SleepManager.h"

%hook UIApplication

- (void)sendEvent:(UIEvent *)event
{
    %orig;

    /*
     * Chỉ reset khi có event cảm ứng.
     * Không truy cập touches / presses / view / window
     * để tránh làm hỏng event pipeline của SpringBoard.
     */
    if (event != nil &&
        [event type] == UIEventTypeTouches) {

        @autoreleasepool {
            [[SleepManager sharedInstance] resetTimer];
        }
    }
}

%end

%ctor
{
    @autoreleasepool {

        /*
         * Chờ SpringBoard khởi động ổn định rồi mới
         * khởi tạo SleepManager.
         */
        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW,
                          (int64_t)(2.0 * NSEC_PER_SEC)),
            dispatch_get_main_queue(),
            ^{
                @autoreleasepool {
                    [[SleepManager sharedInstance] start];
                }
            }
        );
    }
}
