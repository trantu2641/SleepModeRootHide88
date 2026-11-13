#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "SleepManager.h"


#pragma mark -
#pragma mark SpringBoard

@interface SpringBoard : UIApplication
@end


%hook SpringBoard


- (void)applicationDidFinishLaunching:(UIApplication *)application
{
    %orig;


    /*
     * Không khởi tạo SleepManager trực tiếp
     * trong quá trình SpringBoard đang launch.
     *
     * Chờ SpringBoard hoàn tất callback launch
     * rồi mới khởi động SleepMode.
     */

    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            dispatch_async(
                dispatch_get_main_queue(),
                ^{

                    @autoreleasepool {

                        SleepManager *manager =
                            [SleepManager sharedInstance];


                        NSLog(
                            @"[SleepMode] SpringBoard ready"
                        );


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
    );
}


#pragma mark -
#pragma mark Touch


- (void)sendEvent:(UIEvent *)event
{
    /*
     * Chỉ reset khi thực sự bắt đầu
     * một thao tác chạm mới.
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

                NSLog(
                    @"[SleepMode] touch -> reset timer"
                );

                [manager resetTimer];
            }
        }
    }


    %orig;
}


%end
