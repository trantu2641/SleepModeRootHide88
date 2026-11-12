#import "SleepControlCenter.h"

#import "SleepManager.h"

#pragma mark - Notification

NSString * const
    SleepControlCenterStateChangedNotification =
        @"com.trantu.sleepmode.stateChanged";


#pragma mark - SleepControlCenter

@interface SleepControlCenter ()

@property(nonatomic, strong)
    SleepManager *sleepManager;

@end


@implementation SleepControlCenter


#pragma mark - Singleton

+ (instancetype)sharedInstance
{
    static SleepControlCenter *sharedInstance =
        nil;

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
         * Kết nối với SleepManager hiện tại.
         */
        _sleepManager =
            [SleepManager sharedInstance];

        /*
         * Đồng bộ trạng thái ban đầu.
         */
        _enabled =
            _sleepManager.enabled;

        _timeout =
            _sleepManager.timeout;
    }

    return self;
}


#pragma mark - Enabled

- (BOOL)isEnabled
{
    return _enabled;
}


- (void)setEnabled:(BOOL)enabled
{
    if (_enabled == enabled) {
        return;
    }

    _enabled = enabled;

    /*
     * Đồng bộ sang SleepManager.
     */
    _sleepManager.enabled =
        enabled;

    if (enabled) {

        /*
         * Bật lại engine.
         */
        [_sleepManager resetTimer];

        [_sleepManager start];

    } else {

        /*
         * Tắt engine.
         */
        [_sleepManager stop];
    }

    [self postStateChanged];
}


- (void)enable
{
    self.enabled = YES;
}


- (void)disable
{
    self.enabled = NO;
}


- (void)toggle
{
    self.enabled =
        !self.enabled;
}


#pragma mark - Timeout

- (NSTimeInterval)currentTimeout
{
    return _timeout;
}


- (void)setTimeout:(NSTimeInterval)timeout
{
    /*
     * Không cho timeout âm.
     */
    if (timeout < 0.0) {
        timeout = 0.0;
    }

    /*
     * Không cần thay đổi nếu giống hiện tại.
     */
    if (_timeout == timeout) {
        return;
    }

    _timeout =
        timeout;

    /*
     * Đồng bộ sang SleepManager.
     */
    _sleepManager.timeout =
        timeout;

    /*
     * Đổi timeout thì bắt đầu lại
     * một chu kỳ mới.
     */
    [_sleepManager resetTimer];

    [self postStateChanged];
}


#pragma mark - Reset Timer

- (void)resetTimer
{
    [_sleepManager resetTimer];
}


#pragma mark - State Notification

- (void)postStateChanged
{
    NSDictionary *userInfo =
        @{
            @"enabled":
                @(_enabled),

            @"timeout":
                @(_timeout)
        };

    [[NSNotificationCenter defaultCenter]
        postNotificationName:
            SleepControlCenterStateChangedNotification

        object:
            self

        userInfo:
            userInfo];
}


#pragma mark - Description

- (NSString *)description
{
    return
        [NSString stringWithFormat:
            @"<SleepControlCenter: enabled=%@ timeout=%.1f>",
            _enabled ? @"YES" : @"NO",
            _timeout];
}

@end
