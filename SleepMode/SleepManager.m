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
     *     Màn hình/device đang khóa.
     *
     * Khi YES, timer sẽ bị stop hoàn toàn.
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
         * TEST:
         * 60 giây
         *
         * Sau này có thể đổi thành:
         *
         * 60.0
         * 300.0
         * 900.0
         * 1800.0
         * 3600.0
         * 7200.0
         */
        _timeout = 15.0;

        _lastInteraction =
            CFAbsoluteTimeGetCurrent();

        _isEnteringSleep = NO;

        _deviceLocked = NO;

        /*
         * Darwin notification cho activity.
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
     * Không chạy khi màn hình đã khóa.
     */
    if (_deviceLocked) {
        NSLog(
            @"[SleepMode] Timer start ignored because device is locked"
        );

        return;
    }

    /*
     * Đã có timer rồi thì không tạo timer thứ hai.
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
        NSLog(
            @"[SleepMode] Failed to create timer"
        );

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

            /*
             * Cực kỳ quan trọng:
             *
             * Nếu máy đã khóa thì không được
             * xử lý timeout nữa.
             */
            if (strongSelf->_deviceLocked) {
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
        @"[SleepMode] Timer started"
    );
}

#pragma mark - Stop Timer

- (void)stop
{
    if (_timer != nil) {

        NSLog(
            @"[SleepMode] Timer stopped"
        );

        dispatch_source_cancel(_timer);

        _timer = nil;
    }
}

#pragma mark - Reset Timer

- (void)resetTimer
{
    /*
     * Nếu máy đang khóa thì không reset.
     */
    if (_deviceLocked) {
        return;
    }

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
     * Không coi activity khi máy đang khóa
     * là interaction.
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

#pragma mark - Device Lock

- (void)deviceDidLock
{
    /*
     * Tránh gọi nhiều lần.
     */
    if (_deviceLocked) {
        return;
    }

    NSLog(
        @"[SleepMode] Device locked -> stopping SleepMode timer"
    );

    _deviceLocked = YES;

    _isEnteringSleep = NO;

    /*
     * Dừng timer hoàn toàn.
     */
    [self stop];
}

#pragma mark - Device Unlock

- (void)deviceDidUnlock
{
    /*
     * Nếu chưa ở trạng thái locked
     * thì không cần làm gì.
     */
    if (!_deviceLocked) {
        return;
    }

    NSLog(
        @"[SleepMode] Device unlocked -> restarting SleepMode timer"
    );

    _deviceLocked = NO;

    _isEnteringSleep = NO;

    /*
     * Bắt đầu lại từ thời điểm unlock.
     */
    _lastInteraction =
        CFAbsoluteTimeGetCurrent();

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
     * lấy toàn bộ app rồi lọc app đang chạy.
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

    /*
     * FBSSystemService
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
     * Không bao giờ terminate SpringBoard
     * hoặc các process hệ thống quan trọng.
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
         * Exclude system applications.
         */
        if ([excludedBundleIDs
                containsObject:
                    bundleID]) {

            continue;
        }

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
     * Không làm gì nếu máy đã khóa.
     */
    if (_deviceLocked) {
        return;
    }

    _isEnteringSleep = YES;

    NSLog(
        @"[SleepMode] Timeout reached"
    );

    /*
     * 1. Đóng app người dùng.
     */
    [self terminateUserApplications];

    __weak SleepManager *weakSelf =
        self;

    /*
     * Cho SpringBoard khoảng 300ms
     * để xử lý việc terminate app.
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
             * Nếu trong 300ms này máy đã bị khóa
             * bởi nơi khác thì không lock lại.
             */
            if (strongSelf->_deviceLocked) {
                strongSelf->_isEnteringSleep = NO;

                return;
            }

            /*
             * Khóa máy.
             */
            [strongSelf lockDevice];

            /*
             * Ngay sau khi ra lệnh lock,
             * dừng SleepMode timer.
             *
             * Không đợi timer tự chạy tiếp.
             */
            [strongSelf deviceDidLock];

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
     * Fallback.
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
