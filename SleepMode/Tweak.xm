#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "SleepManager.h"

#pragma mark - SpringBoard touch detection

%hook UIApplication

- (void)sendEvent:(UIEvent *)event
{
    // Chỉ inject trong SpringBoard theo SleepMode.plist.
    // Không hook hay inject vào tiến trình ứng dụng người dùng.
    if (event != nil && event.type == UIEventTypeTouches) {
        SleepManager *manager = [SleepManager sharedInstance];

        if ([manager isEnabled]) {
            [manager resetTimer];
        }
    }

    %orig;
}

%end

#pragma mark - SpringBoard startup

%hook SpringBoard

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
    %orig;

    SleepManager *manager = [SleepManager sharedInstance];

    if ([manager isEnabled]) {
        [manager start];
    } else {
        [manager stop];
    }
}

%end
