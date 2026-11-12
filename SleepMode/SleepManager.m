#import "SleepManager.h"

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/message.h>
#import <objc/runtime.h>


#pragma mark - Private SpringBoard interfaces

@interface SBLockScreenManager : NSObject

+ (instancetype)sharedInstance;

- (void)lockDevice;

- (void)lockFromSource:(int)source;

@end


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

    dispatch_once(
        &onceToken,
        ^{
            instance =
                [[self alloc] init];
        }
    );

    return instance;
}


#pragma mark - Init

- (instancetype)init
{
    self = [super init];

    if (self) {

        /*
         * Mặc định:
         *
         * - bật
         * - timeout 15 giây
         * - thiết bị đang unlock
         */
        _enabled = YES;

        _timeout = 15.0;

        _deviceLocked = NO;

        _isEnteringSleep = NO;

        _started = NO;

        _lastInteraction =
            CFAbsoluteTimeGetCurrent();
    }

    return self;
}


#pragma mark - Enabled

- (void)setEnabled:(BOOL)enabled
{
    @synchronized (self) {

        if (_enabled == enabled) {
            return;
        }

        _enabled = enabled;

        if (!_enabled) {

            [self stop];

            _isEnteringSleep = NO;

            return;
        }

        /*
         * Bật lại từ đầu.
         */
        [self resetTimer];

        if (!_deviceLocked) {
            [self start];
        }
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
    @synchronized (self) {

        /*
         * Giới hạn để tránh giá trị lỗi.
         */
        if (timeout < 1.0) {
            timeout = 1.0;
        }

        if (timeout > 86400.0) {
            timeout = 86400.0;
        }

        _timeout = timeout;

        /*
         * Đổi timeout phải bắt đầu lại
         * chu kỳ đếm.
         */
        _lastInteraction =
            CFAbsoluteTimeGetCurrent();

        _isEnteringSleep = NO;

        if (_enabled &&
            !_deviceLocked) {

            [self start];
        }
    }
}


- (NSTimeInterval)timeout
{
    @synchronized (self) {
        return _timeout;
    }
}


#pragma mark - Start timer

- (void)start
{
    @synchronized (self) {

        if (!_enabled) {
            return;
        }

        if (_deviceLocked) {
            return;
        }

        /*
         * Nếu timer đã chạy thì không tạo
         * thêm timer mới.
         */
        if (_timer != nil) {

            if (!_started) {
                _started = YES;
            }

            return;
        }

        _started = YES;

        _lastInteraction =
            CFAbsoluteTimeGetCurrent();

        /*
         * Timer chạy trên background queue.
         *
         * Không chạy logic timer trên main thread.
         */
        dispatch_queue_t queue =
            dispatch_get_global_queue(
                QOS_CLASS_UTILITY,
                0
            );

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

        /*
         * Kiểm tra mỗi 1 giây.
         *
         * Không kiểm tra mỗi touch.
         */
        dispatch_source_set_timer(
            timer,
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
            timer,
            ^{
                SleepManager *strongSelf =
                    weakSelf;

                if (!strongSelf) {
                    return;
                }

                [strongSelf checkTimeout];
            }
        );

        dispatch_source_set_cancel_handler(
            timer,
            ^{
                /*
                 * Không làm việc nặng ở đây.
                 */
            }
        );

        dispatch_resume(timer);
    }
}


#pragma mark - Stop timer

- (void)stop
{
    @synchronized (self) {

        dispatch_source_t timer =
            _timer;

        _timer = nil;

        _started = NO;

        if (timer != nil) {

            dispatch_source_cancel(timer);
        }
    }
}


#pragma mark - Reset timer

- (void)resetTimer
{
    @synchronized (self) {

        if (!_enabled) {
            return;
        }

        if (_deviceLocked) {
            return;
        }

        _lastInteraction =
            CFAbsoluteTimeGetCurrent();

        _isEnteringSleep = NO;
    }
}


#pragma mark - User interaction

- (void)userDidInteract
{
    /*
     * Đây là đường chạy rất thường xuyên,
     * nên tuyệt đối không NSLog ở đây.
     */

    if (!_enabled) {
        return;
    }

    if (_deviceLocked) {
        return;
    }

    /*
     * Chỉ ghi nhận thời điểm.
     *
     * Không:
     *
     * - enumerate app
     * - terminate app
     * - lock máy
     * - tạo timer mới
     * - dispatch nhiều block
     */
    [self resetTimer];

    /*
     * Nếu vì lý do nào đó timer chưa tồn tại
     * thì khởi động lại.
     */
    if (_timer == nil) {
        [self start];
    }
}


#pragma mark - Check timeout

- (void)checkTimeout
{
    /*
     * Tất cả phần kiểm tra này chạy ngoài main thread.
     */
    BOOL shouldSleep = NO;

    NSTimeInterval timeout = 0.0;

    CFAbsoluteTime lastInteraction = 0.0;

    @synchronized (self) {

        if (!_enabled) {
            return;
        }

        if (_deviceLocked) {
            return;
        }

        if (_isEnteringSleep) {
            return;
        }

        timeout = _timeout;

        lastInteraction =
            _lastInteraction;

        CFAbsoluteTime now =
            CFAbsoluteTimeGetCurrent();

        CFTimeInterval elapsed =
            now - lastInteraction;

        if (elapsed >= timeout) {

            _isEnteringSleep = YES;

            shouldSleep = YES;
        }
    }

    if (!shouldSleep) {
        return;
    }

    /*
     * Timeout đã hết.
     *
     * Không thực hiện terminate app trực tiếp
     * trong phần lock timer.
     */
    [self enterSleepMode];
}


#pragma mark - Terminate user applications

- (void)terminateUserApplications
{
    /*
     * Phần này chạy trên background queue.
     *
     * Tuy nhiên thao tác với SpringBoard
     * cần được đưa về main thread.
     */
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            Class workspaceClass =
                NSClassFromString(
                    @"SBMainWorkspace"
                );

            if (!workspaceClass) {
                return;
            }

            SEL sharedSelector =
                NSSelectorFromString(
                    @"sharedInstance"
                );

            if (![workspaceClass
                    respondsToSelector:
                        sharedSelector]) {

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


            /*
             * Cách 1:
             * terminateApplicationWithBundleIdentifier:
             * 
             * Nếu SpringBoard cung cấp selector này.
             */
            SEL terminateSelector =
                NSSelectorFromString(
                    @"terminateApplicationWithBundleIdentifier:"
                );

            /*
             * Không tự enumerate toàn bộ app ở đây.
             *
             * Việc enumerate toàn bộ workspace thường
             * là một trong những nguyên nhân gây lag.
             */
            if ([workspace
                    respondsToSelector:
                        terminateSelector]) {

                NSArray *runningApplications = nil;

                SEL appsSelector =
                    NSSelectorFromString(
                        @"runningApplications"
                    );

                if ([workspace
                        respondsToSelector:
                            appsSelector]) {

                    runningApplications =
                        ((id (*)(id, SEL))objc_msgSend)(
                            workspace,
                            appsSelector
                        );
                }

                if ([runningApplications
                        isKindOfClass:
                            [NSArray class]]) {

                    for (id application
                         in runningApplications) {

                        NSString *bundleIdentifier = nil;

                        SEL bundleIDSelector =
                            NSSelectorFromString(
                                @"bundleIdentifier"
                            );

                        if ([application
                                respondsToSelector:
                                    bundleIDSelector]) {

                            bundleIdentifier =
                                ((id (*)(id, SEL))objc_msgSend)(
                                    application,
                                    bundleIDSelector
                                );
                        }

                        if (bundleIdentifier.length == 0) {
                            continue;
                        }


                        /*
                         * Không terminate Apple/System apps.
                         */
                        if ([bundleIdentifier
                                hasPrefix:@"com.apple."]) {

                            continue;
                        }


                        /*
                         * Không terminate SpringBoard.
                         */
                        if ([bundleIdentifier
                                isEqualToString:
                                    @"com.apple.springboard"]) {

                            continue;
                        }


                        /*
                         * Chỉ terminate app người dùng.
                         */
                        ((void (*)(id, SEL, id))objc_msgSend)(
                            workspace,
                            terminateSelector,
                            bundleIdentifier
                        );
                    }
                }
            }
        }
    );
}


