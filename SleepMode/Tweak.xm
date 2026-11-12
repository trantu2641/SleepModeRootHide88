#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>

#import "SleepManager.h"

#pragma mark - Private SpringBoard Classes

@interface SBIdleTimerGlobalCoordinator : NSObject
@end

@interface SBBacklightController : NSObject
@end

#pragma mark - Activity State

static BOOL gSleepModeInitialized = NO;

static void SleepModeRegisterActivity(void)
{
    if (!gSleepModeInitialized) {
        return;
    }

    [[SleepManager sharedInstance]
        userDidInteract];
}

#pragma mark - SpringBoard

%group SpringBoardGroup

/*
 * Đây là điểm rất gần với cơ chế Auto-Lock của SpringBoard.
 *
 * Không tự tạo gesture recognizer.
 * Không inject vào app.
 *
 * Mỗi khi SpringBoard xử lý reset idle timer,
 * SleepMode reset bộ đếm của chính nó.
 */
%hook SBIdleTimerGlobalCoordinator

- (void)resetIdleTimer
{
    %orig;

    SleepModeRegisterActivity();
}

%end


/*
 * SpringBoard là UIApplication của hệ thống.
 *
 * sendEvent: được giữ làm lớp bổ sung.
 * Không phụ thuộc vào nó một mình.
 */
%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application
{
    %orig;

    NSLog(@"[SleepMode] SpringBoard started");

    [SleepManager sharedInstance];
}

/*
 * Một số event hệ thống đi qua UIApplication của SpringBoard.
 * Nếu event là touch/press thì reset timer.
 */
- (void)sendEvent:(UIEvent *)event
{
    if (event != nil) {

        UIEventType type = event.type;

        if (type == UIEventTypeTouches ||
            type == UIEventTypePresses) {

            NSSet *touches =
                [event allTouches];

            if (touches.count > 0) {
                SleepModeRegisterActivity();
            }
        }
    }

    %orig;
}

%end

#pragma mark - SpringBoard Touch / Gesture Activity

/*
 * SpringBoard có rất nhiều gesture recognizer.
 *
 * Các callback này không dùng để điều khiển gesture.
 * Chỉ dùng làm tín hiệu activity.
 */
%hook UIGestureRecognizer

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    BOOL result = %orig;

    if (result) {
        SleepModeRegisterActivity();
    }

    return result;
}

%end

%end

#pragma mark - Constructor

%ctor
{
    NSString *bundleID =
        [[NSBundle mainBundle]
            bundleIdentifier];

    if ([bundleID
            isEqualToString:
                @"com.apple.springboard"]) {

        NSLog(@"[SleepMode] Injected into SpringBoard");

        gSleepModeInitialized = YES;

        %init(SpringBoardGroup);
    }
}
