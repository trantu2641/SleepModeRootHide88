#import "SleepManager.h"

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#pragma mark - SleepManager

@interface SleepManager ()
{
    dispatch_source_t _timer;

    CFAbsoluteTime _lastInteraction;

    BOOL _deviceLocked;
    BOOL _isEnteringSleep;
    BOOL _started;
}

@end

@implementation SleepManager

#pragma mark - Singleton

+ (instancetype)sharedInstance
{
    static SleepManager *instance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });

    return instance;
}

#pragma mark - Init

- (instancetype)init
{
    self = [super init];

    if (self) {
        _enabled = YES;
        _timeout = 15.0;

        _deviceLocked = NO;
        _isEnteringSleep = NO;
        _started = NO;

        _lastInteraction = CFAbsoluteTimeGetCurrent();
    }

    return self;
}

#pragma mark - Enabled

- (void)setEnabled:(BOOL)enabled
{
    BOOL shouldStart = NO;

    @synchronized (self) {

        if (_enabled == enabled) {
            return;
        }

        _enabled = enabled;

        if (!_enabled) {
            _isEnteringSleep = NO;
        } else {
            _lastInteraction = CFAbsoluteTimeGetCurrent();

            if (!_deviceLocked) {
                shouldStart = YES;
            }
        }
    }

    if (!enabled) {
        [self stop];
    } else if (shouldStart) {
        [self start];
    }
}

- (BOOL)enabled
{
    @synchronized (self) {
        return _enabled;
    }
}

#pragma mark - Timeout

- (void)setTimeout:(NSTimeInterval)timeout
{
    if (timeout < 1.0) {
        timeout = 1.0;
    }

    if (timeout > 86400.0) {
        timeout = 86400.0;
    }

    BOOL shouldStart = NO;

    @synchronized (self) {

        _timeout = timeout;

        _lastInteraction = CFAbsoluteTimeGetCurrent();
        _isEnteringSleep = NO;

        if (_enabled && !_deviceLocked) {
            shouldStart = YES;
        }
    }

    if (shouldStart) {
        [self start];
    }
}

- (NSTimeInterval)timeout
{
    @synchronized (self) {
        return _timeout;
    }
}

#pragma mark - Start

- (void)start
{
    @synchronized (self) {

        if (!_enabled || _deviceLocked) {
            return;
        }

        /*
         * Nếu timer đã tồn tại thì không tạo timer mới.
         */
        if (_timer != nil) {
            _started = YES;
            return;
        }

        _started = YES;

        /*
         * Không reset _lastInteraction ở đây.
         *
         * Điều này rất quan trọng:
         * start chỉ tạo timer,
         * không làm mất thời gian đã tính.
         */
        dispatch_queue_t queue =
            dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);

        dispatch_source_t timer =
            dispatch_source_create(
                DISPATCH_SOURCE_TYPE_TIMER,
                0,
                0,
                queue
            );

        if (!timer) {
            _started = NO;
            return;
        }

        _timer = timer;

        dispatch_source_set_timer(
            timer,
            dispatch_time(
                DISPATCH_TIME_NOW,
                NSEC_PER_SEC
            ),
            NSEC_PER_SEC,
            100 * NSEC_PER_MSEC
        );

        __weak SleepManager *weakSelf = self;

        dispatch_source_set_event_handler(timer, ^{
            SleepManager *strongSelf = weakSelf;

            if (!strongSelf) {
                return;
            }

            [strongSelf checkTimeout];
        });

        dispatch_resume(timer);
    }
}

#pragma mark - Stop

- (void)stop
{
    dispatch_source_t timer = nil;

    @synchronized (self) {

        timer = _timer;

        _timer = nil;
        _started = NO;
    }

    /*
     * Cancel ngoài @synchronized.
     *
     * Tránh giữ lock trong lúc GCD xử lý cancel.
     */
    if (timer != nil) {
        dispatch_source_cancel(timer);
    }
}

