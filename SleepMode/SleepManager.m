#import "SleepManager.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/message.h>

#pragma mark - Constants

static NSString * const kSleepTouchNotification =
    @"com.trantu.sleepmode.touch";

#pragma mark - Private API Helpers

static id SMCallObject(
    id target,
    SEL selector
)
{
    if (target == nil ||
        ![target respondsToSelector:selector]) {
        return nil;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

    return [target performSelector:selector];

#pragma clang diagnostic pop
}

static id SMCallObjectArg(
    id target,
    SEL selector,
    id argument
)
{
    if (target == nil ||
        ![target respondsToSelector:selector]) {
        return nil;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

    return [target performSelector:selector
                        withObject:argument];

#pragma clang diagnostic pop
}

#pragma mark - Forward Declaration

static void SleepModeTouchCallback(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo
);

#pragma mark - SleepManager

@interface SleepManager ()
{
    dispatch_source_t _timer;

    CFAbsoluteTime _lastInteraction;

    BOOL _isEnteringSleep;
}
@end

@implementation SleepManager

#pragma mark - Singleton

+ (instancetype)sharedInstance
{
    static SleepManager *sharedInstance = nil;

    static dispatch_once_t onceToken;

    dispatch_once(
        &onceToken,
        ^{
            sharedInstance =
                [[self alloc] init];
        }
    );

    return sharedInstance;
}

#pragma mark - Init

- (instancetype)init
{
    self = [super init];

    if (self) {

        /*
         * CORE TEST
         *
         * Hiện tại test 60 giây.
         *
         * Sau khi core ổn định sẽ chuyển sang:
         *
         * 60
         * 300
         * 900
         * 1800
         * 3600
         * 7200
         */

        _enabled = YES;

        _timeout = 60.0;

        _lastInteraction =
            CFAbsoluteTimeGetCurrent();

        _isEnteringSleep = NO;

        /*
         * Nhận thông báo khi có touch
         * từ các process khác.
         */

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),

            (__bridge const void *)self,

            SleepModeTouchCallback,

            (__bridge CFStringRef)
                kSleepTouchNotification,

            NULL,

            CFNotificationSuspensionBehaviorDeliverImmediately
        );

        [self start];
    }

    return self;
}

#pragma mark - Start

- (void)start
{
    if (!self.enabled) {
        return;
    }

    if (_timer != nil) {
        return;
    }

    _timer =
        dispatch_source_create(
            DISPATCH_SOURCE_TYPE_TIMER,
            0,
            0,
            dispatch_get_main_queue()
        );

    if (_timer == nil) {
        return;
    }

    /*
     * Kiểm tra mỗi 1 giây.
     */

    dispatch_source_set_timer(
        _timer,

        dispatch_time(
            DISPATCH_TIME_NOW,
            NSEC_PER_SEC
        ),

        NSEC_PER_SEC,

        100 * NSEC_PER_MSEC
    );

    __weak SleepManager *weakSelf =
        self;

    dispatch_source_set_event_handler(
        _timer,
        ^{
            SleepManager *strongSelf =
                weakSelf;

            if (strongSelf == nil) {
                return;
            }

            if (!strongSelf.enabled) {
                return;
            }

            if (strongSelf.timeout <= 0.0) {
                return;
            }

            if (strongSelf->_isEnteringSleep) {
                return;
            }

            CFAbsoluteTime now =
                CFAbsoluteTimeGetCurrent();

            CFAbsoluteTime elapsed =
                now -
                strongSelf->_lastInteraction;

            if (elapsed >=
                strongSelf.timeout) {

                [strongSelf enterSleepMode];
            }
        }
    );

    dispatch_resume(_timer);
}

#pragma mark - Stop

- (void)stop
{
    if (_timer != nil) {

        dispatch_source_cancel(_timer);

        _timer = nil;
    }
}

#pragma mark - Reset Timer

- (void)resetTimer
{
    _lastInteraction =
        CFAbsoluteTimeGetCurrent();

    _isEnteringSleep = NO;
}

#pragma mark - User Interaction

- (void)userDidInteract
{
    if (!self.enabled) {
        return;
    }

    /*
     * Bất kỳ touch nào cũng reset
     * thời gian chờ.
     */

    [self resetTimer];
}

#pragma mark - Terminate User Applications

