#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "SleepManager.h"

static SleepManager *SMManager(void)
{
    return [SleepManager sharedInstance];
}


%hook SpringBoard

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
    %orig;

    dispatch_async(dispatch_get_main_queue(), ^{

        SleepManager *manager = SMManager();

        if (manager.enabled) {
            [manager start];
        }

    });
}

%end


/*
 * SpringBoard nhận các touch event trên Home Screen,
 * Control Center, Lock UI trước khi khóa...
 *
 * Mỗi touch sẽ reset timer.
 */
%hook UIApplication

- (void)sendEvent:(UIEvent *)event
{
    if (event &&
        event.type == UIEventTypeTouches) {

        NSSet *touches = event.allTouches;

        if (touches.count > 0) {

            BOOL hasActiveTouch = NO;

            for (UITouch *touch in touches) {

                if (touch.phase == UITouchPhaseBegan ||
                    touch.phase == UITouchPhaseMoved ||
                    touch.phase == UITouchPhaseStationary) {

                    hasActiveTouch = YES;
                    break;
                }
            }

            if (hasActiveTouch) {
                [SMManager() resetTimer];
            }
        }
    }

    %orig;
}

%end


%ctor
{
    /*
     * Tweak chỉ được load trong SpringBoard
     * theo SleepMode.plist.
     */
}
