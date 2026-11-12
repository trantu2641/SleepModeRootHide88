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

    /*
     * YES:
     *   thiết bị đang khóa
     *
     * Khi YES:
     *   không chạy timer
     *   không đếm thời gian
     *   touch không reset timer
     */
    BOOL _deviceLocked;
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

        _enabled = YES;

        /*
         * TEST MODE
         *
         * Không hoạt động trong 15 giây
         * thì SleepMode xử lý.
         */
        _timeout = 15.0;

        _lastInteraction =
            CFAbsoluteTimeGetCurrent();

        _isEnteringSleep = NO;

        /*
         * Khi SpringBoard vừa khởi động,
         * mặc định coi thiết bị đang unlock.
         */
        _deviceLocked = NO;

        /*
         * Darwin notification touch.
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


#pragma mark - Start Timer

- (void)start
{
    /*
     * Không chạy khi disabled.
     */
    if (!self.enabled) {
        return;
    }

    /*
     * Không chạy khi máy đang khóa.
     */
    if (_deviceLocked) {
        return;
    }

    /*
     * Timer đã chạy rồi.
     */
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
            1 * NSEC_PER_SEC
        ),

        1 * NSEC_PER_SEC,

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

            /*
             * Disabled.
             */
            if (!strongSelf.enabled) {
                return;
            }

            /*
             * Thiết bị đang khóa.
             *
             * Không đếm.
             */
            if (strongSelf->_deviceLocked) {
                return;
            }

            /*
             * Đang thực hiện sleep.
             */
            if (strongSelf->_isEnteringSleep) {
                return;
            }

            if (strongSelf.timeout <= 0.0) {
                return;
            }

            CFAbsoluteTime now =
                CFAbsoluteTimeGetCurrent();

            CFAbsoluteTime elapsed =
                now -
                strongSelf->_lastInteraction;

            if (elapsed >=
                strongSelf.timeout) {

                NSLog(
                    @"[SleepMode] Timeout reached after %.1f seconds",
                    elapsed
                );

                [strongSelf enterSleepMode];
            }
        }
    );

    dispatch_resume(_timer);

    NSLog(
        @"[SleepMode] Timer started, timeout = %.1f seconds",
        self.timeout
    );
}


#pragma mark - Stop Timer

- (void)stop
{
    if (_timer != nil) {

        dispatch_source_cancel(_timer);

        _timer = nil;

        NSLog(@"[SleepMode] Timer stopped");
    }
}


#pragma mark - Reset Timer

- (void)resetTimer
{
    /*
     * Nếu đang khóa thì không reset.
     */
    if (_deviceLocked) {
        return;
    }

    _lastInteraction =
        CFAbsoluteTimeGetCurrent();

    _isEnteringSleep = NO;

    NSLog(@"[SleepMode] Timer reset");
}


#pragma mark - User Interaction

- (void)userDidInteract
{
    if (!self.enabled) {
        return;
    }

    /*
     * Khi lock screen:
     *
     * Không xử lý activity.
     */
    if (_deviceLocked) {
        return;
    }

    [self resetTimer];

    /*
     * Phòng trường hợp timer chưa tồn tại.
     */
    if (_timer == nil) {
        [self start];
    }
}


#pragma mark - Device Locked

- (void)deviceDidLock
{
    NSLog(@"[SleepMode] DeviceDidLock");

    _deviceLocked = YES;

    _isEnteringSleep = NO;

    /*
     * Dừng hoàn toàn bộ timer.
     */
    [self stop];
}


#pragma mark - Device Unlocked

- (void)deviceDidUnlock
{
    NSLog(@"[SleepMode] DeviceDidUnlock");

    _deviceLocked = NO;

    _isEnteringSleep = NO;

    /*
     * Unlock = bắt đầu một chu kỳ mới.
     *
     * Không lấy thời gian trước khi khóa
     * để tính tiếp.
     */
    _lastInteraction =
        CFAbsoluteTimeGetCurrent();

    /*
     * Tạo timer mới.
     */
    [self start];
}


#pragma mark - Terminate Applications

- (void)terminateUserApplications
{
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
     * Fallback:
     * lấy allApplications rồi lọc app đang chạy.
     */
    if (![runningApplications
            isKindOfClass:
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
                        [filtered addObject:app];
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


    #pragma mark - FBSSystemService

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


    #pragma mark - Termination Selector

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


    #pragma mark - Exclusions

    NSSet *excludedBundleIDs =
        [NSSet setWithObjects:

            @"com.apple.springboard",

            @"com.apple.Preferences",

            @"com.apple.WebKit.Networking",

            @"com.apple.WebKit.WebContent",

            @"com.apple.WebKit.GPU",

            @"com.apple.UIKit.pasteboardd",

            @"com.apple.Pasteboard",

            nil
        ];


    #pragma mark - Terminate

    for (id app in runningApplications) {

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
         * Không đóng SpringBoard
         * hoặc các thành phần hệ thống.
         */
        if ([excludedBundleIDs
                containsObject:
                    bundleID]) {

            continue;
        }

        /*
         * Không đụng app hệ thống Apple.
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


#pragma mark - Enter Sleep

- (void)enterSleepMode
{
    /*
     * Không sleep lần 2.
     */
    if (_isEnteringSleep) {
        return;
    }

    /*
     * Không sleep nếu máy đã khóa.
     */
    if (_deviceLocked) {
        return;
    }

    _isEnteringSleep = YES;

    NSLog(
        @"[SleepMode] Timeout reached"
    );

    /*
     * Đóng app người dùng.
     */
    [self terminateUserApplications];

    __weak SleepManager *weakSelf =
        self;

    /*
     * Chờ một chút để app terminate
     * hoàn tất trước khi khóa máy.
     */
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

            /*
             * Trong lúc chờ nếu máy đã bị
             * khóa bởi nơi khác thì bỏ qua.
             */
            if (strongSelf->_deviceLocked) {

                strongSelf->_isEnteringSleep =
                    NO;

                return;
            }

            NSLog(
                @"[SleepMode] Locking device"
            );

            [strongSelf lockDevice];

            /*
             * Không tiếp tục đếm trong chu kỳ
             * vừa lock.
             */
            [strongSelf deviceDidLock];
        }
    );
}


#pragma mark - Lock Device

- (void)lockDevice
{
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


    #pragma mark - Fallback

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


#pragma mark - Darwin Touch Callback

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
