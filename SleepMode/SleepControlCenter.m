#import "SleepControlCenter.h"
#import "SleepManager.h"

NSString * const SleepModeCommandNotification =
    @"com.trantu.sleepmode.command";

NSString * const SleepModeStateChangedNotification =
    @"com.trantu.sleepmode.stateChanged";

NSString * const SleepModeEnabledKey =
    @"SleepModeEnabled";

NSString * const SleepModeTimeoutKey =
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

        if ([defaults objectForKey:SleepModeEnabledKey] == nil) {
            [defaults setBool:NO
                       forKey:SleepModeEnabledKey];
        }

        if ([defaults objectForKey:SleepModeTimeoutKey] == nil) {
            [defaults setDouble:15.0
                         forKey:SleepModeTimeoutKey];
        }
    }

    return self;
}

#pragma mark - Enabled

- (BOOL)isEnabled
{
    return [[NSUserDefaults standardUserDefaults]
                boolForKey:SleepModeEnabledKey];
}

- (void)setEnabled:(BOOL)enabled
{
    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    [defaults setBool:enabled
               forKey:SleepModeEnabledKey];

    [defaults synchronize];

    NSDictionary *info = @{
        @"enabled": @(enabled)
    };

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SleepModeCommandNotification
                      object:nil
                    userInfo:info];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SleepModeStateChangedNotification
                      object:nil];
}

#pragma mark - Enable

- (void)enable
{
    self.enabled = YES;
}

#pragma mark - Disable

- (void)disable
{
    self.enabled = NO;
}

#pragma mark - Toggle

- (void)toggle
{
    self.enabled = !self.enabled;
}

#pragma mark - Timeout

- (void)setTimeout:(NSTimeInterval)timeout
{
    if (timeout < 1.0)
        timeout = 1.0;

    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    [defaults setDouble:timeout
                 forKey:SleepModeTimeoutKey];

    [defaults synchronize];

    NSDictionary *info = @{
        @"timeout": @(timeout)
    };

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SleepModeCommandNotification
                      object:nil
                    userInfo:info];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SleepModeStateChangedNotification
                      object:nil];
}

- (NSTimeInterval)currentTimeout
{
    NSTimeInterval timeout =
        [[NSUserDefaults standardUserDefaults]
            doubleForKey:SleepModeTimeoutKey];

    if (timeout <= 0)
        timeout = 15.0;

    return timeout;
}

#pragma mark - Reset

- (void)resetTimer
{
    [[NSNotificationCenter defaultCenter]
        postNotificationName:SleepModeCommandNotification
                      object:nil
                    userInfo:@{
                        @"reset": @YES
                    }];
}

@end
