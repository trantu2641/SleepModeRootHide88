#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "SleepManager.h"


#pragma mark -
#pragma mark SpringBoard

@interface SpringBoard : UIApplication
@end


%hook SpringBoard


#pragma mark -
#pragma mark Launch

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
    %orig;


    /*
     * Không khởi tạo SleepManager trực tiếp trong
     * launch callback.
     *
     * Chờ SpringBoard ổn định rồi mới khởi động.
     */

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)(3.0 * NSEC_PER_SEC)
        ),
        dispatch_get_main_queue(),
        ^{

            @autoreleasepool {

                NSLog(
                    @"[SleepMode] delayed initialization"
                );


                SleepManager *manager =
                    [SleepManager sharedInstance];


                if (manager.enabled) {

                    NSLog(
                        @"[SleepMode] enabled = YES"
                    );

                    NSLog(
                        @"[SleepMode] timeout = %.0f",
                        manager.timeout
                    );


                    [manager start];

                } else {

                    NSLog(
                        @"[SleepMode] enabled = NO"
                    );
                }
            }
        }
    );
}


#pragma mark -
#pragma mark Touch

- (void)sendEvent:(UIEvent *)event
{
    /*
     * Chỉ reset khi có touch mới bắt đầu.
     *
     * Không reset ở TouchMoved / TouchEnded,
     * tránh việc đang giữ ngón tay khiến timer
     * bị tạo lại liên tục.
     */

    if (event &&
        event.type == UIEventTypeTouches) {

        NSSet *touches =
            event.allTouches;


        BOOL beganTouch =
            NO;


        for (UITouch *touch
             in touches) {

            if (touch.phase ==
                UITouchPhaseBegan) {

                beganTouch =
                    YES;

                break;
            }
        }


        if (beganTouch) {

            SleepManager *manager =
                [SleepManager sharedInstance];


            if (manager.enabled) {

                [manager resetTimer];
            }
        }
    }


    %orig;
}


%end
