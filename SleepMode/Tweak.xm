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
     * Không khởi tạo SleepManager trong launch callback.
     *
     * Chờ SpringBoard hoàn tất quá trình launch
     * rồi mới khởi động SleepMode.
     */

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)(2.0 * NSEC_PER_SEC)
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


%end
