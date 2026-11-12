#import "SleepManager.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/message.h>


#pragma mark - Constants

static NSString * const kSleepTouchNotification =
    @"com.trantu.sleepmode.touch";

static NSString * const kSleepEnabledKey =
    @"SleepModeEnabled";

static NSString * const kSleepTimeoutKey =
    @"SleepModeTimeout";


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

    /*
     * Thời điểm cuối cùng phát hiện tương tác.
     */
    CFAbsoluteTime _lastInteraction;

    /*
     * Tránh gọi khóa màn hình nhiều lần
     * nếu timer vẫn tiếp tục chạy.
     */
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
         * =====================================================
         * TEST CORE
         * =====================================================
         *
         * Hiện tại bật sẵn để test.
         *
         * 60 giây = 1 phút
         *
         * Sau khi core hoạt động ổn định,
         * phần Preferences sẽ thay giá trị này.
         */
        _enabled = YES;

        _timeout = 60.0;

        /*
         * Bắt đầu tính thời gian
         * từ thời điểm khởi tạo manager.
         */
        _lastInteraction =
            CFAbsoluteTimeGetCurrent();

        _isEnteringSleep = NO;


        /*
         * =====================================================
         * ĐĂNG KÝ NHẬN NOTIFICATION TỪ CÁC APP
         * =====================================================
         *
         * Tweak sẽ gửi:
         *
         * com.trantu.sleepmode.touch
         *
         * mỗi khi phát hiện người dùng chạm màn hình.
         *
         * Darwin notification có thể truyền giữa
         * các process.
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


        /*
         * Bắt đầu timer.
         */
        [self start];
    }

    return self;
}


#pragma mark - Start

- (void)start
{
    /*
     * Nếu đang tắt thì không chạy timer.
     */
    if (!self.enabled) {
        return;
    }


    /*
     * Tránh tạo nhiều timer.
     */
    if (_timer != nil) {
        return;
    }


    /*
     * Timer chạy trên main queue của SpringBoard.
     */
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
     * =====================================================
     * TIMER
     * =====================================================
     *
     * Bắt đầu sau 1 giây.
     *
     * Sau đó kiểm tra mỗi 1 giây.
     *
     * leeway 100ms để hệ thống không cần đánh thức CPU
     * chính xác tuyệt đối từng mili-giây.
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


    /*
     * Giữ weak reference để tránh retain cycle.
     */
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
             * Nếu người dùng đã tắt SleepMode
             * thì không làm gì.
             */
            if (!strongSelf.enabled) {
                return;
            }


            /*
             * Nếu timeout không hợp lệ
             * thì bỏ qua.
             */
            if (strongSelf.timeout <= 0.0) {
                return;
            }


            /*
             * Lấy thời gian hiện tại.
             */
            CFAbsoluteTime now =
                CFAbsoluteTimeGetCurrent();


            /*
             * Tính thời gian kể từ lần tương tác cuối.
             */
            CFAbsoluteTime elapsed =
                now - strongSelf->_lastInteraction;


            /*
             * Nếu đã vượt timeout
             * thì vào chế độ ngủ.
             */
            if (elapsed >= strongSelf.timeout) {

                [strongSelf enterSleepMode];
            }
        }
    );


    /*
     * Bắt đầu timer.
     */
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
    /*
     * Ghi nhận thời điểm tương tác mới nhất.
     */
    _lastInteraction =
        CFAbsoluteTimeGetCurrent();


    /*
     * Nếu trước đó đang ở trạng thái
     * chuẩn bị khóa thì hủy trạng thái đó.
     */
    _isEnteringSleep = NO;
}


#pragma mark - User Interaction

- (void)userDidInteract
{
    /*
     * Nếu SleepMode đang tắt
     * thì không cần xử lý.
     */
    if (!self.enabled) {
        return;
    }


    /*
     * Người dùng vừa chạm màn hình.
     *
     * Reset lại bộ đếm.
     */
    [self resetTimer];
}


#pragma mark - Enter Sleep Mode

- (void)enterSleepMode
{
    /*
     * =====================================================
     * CHỐNG GỌI LẶP
     * =====================================================
     *
     * Timer chạy mỗi giây.
     *
     * Nếu khóa màn hình mất một khoảng thời gian,
     * hàm này có thể bị gọi lại.
     *
     * Vì vậy chỉ cho phép một lần xử lý.
     */
    if (_isEnteringSleep) {
        return;
    }


    _isEnteringSleep = YES;


    /*
     * Reset timer trước khi khóa.
     *
     * Nếu việc khóa thất bại,
     * hệ thống sẽ không lập tức gọi lại hàm
     * ở giây tiếp theo.
     */
    [self resetTimer];


    /*
     * =====================================================
     * CÁCH 1
     * SBLockScreenManager
     * =====================================================
     *
     * Đây là private class của SpringBoard.
     */
    Class lockManagerClass =
        NSClassFromString(
            @"SBLockScreenManager"
        );


    if (lockManagerClass != Nil) {

        id manager = nil;


        /*
         * Lấy singleton:
         *
         * +sharedInstance
         */
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


        /*
         * Kiểm tra lockDevice.
         */
        SEL lockDeviceSelector =
            @selector(lockDevice);


        if (manager != nil &&
            [manager
                respondsToSelector:
                    lockDeviceSelector]) {

            /*
             * Gọi:
             *
             * [manager lockDevice]
             */
            ((void (*)(id, SEL))
                objc_msgSend)(
                manager,
                lockDeviceSelector
            );


            /*
             * Hoàn tất.
             */
            _isEnteringSleep = NO;

            return;
        }
    }


    /*
     * =====================================================
     * CÁCH 2
     * UIApplication private selector
     * =====================================================
     *
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

        ((void (*)(id, SEL))
            objc_msgSend)(
            application,
            simulateLockSelector
        );


        _isEnteringSleep = NO;

        return;
    }


    /*
     * Không tìm được API khóa màn hình.
     */
    _isEnteringSleep = NO;
}


#pragma mark - Dealloc

- (void)dealloc
{
    /*
     * Hủy timer.
     */
    [self stop];


    /*
     * Gỡ Darwin notification.
     */
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
    /*
     * Chuyển observer trở lại SleepManager.
     */
    SleepManager *manager =
        (__bridge SleepManager *)observer;


    if (manager == nil) {
        return;
    }


    /*
     * Đảm bảo việc reset timer
     * được thực hiện trên main queue.
     */
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            [manager userDidInteract];
        }
    );
}
