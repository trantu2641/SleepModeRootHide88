#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "SleepManager.h"


%hook SpringBoard


- (void)applicationDidFinishLaunching:
    (UIApplication *)application
{
    %orig(application);


    NSLog(
        @"[SleepMode] Injected into SpringBoard"
    );


    [[SleepManager sharedInstance]
        start];
}


- (void)sendEvent:(UIEvent *)event
{
    if (event != nil) {

        NSSet *touches =
            [event allTouches];

        if (touches != nil &&
            touches.count > 0) {

            [[SleepManager sharedInstance]
                userDidInteract];
        }
    }


    %orig(event);
}


%end


%ctor
{
    @autoreleasepool {

        SleepManager *manager =
            [SleepManager sharedInstance];

        (void)manager;

        NSLog(
            @"[SleepMode] Core + Settings ready"
        );
    }
}
