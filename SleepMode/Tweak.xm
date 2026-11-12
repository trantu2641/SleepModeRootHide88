#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "SleepManager.h"

#pragma mark - SpringBoard

%group SpringBoardGroup

/*
 * SBIdleTimerGlobalCoordinator
 *
 * SpringBoard sử dụng class này để quản lý
 * idle timer toàn hệ thống.
 *
 * NexusBoard binary mà bạn cung cấp cũng có
 * selector:
 *
 *     resetIdleTimer
 *
 * Vì vậy SleepMode sẽ dùng chính điểm này
 * để biết hệ thống vừa nhận interaction.
 */

%hook SBIdleTimerGlobalCoordinator

- (void)resetIdleTimer
{
    /*
     * Cho SpringBoard xử lý bình thường trước.
     */
    %orig;

    /*
     * Báo cho SleepManager:
     *
     * "Có hoạt động người dùng"
     *
     * Không cần biết interaction bắt nguồn
     * từ Safari, game, Settings hay app nào.
     */
    [[SleepManager sharedInstance]
        userDidInteract];
}

%end


#pragma mark - SpringBoard Startup

%hook SpringBoard

- (void)applicationDidFinishLaunching:
    (id)application
{
    %orig;

    NSLog(
        @"[SleepMode] SpringBoard started"
    );

    /*
     * Khởi động SleepManager.
     */
    [SleepManager sharedInstance];
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

        NSLog(
            @"[SleepMode] Injected into SpringBoard"
        );

        %init(SpringBoardGroup);

        return;
    }

    /*
     * Không làm gì trong các app khác.
     */
}
