#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "SleepManager.h"

%hook UIApplication

- (void)sendEvent:(UIEvent *)event
{
    if (event != nil) {

        BOOL hasTouch =
            [event allTouches].count > 0;

        if (hasTouch) {
            [[SleepManager sharedInstance]
                userDidInteract];

            NSLog(
                @"[SleepMode] User interaction detected"
            );
        }
    }

    %orig(event);
}

%end


%hook SpringBoard

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
    %orig(application);

    NSLog(@"[SleepMode] SpringBoard started");

    [[SleepManager sharedInstance] start];
}

%end


%ctor
{
    @autoreleasepool {

        NSLog(@"[SleepMode] Injected into SpringBoard");

        SleepManager *manager =
            [SleepManager sharedInstance];

        (void)manager;

        NSLog(
            @"[SleepMode] Core initialized"
        );
    }
}
