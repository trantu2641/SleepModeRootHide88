#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "SleepManager.h"


%hook UIApplication

- (void)sendEvent:(UIEvent *)event
{
    if (event != nil &&
        event.allTouches.count > 0) {

        [[SleepManager sharedInstance]
            userDidInteract];
    }

    %orig(event);
}

%end


%hook SpringBoard

- (void)applicationDidFinishLaunching:
    (UIApplication *)application
{
    %orig(application);

    NSLog(@"[SleepMode] SpringBoard launched");

    [[SleepManager sharedInstance]
        start];
}

%end


%ctor
{
    @autoreleasepool {

        SleepManager *manager =
            [SleepManager sharedInstance];

        (void)manager;

        NSLog(@"[SleepMode] Loaded");
    }
}
