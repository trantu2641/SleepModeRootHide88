#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "SleepManager.h"

#pragma mark - SpringBoard

%group SpringBoardGroup

%hook SpringBoard

- (void)applicationDidFinishLaunching:
    (id)application
{
    %orig;

    NSLog(
        @"[SleepMode] SpringBoard started"
    );

    [SleepManager sharedInstance];
}

#pragma mark - SpringBoard Event

- (void)sendEvent:(UIEvent *)event
{
    /*
     * Kiểm tra touch trước.
     *
     * Không reset timer đối với:
     * - keyboard
     * - motion
     * - remote control
     * - các event không phải touch
     */

    if (event != nil &&
        event.type == UIEventTypeTouches) {

        NSSet *touches =
            [event allTouches];

        for (UITouch *touch
             in touches) {

            UITouchPhase phase =
                touch.phase;

            if (phase == UITouchPhaseBegan ||
                phase == UITouchPhaseMoved ||
                phase == UITouchPhaseEnded) {

                NSLog(
                    @"[SleepMode] SpringBoard touch detected"
                );

                [[SleepManager sharedInstance]
                    userDidInteract];

                break;
            }
        }
    }

    %orig;
}

%end

%end

#pragma mark - Constructor

%ctor
{
    NSString *bundleID =
        [[NSBundle mainBundle]
            bundleIdentifier];

    if (bundleID == nil) {
        return;
    }

    if ([bundleID
            isEqualToString:
                @"com.apple.springboard"]) {

        NSLog(
            @"[SleepMode] Injected into SpringBoard"
        );

        %init(SpringBoardGroup);
    }
}