- (void)terminateUserApplications
{
    /*
     * Chỉ thực hiện trong SpringBoard.
     *
     * Tuyệt đối không dùng kill(pid, SIGKILL)
     * cho toàn bộ process.
     */

    Class SBApplicationControllerClass =
        NSClassFromString(
            @"SBApplicationController"
        );

    if (SBApplicationControllerClass == Nil) {

        NSLog(
            @"[SleepMode] SBApplicationController unavailable"
        );

        return;
    }

    id controller = nil;

    SEL sharedInstanceSelector =
        @selector(sharedInstance);

    if ([SBApplicationControllerClass
            respondsToSelector:
                sharedInstanceSelector]) {

        controller =
            ((id (*)(id, SEL))
                objc_msgSend)(
                SBApplicationControllerClass,
                sharedInstanceSelector
            );
    }

    if (controller == nil) {

        NSLog(
            @"[SleepMode] Cannot get SBApplicationController"
        );

        return;
    }

    /*
     * Ưu tiên runningApplications.
     */

    NSArray *runningApplications = nil;

    SEL runningApplicationsSelector =
        @selector(runningApplications);

    if ([controller
            respondsToSelector:
                runningApplicationsSelector]) {

        runningApplications =
            SMCallObject(
                controller,
                runningApplicationsSelector
            );
    }

    /*
     * Fallback sang allApplications.
     */

    if (![runningApplications isKindOfClass:
            [NSArray class]]) {

        SEL allApplicationsSelector =
            @selector(allApplications);

        if ([controller
                respondsToSelector:
                    allApplicationsSelector]) {

            NSArray *allApplications =
                SMCallObject(
                    controller,
                    allApplicationsSelector
                );

            if ([allApplications
                    isKindOfClass:
                        [NSArray class]]) {

                NSMutableArray *filtered =
                    [NSMutableArray array];

                for (id app in allApplications) {

                    BOOL isRunning = NO;

                    SEL isRunningSelector =
                        @selector(isRunning);

                    if ([app
                            respondsToSelector:
                                isRunningSelector]) {

                        isRunning =
                            ((BOOL (*)(id, SEL))
                                objc_msgSend)(
                                app,
                                isRunningSelector
                            );
                    }

                    if (isRunning) {

                        [filtered
                            addObject:app];
                    }
                }

                runningApplications =
                    [filtered copy];
            }
        }
    }

    if (runningApplications.count == 0) {

        NSLog(
            @"[SleepMode] No running applications found"
        );

        return;
    }

    /*
     * FBSSystemService
     *
     * Đây là service của FrontBoard dùng để
     * yêu cầu hệ thống terminate application.
     */

    Class FBSSystemServiceClass =
        NSClassFromString(
            @"FBSSystemService"
        );

    id fbsService = nil;

    if (FBSSystemServiceClass != Nil) {

        SEL sharedServiceSelector =
            @selector(sharedService);

        if ([FBSSystemServiceClass
                respondsToSelector:
                    sharedServiceSelector]) {

            fbsService =
                ((id (*)(id, SEL))
                    objc_msgSend)(
                    FBSSystemServiceClass,
                    sharedServiceSelector
                );
        }
    }

    if (fbsService == nil) {

        NSLog(
            @"[SleepMode] FBSSystemService unavailable"
        );

        return;
    }

    SEL terminateSelector =
        @selector(
            terminateApplication:
            forReason:
            andReport:
            withDescription:
        );

    if (![fbsService
            respondsToSelector:
                terminateSelector]) {

        NSLog(
            @"[SleepMode] Termination selector unavailable"
        );

        return;
    }

    /*
     * Các bundle không được đụng vào.
     *
     * SpringBoard tuyệt đối không được terminate.
     */

    NSSet *excludedBundleIDs =
        [NSSet setWithObjects:

            @"com.apple.springboard",

            @"com.apple.Preferences",

            @"com.apple.WebKit.Networking",

            @"com.apple.WebKit.WebContent",

            @"com.apple.WebKit.GPU",

            @"com.apple.UIKit.pasteboardd",

            @"com.apple.Pasteboard",

            nil];

    for (id app
         in runningApplications) {

        if (app == nil) {
            continue;
        }

        NSString *bundleID = nil;

        SEL bundleIdentifierSelector =
            @selector(bundleIdentifier);

        if ([app
                respondsToSelector:
                    bundleIdentifierSelector]) {

            bundleID =
                SMCallObject(
                    app,
                    bundleIdentifierSelector
                );
        }

        if (![bundleID
                isKindOfClass:
                    [NSString class]]) {

            continue;
        }

        if (bundleID.length == 0) {
            continue;
        }

        /*
         * Không terminate SpringBoard
         * hoặc các process được bảo vệ.
         */

        if ([excludedBundleIDs
                containsObject:
                    bundleID]) {

            continue;
        }

        /*
         * Chỉ xử lý bundle của app.
         *
         * Apple system application có thể bắt đầu
         * bằng com.apple.
         *
         * Ở phiên bản đầu này:
         *
         * - com.apple.springboard -> bỏ qua
         * - các system process không nằm trong
         *   SBApplicationController thường không
         *   xuất hiện ở đây
         *
         * Nhưng để an toàn, không đụng tới
         * bundle com.apple.*.
         */

        if ([bundleID
                hasPrefix:
                    @"com.apple."]) {

            continue;
        }

        NSLog(
            @"[SleepMode] Terminating app: %@",
            bundleID
        );

        NSString *description =
            @"SleepMode automatic idle termination";

        long long reason = 5;

        BOOL report = NO;

        ((void (*)(id,
                   SEL,
                   id,
                   long long,
                   BOOL,
                   id))
            objc_msgSend)(
            fbsService,
            terminateSelector,
            bundleID,
            reason,
            report,
            description
        );
    }
}

