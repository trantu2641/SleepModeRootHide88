#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "SleepManager.h"


static SleepManager *SMManager(void)
{
    return [SleepManager sharedInstance];
}


#pragma mark -
#pragma mark SpringBoard


%hook SpringBoard


- (void)applicationDidFinishLaunching:(UIApplication *)application
{
    %orig;


    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            SleepManager *manager =
                SMManager();


            NSLog(
                @"[SleepMode] SpringBoard launched"
            );


            if (manager.enabled) {

                NSLog(
                    @"[SleepMode] enabled at launch, timeout=%.0f",
                    manager.timeout
                );

                [manager start];

            } else {

                NSLog(
                    @"[SleepMode] disabled at launch"
                );
            }
        }
    );
}


%end


#pragma mark -
#pragma mark Touch Detection


%hook UIApplication


- (void)sendEvent:(UIEvent *)event
{
    /*
     * Chỉ xử lý touch event.
     */

    if (event &&
        event.type == UIEventTypeTouches) {

        NSSet *touches =
            event.allTouches;


        if (touches.count > 0) {

            BOOL hasNewTouch =
                NO;


            for (UITouch *touch
                 in touches) {

                /*
                 * Chỉ reset timer khi có touch
                 * mới bắt đầu.
                 *
                 * Không dùng Moved/Stationary,
                 * tránh reset timer liên tục.
                 */

                if (touch.phase ==
                    UITouchPhaseBegan) {

                    hasNewTouch =
                        YES;

                    break;
                }
            }


            if (hasNewTouch) {

                SleepManager *manager =
                    SMManager();


                if (manager.enabled) {

                    [manager resetTimer];
                }
            }
        }
    }


    %orig;
}


%end


#pragma mark -
#pragma mark Constructor


%ctor
{
    /*
     * SleepMode.plist chỉ inject vào:
     *
     * com.apple.springboard
     *
     * nên toàn bộ tweak này chạy trong SpringBoard.
     */
}
