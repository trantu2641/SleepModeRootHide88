#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "SleepManager.h"

static void (*orig_UIApplication_sendEvent)(UIApplication *self,
                                            SEL _cmd,
                                            UIEvent *event);

static void sm_UIApplication_sendEvent(UIApplication *self,
                                       SEL _cmd,
                                       UIEvent *event)
{
    if (orig_UIApplication_sendEvent != NULL) {
        orig_UIApplication_sendEvent(self, _cmd, event);
    }

    /*
     * Chỉ xử lý event cảm ứng.
     *
     * Không gọi:
     * - allTouches
     * - allPresses
     * - touchesForView:
     * - window
     * - view
     *
     * để tránh can thiệp sâu vào event pipeline của SpringBoard.
     */
    if (event != nil &&
        [event type] == UIEventTypeTouches) {

        @autoreleasepool {
            [[SleepManager sharedInstance] resetTimer];
        }
    }
}

%ctor
{
    @autoreleasepool {

        Class UIApplicationClass = objc_getClass("UIApplication");

        if (UIApplicationClass != Nil) {

            SEL sendEventSEL = @selector(sendEvent:);

            Method method =
                class_getInstanceMethod(UIApplicationClass,
                                         sendEventSEL);

            if (method != NULL) {

                MSHookMessageEx(UIApplicationClass,
                                sendEventSEL,
                                (IMP)sm_UIApplication_sendEvent,
                                (IMP *)&orig_UIApplication_sendEvent);
            }
        }

        /*
         * Khởi động SleepManager sau khi SpringBoard đã ổn định.
         * Không khởi tạo ngay trong lúc dylib vừa được inject.
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
