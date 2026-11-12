#import "SleepControlCenter.h"
#import "SleepManager.h"

#import <Foundation/Foundation.h>
#import <math.h>

NSString * const
    SleepControlCenterStateChangedNotification =
        @"com.trantu.sleepmode.stateChanged";

@interface SleepControlCenter ()

@property(nonatomic, strong)
    SleepManager *sleepManager;

@end

@implementation SleepControlCenter

+ (instancetype)sharedInstance
{
    static SleepControlCenter *sharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });

    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];

    if (self) {
        self.sleepManager =
            [SleepManager sharedInstance];
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

    self.sleepManager.enabled = enabled;

    if (enabled) {

        [self.sleepManager resetTimer];
        [self.sleepManager start];

    } else {

        [self.sleepManager stop];

    }

    [self postStateChanged];
}

#pragma mark - Enable / Disable

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
    self.enabled = !self.enabled;
}

#pragma mark - Timeout

- (NSTimeInterval)currentTimeout
{
    return self.sleepManager.timeout;
}

- (void)setTimeout:(NSTimeInterval)timeout
{
    if (timeout < 0.0) {
        timeout = 0.0;
    }

    NSTimeInterval currentTimeout =
        self.sleepManager.timeout;

    if (fabs(currentTimeout - timeout) < 0.001) {
        return;
    }

    self.sleepManager.timeout = timeout;

    /*
     * Đổi thời gian sẽ tính lại bộ đếm
     * từ thời điểm hiện tại.
     */
    [self.sleepManager resetTimer];

    [self postStateChanged];
}

#pragma mark - Timer

- (void)resetTimer
{
    [self.sleepManager resetTimer];
}

#pragma mark - Notification

- (void)postStateChanged
{
    NSDictionary *userInfo = @{
        @"enabled": @(self.enabled),
        @"timeout": @(self.currentTimeout)
    };

    [[NSNotificationCenter defaultCenter]
        postNotificationName:
            SleepControlCenterStateChangedNotification
        object:self
        userInfo:userInfo];
}

#pragma mark - Description

- (NSString *)description
{
    return [NSString stringWithFormat:
        @"<SleepControlCenter: enabled=%@ timeout=%.1f>",
        self.enabled ? @"YES" : @"NO",
        self.currentTimeout];
}

@end
