#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>

#import "SleepManager.h"

static NSString * const kSleepTouchNotification =
    @"com.trantu.sleepmode.touch";

static void NotifySleepModeTouch(void)
{
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),

        (__bridge CFStringRef)
            kSleepTouchNotification,

        NULL,
        NULL,
        YES
    );
}

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

%end

%end

#pragma mark - Touch Reporter

%group TouchReporterGroup

%hook UIApplication

- (void)sendEvent:(UIEvent *)event
{
    %orig;

    if (event.type != UIEventTypeTouches) {
        return;
    }

    NSSet *touches =
        [event allTouches];

    if (touches.count == 0) {
        return;
    }

    for (UITouch *touch in touches) {

        if (touch.phase ==
            UITouchPhaseBegan) {

            NotifySleepModeTouch();

            break;
        }
    }
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

    /*
     * SpringBoard:
     * chạy SleepManager.
     */

    if ([bundleID
            isEqualToString:
                @"com.apple.springboard"]) {

        %init(SpringBoardGroup);

        return;
    }

    /*
     * Tất cả process/app còn lại:
     * hook UIApplication để phát hiện touch.
     *
     * RootHide Bootstrap quyết định
     * process nào thực tế được inject.
     */

    %init(TouchReporterGroup);
}