#pragma mark - Enter sleep mode

- (void)enterSleepMode
{
    /*
     * Chỉ cho phép một lần chạy.
     */
    @synchronized (self) {

        if (!_enabled) {

            _isEnteringSleep = NO;

            return;
        }

        if (_deviceLocked) {

            _isEnteringSleep = NO;

            return;
        }
    }


    /*
     * Dừng timer ngay trước khi thực hiện
     * terminate/lock.
     */
    [self stop];


    /*
     * Đóng app người dùng.
     */
    [self terminateUserApplications];


    /*
     * Đợi một khoảng rất ngắn để
     * SpringBoard xử lý terminate.
     *
     * Không dùng sleep() vì sleep sẽ block
     * thread đang chạy.
     */
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            80 * NSEC_PER_MSEC
        ),
        dispatch_get_main_queue(),
        ^{
            [self performDeviceLock];
        }
    );
}


#pragma mark - Lock device

- (void)performDeviceLock
{
    @synchronized (self) {

        if (!_enabled) {

            _isEnteringSleep = NO;

            return;
        }

        if (_deviceLocked) {

            _isEnteringSleep = NO;

            return;
        }

        _deviceLocked = YES;
    }


    Class lockManagerClass =
        NSClassFromString(
            @"SBLockScreenManager"
        );

    if (!lockManagerClass) {

        @synchronized (self) {
            _deviceLocked = NO;
            _isEnteringSleep = NO;
        }

        return;
    }


    SEL sharedSelector =
        NSSelectorFromString(
            @"sharedInstance"
        );

    if (![lockManagerClass
            respondsToSelector:
                sharedSelector]) {

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
     * Phương pháp chính.
     */
    SEL lockSelector =
        NSSelectorFromString(
            @"lockDevice"
        );

    if ([manager
            respondsToSelector:
                lockSelector]) {

        ((void (*)(id, SEL))objc_msgSend)(
            manager,
            lockSelector
        );

        return;
    }


    /*
     * Fallback cho một số build SpringBoard.
     */
    SEL sourceSelector =
        NSSelectorFromString(
            @"lockFromSource:"
        );

    if ([manager
            respondsToSelector:
                sourceSelector]) {

        ((void (*)(id, SEL, int))objc_msgSend)(
            manager,
            sourceSelector,
            1
        );

        return;
    }


    /*
     * Không tìm thấy API lock.
     *
     * Cho phép thử lại ở chu kỳ sau.
     */
    @synchronized (self) {

        _deviceLocked = NO;

        _isEnteringSleep = NO;
    }
}


#pragma mark - Device locked

- (void)deviceDidLock
{
    @synchronized (self) {

        _deviceLocked = YES;

        _isEnteringSleep = NO;

        /*
         * Tuyệt đối không giữ timer khi
         * thiết bị đang khóa.
         */
        dispatch_source_t timer =
            _timer;

        _timer = nil;

        _started = NO;

        if (timer != nil) {

            dispatch_source_cancel(timer);
        }
    }
}


#pragma mark - Device unlocked

- (void)deviceDidUnlock
{
    @synchronized (self) {

        _deviceLocked = NO;

        _isEnteringSleep = NO;

        /*
         * Unlock = bắt đầu một chu kỳ hoàn toàn mới.
         */
        _lastInteraction =
            CFAbsoluteTimeGetCurrent();
    }


    if (_enabled) {

        [self start];
    }
}


#pragma mark - Dealloc

- (void)dealloc
{
    [self stop];
}

@end
