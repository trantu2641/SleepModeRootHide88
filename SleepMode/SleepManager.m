#import "SleepManager.h"

#import <UIKit/UIKit.h>
#import <objc/message.h>

static NSString * const kSleepTouchNotification =
    @"com.trantu.sleepmode.touch";

static NSString * const kSleepEnabledKey =
    @"SleepModeEnabled";

static NSString * const kSleepTimeoutKey =
    @"SleepModeTimeout";

static SleepManager *gManager = nil;

@interface SleepManager ()
{
    dispatch_source_t _timer;
    CFAbsoluteTime _lastInteraction;
}
@end

@implementation SleepManager

+ (instancetype)sharedInstance
{
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        gManager = [[self alloc] init];
    });

    return gManager;
}

- (instancetype)init
{
    self = [super init];

    if (self) {

        _enabled = YES;

        /*
         * Bản test đầu tiên:
         * 60 giây.
         */
        _timeout = 60.0;

        _lastInteraction =
            CFAbsoluteTimeGetCurrent();

        [self start];
    }

    return self;
}

#pragma mark - Start

- (void)start
{
    if (!_enabled) {
        return;
    }

    [self createTimer];
}

#pragma mark - Stop

- (void)stop
{
    if (_timer) {

        dispatch_source_cancel(_timer);

        _timer = nil;
    }
}

#pragma mark - Timer

- (void)createTimer
{
    if (_timer) {
        return;
    }

    _timer =
        dispatch_source_create(
            DISPATCH_SOURCE_TYPE_TIMER,
            0,
            0,
            dispatch_get_main_queue()
        );

    if (!_timer) {
        return;
    }

    dispatch_source_set_timer(
        _timer,

        dispatch_time(
            DISPATCH_TIME_NOW,
            NSEC_PER_SEC
        ),

        NSEC_PER_SEC,

        100 * NSEC_PER_MSEC
    );

    __weak typeof(self) weakSelf =
        self;

    dispatch_source_set_event_handler(
        _timer,
        ^{
            __strong typeof(weakSelf) self =
                weakSelf;

            if (!self) {
                return;
            }

            if (!self.enabled) {
                return;
            }

            CFAbsoluteTime now =
                CFAbsoluteTimeGetCurrent();

            CFAbsoluteTime elapsed =
                now - self->_lastInteraction;

            if (elapsed >= self.timeout) {

                [self enterSleepMode];
            }
        }
    );

    dispatch_resume(_timer);
}

#pragma mark - Touch

- (void)resetTimer
{
    _lastInteraction =
        CFAbsoluteTimeGetCurrent();
}

- (void)userDidInteract
{
    if (!_enabled) {
        return;
    }

    [self resetTimer];
}

#pragma mark - Sleep

- (void)enterSleepMode
{
    static BOOL locking = NO;

    if (locking) {
        return;
    }

    locking = YES;

    /*
     * Reset ngay để tránh timer
     * gọi lại liên tục.
     */
    [self resetTimer];

    Class lockManager =
        NSClassFromString(
            @"SBLockScreenManager"
        );

    if (lockManager) {

        id manager =
            [lockManager
                performSelector:
                    @selector(sharedInstance)];

        SEL lockSelector =
            @selector(lockDevice);

        if ([manager
                respondsToSelector:
                    lockSelector]) {

            ((void (*)(id, SEL))
                objc_msgSend)(
                    manager,
                    lockSelector
            );

            locking = NO;

            return;
        }
    }

    /*
     * Fallback.
     */
    UIApplication *app =
        [UIApplication sharedApplication];

    SEL selector =
        @selector(
            _simulateLockButtonPress
        );

    if ([app respondsToSelector:
            selector]) {

        ((void (*)(id, SEL))
            objc_msgSend)(
                app,
                selector
        );
    }

    locking = NO;
}

@end
