#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "SleepManager.h"


@interface SpringBoard : UIApplication
@end


%hook SpringBoard


- (void)applicationDidFinishLaunching:(UIApplication *)application
{
    %orig;


    /*
     * Không làm gì trong launch callback.
     * Chỉ lên lịch khởi động SleepMode sau 3 giây.
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


                NSLog(
                    @"[SleepMode] enabled=%@ timeout=%.0f",
                    manager.enabled
                        ? @"YES"
                        : @"NO",
                    manager.timeout
                );


                if (manager.enabled) {

                    [manager start];
                }
            }
        }
    );
}


#pragma mark -
#pragma mark Touch

- (void)sendEvent:(UIEvent *)event
{
    if (event &&
        event.type == UIEventTypeTouches) {

        NSSet *touches =
            event.allTouches;


        BOOL began =
            NO;


        for (UITouch *touch
             in touches) {

            if (touch.phase ==
                UITouchPhaseBegan) {

                began = YES;

                break;
            }
        }


        if (began) {

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
