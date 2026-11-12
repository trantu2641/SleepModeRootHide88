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


#pragma mark -
#pragma mark SpringBoard

%group SpringBoardGroup

%hook SpringBoard

- (void)applicationDidFinishLaunching:
    (id)application
{
    %orig;

    /*
     * Khởi động SleepManager
     * trong SpringBoard.
     */
    [SleepManager sharedInstance];
}

%end

%end


#pragma mark -
#pragma mark Touch Reporter

%group TouchReporterGroup

%hook UIApplication

- (void)sendEvent:(UIEvent *)event
{
    if (event.type ==
        UIEventTypeTouches) {

        NSSet *touches =
            [event allTouches];

        if (touches.count > 0) {

            for (UITouch *touch
                 in touches) {

                if (touch.phase ==
                    UITouchPhaseBegan) {

                    NotifySleepModeTouch();

                    break;
                }
            }
        }
    }

    %orig;
}

%end

%end


#pragma mark -
#pragma mark Constructor

%ctor
{
    NSString *bundleID =
        [[NSBundle mainBundle]
            bundleIdentifier];

    if ([bundleID isEqualToString:
            @"com.apple.springboard"]) {

        %init(SpringBoardGroup);

        return;
    }

    /*
     * Touch reporter chạy trong
     * app người dùng.
     */
    %init(TouchReporterGroup);
}
