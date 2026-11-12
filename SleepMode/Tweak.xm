#import <UIKit/UIKit.h>

#import "SleepManager.h"


%hook UIApplication


- (void)sendEvent:(UIEvent *)event
{
    SleepManager *manager =
        [SleepManager sharedInstance];


    if (manager.isEnabled) {

        UIEventType type =
            event.type;

        if (type == UIEventTypeTouches) {

            NSSet *touches =
                [event allTouches];

            BOOL hasRealTouch = NO;

            for (UITouch *touch in touches) {

                UITouchPhase phase =
                    touch.phase;

                if (phase == UITouchPhaseBegan ||
                    phase == UITouchPhaseMoved ||
                    phase == UITouchPhaseEnded ||
                    phase == UITouchPhaseCancelled) {

                    hasRealTouch = YES;
                    break;
                }
            }

            if (hasRealTouch) {
                [manager resetTimer];
            }
        }
    }


    %orig;
}

%end


%hook SpringBoard


- (void)applicationDidFinishLaunching:(id)application
{
    %orig;


    SleepManager *manager =
        [SleepManager sharedInstance];

    if (manager.isEnabled) {
        [manager start];
    }
    else {
        [manager stop];
    }
}

%end


%ctor
{
}
