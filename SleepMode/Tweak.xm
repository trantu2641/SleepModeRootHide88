#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "SleepManager.h"
#import "SleepControlCenter.h"


%group SleepModeGroup


#pragma mark - SpringBoard

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application
{
    %orig;

    /*
     * Khởi tạo singleton.
     */
    [SleepManager sharedInstance];

    [SleepControlCenter sharedInstance];
}


- (void)sendEvent:(UIEvent *)event
{
    /*
     * Chỉ xử lý TOUCH BEGAN.
     *
     * Không xử lý:
     *
     * - Moved
     * - Stationary
     * - Ended
     *
     * để tránh reset timer hàng chục/hàng trăm lần
     * trong một thao tác vuốt.
     */

    if (event != nil &&
        event.type == UIEventTypeTouches) {

        NSSet *touches =
            [event allTouches];

        if (touches.count > 0) {

            for (UITouch *touch in touches) {

                if (touch.phase ==
                    UITouchPhaseBegan) {

                    [[SleepManager sharedInstance]
                        userDidInteract];

                    break;
                }
            }
        }
    }

    /*
     * Luôn trả event về SpringBoard ngay.
     */
    %orig;
}

%end


#pragma mark - System Idle Timer

%hook SBIdleTimerGlobalCoordinator

- (void)resetIdleTimer
{
    %orig;

    /*
     * Hệ thống tự reset idle timer.
     * Đây cũng được xem là activity.
     */
    [[SleepManager sharedInstance]
        userDidInteract];
}

%end


#pragma mark - Lock / Unlock

%hook SBLockScreenManager

- (void)lockFromSource:(int)source
{
    %orig;

    /*
     * Khi thiết bị khóa:
     *
     * - dừng timer
     * - không tiếp tục đếm
     */
    [[SleepManager sharedInstance]
        deviceDidLock];
}


- (void)unlockUIFromSource:(int)source
              withOptions:(id)options
{
    %orig;

    /*
     * Unlock:
     *
     * - bắt đầu chu kỳ mới
     * - timer tính từ 0
     */
    [[SleepManager sharedInstance]
        deviceDidUnlock];
}

%end


#pragma mark - Constructor

%ctor
{
    NSString *bundleID =
        [[NSBundle mainBundle]
            bundleIdentifier];

    /*
     * CHỈ inject vào SpringBoard.
     *
     * Không inject vào app người dùng.
     */
    if ([bundleID
            isEqualToString:
                @"com.apple.springboard"]) {

        %init(SleepModeGroup);

        [SleepManager sharedInstance];

        [SleepControlCenter sharedInstance];
    }
}

%end
