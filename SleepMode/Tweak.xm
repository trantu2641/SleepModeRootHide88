#import <UIKit/UIKit.h>

#import "SleepManager.h"

#pragma mark - UIApplication

%hook UIApplication

- (void)sendEvent:(UIEvent *)event
{
    %orig;

    if (event != nil &&
        event.type == UIEventTypeTouches) {

        SleepManager *manager =
            [SleepManager sharedInstance];

        if (manager.enabled) {
            [manager resetTimer];
        }
    }
}

%end

#pragma mark - SpringBoard

%hook SpringBoard

- (void)applicationDidFinishLaunching:
    (UIApplication *)application
{
    %orig;

    SleepManager *manager =
        [SleepManager sharedInstance];

    if (manager.enabled) {
        [manager start];
    }
}

%end
