#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "SleepManager.h"

#pragma mark - Touch detection

%hook UIApplication

- (void)sendEvent:(UIEvent *)event
{
    %orig;

    /*
     * SleepMode chỉ được inject vào SpringBoard.
     *
     * Vì vậy sendEvent: ở đây là event của SpringBoard:
     *
     * Home Screen
     * Control Center
     * Lock-related UI
     * các màn hình hệ thống khác
     *
     * Không inject vào app người dùng.
     */

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

#pragma mark - SpringBoard startup

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