#pragma mark - Enter Sleep Mode

- (void)enterSleepMode
{
    if (_isEnteringSleep) {
        return;
    }

    /*
     * Đánh dấu ngay lập tức.
     *
     * Không gọi resetTimer() ở đây vì
     * resetTimer() sẽ hạ _isEnteringSleep về NO.
     */

    _isEnteringSleep = YES;

    NSLog(
        @"[SleepMode] Timeout reached"
    );

    /*
     * Bước 1:
     * đóng app người dùng.
     */

    [self terminateUserApplications];

    /*
     * Cho SpringBoard một khoảng thời gian
     * xử lý termination request.
     *
     * Không khóa ngay lập tức để tránh
     * request terminate và lock đè lên nhau.
     */

    __weak SleepManager *weakSelf =
        self;

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            300 * NSEC_PER_MSEC
        ),
        dispatch_get_main_queue(),
        ^{
            SleepManager *strongSelf =
                weakSelf;

            if (strongSelf == nil) {
                return;
            }

            [strongSelf lockDevice];

            /*
             * Giữ guard một chút trong chu kỳ
             * hiện tại, sau đó cho phép timer
             * hoạt động lại.
             */

            strongSelf->_lastInteraction =
                CFAbsoluteTimeGetCurrent();

            strongSelf->_isEnteringSleep =
                NO;
        }
    );
}

#pragma mark - Lock Device

- (void)lockDevice
{
    /*
     * Cách 1:
     * SBLockScreenManager
     */

    Class lockManagerClass =
        NSClassFromString(
            @"SBLockScreenManager"
        );

    if (lockManagerClass != Nil) {

        id manager = nil;

        SEL sharedInstanceSelector =
            @selector(sharedInstance);

        if ([lockManagerClass
                respondsToSelector:
                    sharedInstanceSelector]) {

            manager =
                ((id (*)(id, SEL))
                    objc_msgSend)(
                    lockManagerClass,
                    sharedInstanceSelector
                );
        }

        SEL lockDeviceSelector =
            @selector(lockDevice);

        if (manager != nil &&
            [manager
                respondsToSelector:
                    lockDeviceSelector]) {

            NSLog(
                @"[SleepMode] Locking device via SBLockScreenManager"
            );

            ((void (*)(id, SEL))
                objc_msgSend)(
                manager,
                lockDeviceSelector
            );

            return;
        }
    }

    /*
     * Cách 2:
     * SpringBoard _simulateLockButtonPress
     */

    UIApplication *application =
        [UIApplication sharedApplication];

    SEL simulateLockSelector =
        @selector(
            _simulateLockButtonPress
        );

    if (application != nil &&
        [application
            respondsToSelector:
                simulateLockSelector]) {

        NSLog(
            @"[SleepMode] Locking device via _simulateLockButtonPress"
        );

        ((void (*)(id, SEL))
            objc_msgSend)(
            application,
            simulateLockSelector
        );

        return;
    }

    NSLog(
        @"[SleepMode] Unable to lock device"
    );
}

#pragma mark - Dealloc

- (void)dealloc
{
    [self stop];

    CFNotificationCenterRemoveObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),

        (__bridge const void *)self,

        (__bridge CFStringRef)
            kSleepTouchNotification,

        NULL
    );
}

@end

#pragma mark - Darwin Notification Callback

static void SleepModeTouchCallback(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo
)
{
    SleepManager *manager =
        (__bridge SleepManager *)observer;

    if (manager == nil) {
        return;
    }

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            [manager userDidInteract];
        }
    );
}
