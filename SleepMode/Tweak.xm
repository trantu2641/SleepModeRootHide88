#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

#import "SleepManager.h"

static NSString * const kSleepModeTouchNotification =
    @"com.trantu.sleepmode.touch";

%hook UIApplication

- (void)sendEvent:(UIEvent *)event
{
    %orig;

    /*
     * Tuyệt đối không can thiệp vào event đang chạy.
     *
     * Chỉ thông báo cho SleepManager rằng vừa có
     * một event cảm ứng xảy ra.
     */
    if (event != nil &&
        [event type] == UIEventTypeTouches) {

        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge CFStringRef)
                kSleepModeTouchNotification,
            NULL,
            NULL,
            YES
        );
    }
}

%end

%ctor
{
    @autoreleasepool {

        /*
         * Chờ SpringBoard khởi động hoàn chỉnh.
         * Không khởi tạo SleepManager trong lúc dylib
         * vừa được inject.
         */
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(2.0 * NSEC_PER_SEC)
            ),
            dispatch_get_main_queue(),
            ^{
                @autoreleasepool {

                    SleepManager *manager =
                        [SleepManager sharedInstance];

                    [manager start];
                }
            }
        );
    }
}
