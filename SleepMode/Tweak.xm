#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "SleepManager.h"

#pragma mark - Touch Reset

%hook UIApplication

- (void)sendEvent:(UIEvent *)event
{
    %orig;

    /*
     * Giữ đúng cơ chế của bản 1.3.0:
     * nhận touch trong SpringBoard rồi gọi thẳng resetTimer.
     * Không tạo Darwin notification cho từng touch.
     */
    if (event != nil && event.type == UIEventTypeTouches) {
        SleepManager *manager = [SleepManager sharedInstance];

        if (manager.enabled) {
            [manager resetTimer];
        }
    }
}

%end

#pragma mark - SpringBoard Startup

%hook SpringBoard

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
    %orig;

    @autoreleasepool {
        SleepManager *manager = [SleepManager sharedInstance];
        [manager start];
    }
}

%end