#pragma mark - Reset

- (void)resetTimer
{
    @synchronized (self) {

        if (!_enabled || _deviceLocked) {
            return;
        }

        _lastInteraction =
            CFAbsoluteTimeGetCurrent();

        _isEnteringSleep = NO;
    }
}

#pragma mark - User Interaction

- (void)userDidInteract
{
    /*
     * Đây là đường chạy cực kỳ thường xuyên.
     *
     * Không NSLog.
     * Không tạo timer.
     * Không enumerate app.
     * Không dispatch block.
     */

    @synchronized (self) {

        if (!_enabled || _deviceLocked) {
            return;
        }

        /*
         * Chỉ cập nhật timestamp.
         */
        _lastInteraction =
            CFAbsoluteTimeGetCurrent();

        /*
         * Nếu đang trong quá trình sleep
         * thì touch hủy trạng thái đó.
         */
        _isEnteringSleep = NO;
    }

    /*
     * Chỉ trường hợp bất thường timer biến mất
     * mới tạo lại.
     */
    BOOL needStart = NO;

    @synchronized (self) {
        if (_enabled &&
            !_deviceLocked &&
            _timer == nil) {

            needStart = YES;
        }
    }

    if (needStart) {
        [self start];
    }
}

#pragma mark - Check Timeout

- (void)checkTimeout
{
    BOOL shouldSleep = NO;

    @synchronized (self) {

        if (!_enabled ||
            _deviceLocked ||
            _isEnteringSleep) {

            return;
        }

        CFAbsoluteTime now =
            CFAbsoluteTimeGetCurrent();

        CFTimeInterval elapsed =
            now - _lastInteraction;

        if (elapsed >= _timeout) {
            _isEnteringSleep = YES;
            shouldSleep = YES;
        }
    }

    if (!shouldSleep) {
        return;
    }

    [self enterSleepMode];
}

#pragma mark - Terminate User Applications

- (void)terminateUserApplications
{
    /*
     * SpringBoard API phải chạy main thread.
     *
     * Quan trọng:
     * phần này chỉ chạy khi timeout đã hết,
     * KHÔNG chạy trong userDidInteract.
     */
    dispatch_async(dispatch_get_main_queue(), ^{

        Class workspaceClass =
            NSClassFromString(@"SBMainWorkspace");

        if (!workspaceClass) {
            return;
        }

        SEL sharedSelector =
            NSSelectorFromString(@"sharedInstance");

        if (![workspaceClass respondsToSelector:sharedSelector]) {
            return;
        }

        id workspace =
            ((id (*)(id, SEL))objc_msgSend)(
                workspaceClass,
                sharedSelector
            );

        if (!workspace) {
            return;
        }

        SEL runningAppsSelector =
            NSSelectorFromString(@"runningApplications");

        if (![workspace respondsToSelector:runningAppsSelector]) {
            return;
        }

        NSArray *runningApplications =
            ((id (*)(id, SEL))objc_msgSend)(
                workspace,
                runningAppsSelector
            );

        if (![runningApplications isKindOfClass:[NSArray class]]) {
            return;
        }

        SEL terminateSelector =
            NSSelectorFromString(
                @"terminateApplicationWithBundleIdentifier:"
            );

        if (![workspace respondsToSelector:terminateSelector]) {
            return;
        }

        for (id application in runningApplications) {

            SEL bundleIDSelector =
                NSSelectorFromString(@"bundleIdentifier");

            if (![application respondsToSelector:bundleIDSelector]) {
                continue;
            }

            NSString *bundleIdentifier =
                ((id (*)(id, SEL))objc_msgSend)(
                    application,
                    bundleIDSelector
                );

            if (bundleIdentifier.length == 0) {
                continue;
            }

            /*
             * Không đụng app hệ thống.
             */
            if ([bundleIdentifier hasPrefix:@"com.apple."]) {
                continue;
            }

            /*
             * Không terminate SpringBoard.
             */
            if ([bundleIdentifier
                    isEqualToString:@"com.apple.springboard"]) {

                continue;
            }

            /*
             * Terminate app người dùng.
             */
            ((void (*)(id, SEL, id))objc_msgSend)(
                workspace,
                terminateSelector,
                bundleIdentifier
            );
        }
    });
}

