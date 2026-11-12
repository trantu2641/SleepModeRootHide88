#import "SleepControlCenter.h"

#import "SleepManager.h"


NSString * const
    SleepControlCenterStateChangedNotification =
        @"com.trantu.sleepmode.stateChanged";


@interface SleepControlCenter ()

@property(nonatomic, strong)
    SleepManager *sleepManager;

@end


@implementation SleepControlCenter


#pragma mark - Singleton

+ (instancetype)sharedInstance
{
    static SleepControlCenter *sharedInstance = nil;

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

        self.sleepManager =
            [SleepManager sharedInstance];

        /*
         * Đồng bộ trạng thái ban đầu
         * từ SleepManager.
         */
        self.enabled =
            self.sleepManager.enabled;

        self.timeout =
            self.sleepManager.timeout;
    }

    return self;
}


#pragma mark - Enabled

- (BOOL)isEnabled
{
    return self.sleepManager.enabled;
}


- (void)setEnabled:(BOOL)enabled
{
    BOOL currentEnabled =
        self.sleepManager.enabled;

    if (currentEnabled == enabled) {
        return;
    }


    /*
     * Đồng bộ trạng thái xuống SleepManager.
     */
    self.sleepManager.enabled =
        enabled;


    if (enabled) {

        /*
         * Bật SleepMode:
         *
         * reset timer
         * rồi bắt đầu đếm.
         */
        [self.sleepManager resetTimer];

        [self.sleepManager start];

    } else {

        /*
         * Tắt SleepMode:
         *
         * dừng timer hoàn toàn.
         */
        [self.sleepManager stop];
    }


    [self postStateChanged];
}


#pragma mark - Enable / Disable / Toggle

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
    return self.sleepManager.timeout;
}


- (void)setTimeout:(NSTimeInterval)timeout
{
    /*
     * Không cho timeout âm.
     */
    if (timeout < 0.0) {
        timeout = 0.0;
    }


    NSTimeInterval currentTimeout =
        self.sleepManager.timeout;


    if (fabs(currentTimeout - timeout) < 0.001) {
        return;
    }


    /*
     * Đồng bộ timeout xuống SleepManager.
     */
    self.sleepManager.timeout =
        timeout;


    /*
     * Đổi timeout thì reset bộ đếm
     * về 0 giây.
     */
    [self.sleepManager resetTimer];


    [self postStateChanged];
}


#pragma mark - Reset

- (void)resetTimer
{
    [self.sleepManager resetTimer];
}


#pragma mark - Notification

- (void)postStateChanged
{
    NSDictionary *userInfo =
        @{
            @"enabled":
                @(self.enabled),

            @"timeout":
                @(self.currentTimeout)
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
            self.enabled ? @"YES" : @"NO",
            self.currentTimeout];
}


@end
