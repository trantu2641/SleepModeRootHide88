#import "SleepControlCenter.h"
#import "SleepManager.h"

NSString * const SleepControlCenterStateChangedNotification =
    @"com.trantu.sleepmode.stateChanged";

static NSString * const kSleepModeEnabledKey =
    @"SleepModeEnabled";

static NSString * const kSleepModeTimeoutKey =
    @"SleepModeTimeout";

@implementation SleepControlCenter

+ (instancetype)sharedInstance
{
    static SleepControlCenter *instance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });

    return instance;
}

- (instancetype)init
{
    self = [super init];

    if (self) {

        NSUserDefaults *defaults =
            [NSUserDefaults standardUserDefaults];

        if ([defaults objectForKey:kSleepModeEnabledKey] == nil) {
            [defaults setBool:YES
                        forKey:kSleepModeEnabledKey];
        }

        if ([defaults objectForKey:kSleepModeTimeoutKey] == nil) {
            [defaults setDouble:15.0
                         forKey:kSleepModeTimeoutKey];
        }
    }

    return self;
}

#pragma mark - Enabled

- (BOOL)isEnabled
{
    return [SleepManager sharedInstance].enabled;
}

- (void)setEnabled:(BOOL)enabled
{
    [[SleepManager sharedInstance]
        setEnabled:enabled];

    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    [defaults setBool:enabled
               forKey:kSleepModeEnabledKey];

    [defaults synchronize];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:
            SleepControlCenterStateChangedNotification
        object:nil];
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
    self.enabled = !self.enabled;
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

    [[SleepManager sharedInstance]
        setTimeout:timeout];

    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    [defaults setDouble:timeout
                 forKey:kSleepModeTimeoutKey];

    [defaults synchronize];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:
            SleepControlCenterStateChangedNotification
        object:nil];
}

- (NSTimeInterval)currentTimeout
{
    return [SleepManager sharedInstance].timeout;
}

#pragma mark - Reset

- (void)resetTimer
{
    [[SleepManager sharedInstance]
        resetTimer];
}

@end
