#import "SleepManager.h"

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <SpringBoard/SpringBoard.h>

@interface SleepManager ()

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) NSTimeInterval timeout;
@property (nonatomic, retain) NSTimer *timer;
@property (nonatomic, assign) BOOL started;

@end

@implementation SleepManager {
    BOOL _enabled;
    NSTimeInterval _timeout;
    NSTimer *_timer;
    BOOL _started;
}

+ (instancetype)sharedInstance
{
    static SleepManager *manager = nil;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
    });

    return manager;
}

- (instancetype)init
{
    self = [super init];

    if (self) {
        NSUserDefaults *defaults =
            [NSUserDefaults standardUserDefaults];

        id enabledValue =
            [defaults objectForKey:@"SleepModeEnabled"];

        id timeoutValue =
            [defaults objectForKey:@"SleepModeTimeout"];

        _enabled =
            (enabledValue != nil)
            ? [enabledValue boolValue]
            : YES;

        _timeout =
            (timeoutValue != nil)
            ? [timeoutValue doubleValue]
            : 15.0;

        if (_timeout <= 0) {
            _timeout = 15.0;
        }

        _timer = nil;
        _started = NO;
    }

    return self;
}

#pragma mark - Properties

- (BOOL)enabled
{
    return _enabled;
}

- (void)setEnabled:(BOOL)enabled
{
    _enabled = enabled;

    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    [defaults setBool:enabled
               forKey:@"SleepModeEnabled"];

    [defaults synchronize];

    if (enabled) {
        [self start];
    } else {
        [self stop];
    }
}

- (NSTimeInterval)timeout
{
    return _timeout;
}

- (void)setTimeout:(NSTimeInterval)timeout
{
    if (timeout <= 0) {
        timeout = 15.0;
    }

    _timeout = timeout;

    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    [defaults setDouble:timeout
                 forKey:@"SleepModeTimeout"];

    [defaults synchronize];

    if (_started) {
        [self resetTimer];
    }
}

#pragma mark - Start / Stop

- (void)start
{
    if (_started) {
        [self resetTimer];
        return;
    }

    _started = YES;

    [self resetTimer];
}

- (void)stop
{
    _started = NO;

    if (_timer != nil) {
        [_timer invalidate];
        _timer = nil;
    }
}

#pragma mark - Timer

- (void)resetTimer
{
    if (!_enabled || !_started) {
        return;
    }

    if (_timer != nil) {
        [_timer invalidate];
        _timer = nil;
    }

    _timer =
        [NSTimer timerWithTimeInterval:_timeout
                                target:self
                              selector:@selector(timerFired:)
                              userInfo:nil
                               repeats:NO];

    [[NSRunLoop mainRunLoop]
        addTimer:_timer
        forMode:NSRunLoopCommonModes];
}

- (void)timerFired:(NSTimer *)timer
{
    if (!_enabled || !_started) {
        return;
    }

    _timer = nil;

    [self closeRunningApplications];

    [self lockScreen];

    [self resetTimer];
}

#pragma mark - Close Applications

- (void)closeRunningApplications
{
    Class applicationControllerClass =
        NSClassFromString(@"SBApplicationController");

    if (applicationControllerClass == Nil) {
        return;
    }

    id controller =
        [applicationControllerClass sharedInstance];

    if (controller == nil) {
        return;
    }

    NSArray *applications = nil;

    if ([controller respondsToSelector:@selector(allApplications)]) {
        applications = [controller allApplications];
    }

    if (![applications isKindOfClass:[NSArray class]]) {
        return;
    }

    Class systemServiceClass =
        NSClassFromString(@"FBSystemService");

    id systemService = nil;

    if (systemServiceClass != Nil &&
        [systemServiceClass respondsToSelector:@selector(sharedInstance)]) {
        systemService =
            [systemServiceClass sharedInstance];
    }

    for (id application in applications) {

        if (application == nil) {
            continue;
        }

        NSString *bundleIdentifier = nil;

        if ([application respondsToSelector:@selector(bundleIdentifier)]) {
            bundleIdentifier =
                [application bundleIdentifier];
        }

        if (bundleIdentifier.length == 0) {
            continue;
        }

        // Không đóng các thành phần hệ thống.
        if ([bundleIdentifier isEqualToString:@"com.apple.springboard"] ||
            [bundleIdentifier isEqualToString:@"com.apple.Preferences"]) {
            continue;
        }

        if (systemService != nil &&
            [systemService respondsToSelector:
                @selector(terminateApplication:forReason:andReport:)]) {

            @try {
                [systemService
                    terminateApplication:application
                    forReason:@"SleepMode"
                    andReport:NO];
            }
            @catch (__unused NSException *exception) {
            }
        }
    }
}

#pragma mark - Lock

- (void)lockScreen
{
    Class backBoardControllerClass =
        NSClassFromString(@"SBBackBoardController");

    if (backBoardControllerClass != Nil &&
        [backBoardControllerClass respondsToSelector:@selector(sharedInstance)]) {

        id controller =
            [backBoardControllerClass sharedInstance];

        if ([controller respondsToSelector:@selector(lockScreen)]) {
            [controller lockScreen];
            return;
        }
    }

    // Fallback cho các build iOS khác.
    Class springBoardClass =
        NSClassFromString(@"SpringBoard");

    if (springBoardClass != Nil &&
        [springBoardClass respondsToSelector:@selector(sharedApplication)]) {

        id springBoard =
            [springBoardClass sharedApplication];

        if ([springBoard respondsToSelector:@selector(_lockScreen)]) {
            [springBoard _lockScreen];
        }
    }
}

@end
