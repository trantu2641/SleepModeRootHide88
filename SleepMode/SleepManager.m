#import "SleepManager.h"

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/message.h>

@implementation SleepManager

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

        NSNumber *enabledValue =
            [defaults objectForKey:@"SleepModeEnabled"];

        NSNumber *timeoutValue =
            [defaults objectForKey:@"SleepModeTimeout"];

        _enabled =
            enabledValue != nil
            ? [enabledValue boolValue]
            : YES;

        _timeout =
            timeoutValue != nil
            ? [timeoutValue doubleValue]
            : 15.0;

        if (_timeout < 1.0) {
            _timeout = 15.0;
        }

        _started = NO;
        _deviceLocked = NO;
        _isEnteringSleep = NO;

        _lastInteraction =
            CFAbsoluteTimeGetCurrent();

        _timer = nil;

        [[NSNotificationCenter defaultCenter]
            addObserver:self
            selector:@selector(deviceDidLock)
            name:@"SBDeviceLockStateChangedNotification"
            object:nil];

        [[NSNotificationCenter defaultCenter]
            addObserver:self
            selector:@selector(deviceDidUnlock)
            name:@"SBDeviceUnlockStateChangedNotification"
            object:nil];
    }

    return self;
}

- (void)dealloc
{
    [self stopTimer];

    [[NSNotificationCenter defaultCenter]
        removeObserver:self];
}

#pragma mark - Settings

- (BOOL)isEnabled
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

    [self postStateChanged];
}

- (NSTimeInterval)timeout
{
    return _timeout;
}