#pragma mark - Enter Sleep

- (void)enterSleepMode
{
    @synchronized (self) {

        if (!_enabled || _deviceLocked) {
            _isEnteringSleep = NO;
            return;
        }
    }

    /*
     * Dừng timer trước.
     */
    [self stop];

    /*
     * Đóng app người dùng.
     */
    [self terminateUserApplications];

    /*
     * Cho SpringBoard một khoảng cực ngắn
     * để xử lý terminate.
     */
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            50 * NSEC_PER_MSEC
        ),
        dispatch_get_main_queue(),
        ^{
            [self performDeviceLock];
        }
    );
}

#pragma mark - Lock Device

- (void)performDeviceLock
{
    @synchronized (self) {

        if (!_enabled || _deviceLocked) {
            _isEnteringSleep = NO;
            return;
        }

        _deviceLocked = YES;
    }

    Class lockManagerClass =
        NSClassFromString(@"SBLockScreenManager");

    if (!lockManagerClass) {

        @synchronized (self) {
            _deviceLocked = NO;
            _isEnteringSleep = NO;
        }

        return;
    }

    SEL sharedSelector =
        NSSelectorFromString(@"sharedInstance");

    if (![lockManagerClass respondsToSelector:sharedSelector]) {

        @synchronized (self) {
            _deviceLocked = NO;
            _isEnteringSleep = NO;
        }

        return;
    }

    id manager =
        ((id (*)(id, SEL))objc_msgSend)(
            lockManagerClass,
            sharedSelector
        );

    if (!manager) {

        @synchronized (self) {
            _deviceLocked = NO;
            _isEnteringSleep = NO;
        }

        return;
    }

    /*
     * API chính trên các build SpringBoard
     * phù hợp.
     */
    SEL lockSelector =
        NSSelectorFromString(@"lockDevice");

    if ([manager respondsToSelector:lockSelector]) {

        ((void (*)(id, SEL))objc_msgSend)(
            manager,
            lockSelector
        );

        return;
    }

    /*
     * Fallback.
     */
    SEL sourceSelector =
        NSSelectorFromString(@"lockFromSource:");

    if ([manager respondsToSelector:sourceSelector]) {

        ((void (*)(id, SEL, int))objc_msgSend)(
            manager,
            sourceSelector,
            1
        );

        return;
    }

    /*
     * Không có API lock.
     */
    @synchronized (self) {
        _deviceLocked = NO;
        _isEnteringSleep = NO;
    }
}

#pragma mark - Device Locked

- (void)deviceDidLock
{
    dispatch_source_t timer = nil;

    @synchronized (self) {

        _deviceLocked = YES;
        _isEnteringSleep = NO;

        timer = _timer;

        _timer = nil;
        _started = NO;
    }

    /*
     * Hủy timer ngoài lock.
     */
    if (timer != nil) {
        dispatch_source_cancel(timer);
    }
}

#pragma mark - Device Unlocked

- (void)deviceDidUnlock
{
    BOOL shouldStart = NO;

    @synchronized (self) {

        _deviceLocked = NO;
        _isEnteringSleep = NO;

        /*
         * Unlock = bắt đầu chu kỳ mới.
         */
        _lastInteraction =
            CFAbsoluteTimeGetCurrent();

        if (_enabled) {
            shouldStart = YES;
        }
    }

    if (shouldStart) {
        [self start];
    }
}

#pragma mark - Dealloc

- (void)dealloc
{
    [self stop];
}

@end