- (void)setTimeout:(NSTimeInterval)timeout
{
    if (timeout < 1.0) {
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

    [self postStateChanged];
}

#pragma mark - Start / Stop

- (void)start
{
    if (!_enabled) {
        return;
    }

    _started = YES;
    _deviceLocked = NO;
    _isEnteringSleep = NO;

    _lastInteraction =
        CFAbsoluteTimeGetCurrent();

    NSLog(
        @"[SleepMode] Started - timeout %.1f",
        _timeout
    );

    [self resetTimer];
}

- (void)stop
{
    _started = NO;

    [self stopTimer];

    NSLog(@"[SleepMode] Stopped");
}

#pragma mark - Timer

- (void)resetTimer
{
    if (!_enabled ||
        !_started ||
        _deviceLocked) {
        return;
    }

    [self stopTimer];

    _lastInteraction =
        CFAbsoluteTimeGetCurrent();

    dispatch_source_t timer =
        dispatch_source_create(
            DISPATCH_SOURCE_TYPE_TIMER,
            0,
            0,
            dispatch_get_main_queue()
        );

    if (timer == nil) {
        return;
    }

    _timer = timer;

    uint64_t interval =
        (uint64_t)(
            _timeout * NSEC_PER_SEC
        );

    dispatch_source_set_timer(
        timer,
        dispatch_time(
            DISPATCH_TIME_NOW,
            interval
        ),
        DISPATCH_TIME_FOREVER,
        1000000
    );

    __weak SleepManager *weakSelf = self;

    dispatch_source_set_event_handler(
        timer,
        ^{
            __strong SleepManager *strongSelf =
                weakSelf;

            if (strongSelf != nil) {
                [strongSelf timerFired];
            }
        }
    );

    dispatch_resume(timer);

    NSLog(
        @"[SleepMode] Timer reset: %.1f seconds",
        _timeout
    );
}

- (void)stopTimer
{
    if (_timer != nil) {

        dispatch_source_cancel(_timer);

        _timer = nil;
    }
}

- (void)timerFired
{
    if (!_enabled ||
        !_started ||
        _deviceLocked ||
        _isEnteringSleep) {
        return;
    }

    NSTimeInterval elapsed =
        CFAbsoluteTimeGetCurrent()
        - _lastInteraction;

    NSLog(
        @"[SleepMode] Timer fired - elapsed %.2f / %.2f",
        elapsed,
        _timeout
    );

    if (elapsed < _timeout) {
        [self resetTimer];
        return;
    }

    _isEnteringSleep = YES;

    [self stopTimer];

    [self enterSleepMode];
}

#pragma mark - Interaction

- (void)userDidInteract
{
    if (!_enabled ||
        !_started ||
        _isEnteringSleep) {
        return;
    }

    _lastInteraction =
        CFAbsoluteTimeGetCurrent();

    [self resetTimer];
}

- (void)resetIdleTimer
{
    [self userDidInteract];
}

#pragma mark - Sleep

- (void)enterSleepMode
{
    if (!_enabled ||
        _deviceLocked) {

        _isEnteringSleep = NO;

        return;
    }

    NSLog(
        @"[SleepMode] Entering sleep mode"
    );

    [self terminateUserApplications];

    [self lockDevice];
}

#pragma mark - Lock Device

- (void)lockDevice
{
    NSLog(
        @"[SleepMode] Locking device"
    );

    Class lockManagerClass =
        NSClassFromString(@"SBLockScreenManager");

    if (lockManagerClass != Nil) {

        id lockManager =
            ((id (*)(id, SEL))
             objc_msgSend)(
                lockManagerClass,
                @selector(sharedInstance)
            );

        if (lockManager != nil) {

            SEL selector =
                @selector(
                    lockUIFromSource:withOptions:
                );

            if ([lockManager
                    respondsToSelector:selector]) {

                typedef void (*LockFunc)(
                    id,
                    SEL,
                    NSInteger,
                    id
                );

                LockFunc lockFunc =
                    (LockFunc)objc_msgSend;

                lockFunc(
                    lockManager,
                    selector,
                    1,
                    nil
                );

                return;
            }

            selector =
                @selector(
                    _simulateLockButtonPress
                );

            if ([lockManager
                    respondsToSelector:selector]) {

                ((void (*)(id, SEL))
                 objc_msgSend)(
                    lockManager,
                    selector
                );

                return;
            }
        }
    }

    Class backBoardClass =
        NSClassFromString(
            @"SBBackBoardController"
        );

    if (backBoardClass != Nil) {

        id controller =
            ((id (*)(id, SEL))
             objc_msgSend)(
                backBoardClass,
                @selector(sharedInstance)
            );

        SEL selector =
            @selector(lockScreen);

        if (controller != nil &&
            [controller
                respondsToSelector:selector]) {

            ((void (*)(id, SEL))
             objc_msgSend)(
                controller,
                selector
            );

            return;
        }
    }

    NSLog(
        @"[SleepMode] Lock method unavailable"
    );
}

#pragma mark - Terminate Applications

- (void)terminateUserApplications
{
    Class applicationControllerClass =
        NSClassFromString(
            @"SBApplicationController"
        );

    if (applicationControllerClass == Nil) {
        return;
    }

    id controller =
        ((id (*)(id, SEL))
         objc_msgSend)(
            applicationControllerClass,
            @selector(sharedInstance)
        );

    if (controller == nil) {
        return;
    }

    NSArray *applications = nil;

    SEL selector =
        @selector(allApplications);

    if ([controller respondsToSelector:selector]) {

        applications =
            ((id (*)(id, SEL))
             objc_msgSend)(
                controller,
                selector
            );
    }

    if (![applications
            isKindOfClass:[NSArray class]]) {
        return;
    }

    Class serviceClass =
        NSClassFromString(
            @"FBSSystemService"
        );

    if (serviceClass == Nil) {
        serviceClass =
            NSClassFromString(
                @"FBSystemService"
            );
    }

    if (serviceClass == Nil) {
        return;
    }

    id service = nil;

    selector =
        @selector(sharedService);

    if ([serviceClass respondsToSelector:selector]) {

        service =
            ((id (*)(id, SEL))
             objc_msgSend)(
                serviceClass,
                selector
            );
    }

    if (service == nil) {

        selector =
            @selector(sharedInstance);

        if ([serviceClass
                respondsToSelector:selector]) {

            service =
                ((id (*)(id, SEL))
                 objc_msgSend)(
                    serviceClass,
                    selector
                );
        }
    }

    if (service == nil) {
        return;
    }

    SEL terminate4 =
        @selector(
            terminateApplication:
            forReason:
            andReport:
            withDescription:
        );

    SEL terminate3 =
        @selector(
            terminateApplication:
            forReason:
            andReport:
        );

    BOOL hasTerminate4 =
        [service respondsToSelector:terminate4];

    BOOL hasTerminate3 =
        [service respondsToSelector:terminate3];

    NSSet *protectedApps =
        [NSSet setWithObjects:
            @"com.apple.springboard",
            @"com.apple.Preferences",
            nil];

    for (id application in applications) {

        NSString *bundleIdentifier = nil;

        selector =
            @selector(bundleIdentifier);

        if ([application
                respondsToSelector:selector]) {

            bundleIdentifier =
                ((id (*)(id, SEL))
                 objc_msgSend)(
                    application,
                    selector
                );
        }

        if (bundleIdentifier.length == 0) {
            continue;
        }

        if ([protectedApps
                containsObject:bundleIdentifier]) {
            continue;
        }

        if ([bundleIdentifier
                hasPrefix:@"com.apple."]) {
            continue;
        }

        @try {

            if (hasTerminate4) {

                typedef void (*Terminate4Func)(
                    id,
                    SEL,
                    id,
                    id,
                    BOOL,
                    id
                );

                Terminate4Func fn =
                    (Terminate4Func)objc_msgSend;

                fn(
                    service,
                    terminate4,
                    application,
                    @"SleepMode",
                    NO,
                    @"SleepMode"
                );

            } else if (hasTerminate3) {

                typedef void (*Terminate3Func)(
                    id,
                    SEL,
                    id,
                    id,
                    BOOL
                );

                Terminate3Func fn =
                    (Terminate3Func)objc_msgSend;

                fn(
                    service,
                    terminate3,
                    application,
                    @"SleepMode",
                    NO
                );
            }

        }
        @catch (__unused NSException *exception) {
        }
    }
}

#pragma mark - Device State

- (void)deviceDidLock
{
    _deviceLocked = YES;

    [self stopTimer];
}

- (void)deviceDidUnlock
{
    _deviceLocked = NO;
    _isEnteringSleep = NO;

    if (_enabled && _started) {
        [self resetTimer];
    }
}

#pragma mark - State

- (void)postStateChanged
{
    [[NSNotificationCenter defaultCenter]
        postNotificationName:
            @"com.trantu.sleepmode.stateChanged"
        object:self
        userInfo:@{
            @"enabled": @(_enabled),
            @"timeout": @(_timeout)
        }];
}

@end
