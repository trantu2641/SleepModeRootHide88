#import "SleepManager.h"

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/message.h>

@interface SleepManager : NSObject {
    BOOL _enabled;
    NSTimeInterval _timeout;

    BOOL _started;
    BOOL _deviceLocked;
    BOOL _isEnteringSleep;

    NSTimeInterval _lastInteraction;

    dispatch_source_t _timer;
}

+ (instancetype)sharedInstance;

- (void)start;
- (void)stop;

- (void)resetTimer;
- (void)resetIdleTimer;
- (void)userDidInteract;

- (BOOL)isEnabled;
- (void)setEnabled:(BOOL)enabled;

- (NSTimeInterval)timeout;
- (void)setTimeout:(NSTimeInterval)timeout;

@end

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

        NSLog(
            @"[SleepMode] SBApplicationController unavailable"
        );

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

    SEL allApplicationsSelector =
        @selector(allApplications);

    if ([controller
            respondsToSelector:
                allApplicationsSelector]) {

        applications =
            ((id (*)(id, SEL))
             objc_msgSend)(
                controller,
                allApplicationsSelector
            );
    }

    if (![applications
            isKindOfClass:[NSArray class]]) {

        NSLog(
            @"[SleepMode] No applications"
        );

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

        NSLog(
            @"[SleepMode] FBSSystemService unavailable"
        );

        return;
    }

    id service = nil;

    SEL sharedServiceSelector =
        @selector(sharedService);

    if ([serviceClass
            respondsToSelector:
                sharedServiceSelector]) {

        service =
            ((id (*)(id, SEL))
             objc_msgSend)(
                serviceClass,
                sharedServiceSelector
            );
    }

    if (service == nil) {

        SEL sharedInstanceSelector =
            @selector(sharedInstance);

        if ([serviceClass
                respondsToSelector:
                    sharedInstanceSelector]) {

            service =
                ((id (*)(id, SEL))
                 objc_msgSend)(
                    serviceClass,
                    sharedInstanceSelector
                );
        }
    }

    if (service == nil) {

        NSLog(
            @"[SleepMode] System service unavailable"
        );

        return;
    }

    SEL terminateSelector =
        @selector(
            terminateApplication:
            forReason:
            andReport:
            withDescription:
        );

    if (![service
            respondsToSelector:
                terminateSelector]) {

        /*
         * Một số iOS dùng selector 3 tham số.
         */
        terminateSelector =
            @selector(
                terminateApplication:
                forReason:
                andReport:
            );
    }

    BOOL hasFourArguments =
        [service
            respondsToSelector:
                @selector(
                    terminateApplication:
                    forReason:
                    andReport:
                    withDescription:
                )];

    BOOL hasThreeArguments =
        [service
            respondsToSelector:
                @selector(
                    terminateApplication:
                    forReason:
                    andReport:
                )];

    if (!hasFourArguments &&
        !hasThreeArguments) {

        NSLog(
            @"[SleepMode] Termination API unavailable"
        );

        return;
    }

    NSSet *protectedApplications =
        [NSSet setWithObjects:
            @"com.apple.springboard",
            @"com.apple.Preferences",
            nil];

    for (id application in applications) {

        NSString *bundleIdentifier = nil;

        SEL bundleSelector =
            @selector(bundleIdentifier);

        if ([application
                respondsToSelector:
                    bundleSelector]) {

            bundleIdentifier =
                ((id (*)(id, SEL))
                 objc_msgSend)(
                    application,
                    bundleSelector
                );
        }

        if (bundleIdentifier.length == 0) {
            continue;
        }

        if ([protectedApplications
                containsObject:
                    bundleIdentifier]) {

            continue;
        }

        if ([bundleIdentifier
                hasPrefix:@"com.apple."]) {

            continue;
        }

        NSLog(
            @"[SleepMode] Terminating %@",
            bundleIdentifier
        );

        @try {

            if (hasFourArguments) {

                typedef void (*Terminate4)(
                    id,
                    SEL,
                    id,
                    id,
                    BOOL,
                    id
                );

                Terminate4 terminate =
                    (Terminate4)objc_msgSend;

                terminate(
                    service,
                    terminateSelector,
                    application,
                    @"SleepMode",
                    NO,
                    @"SleepMode"
                );

            } else {

                typedef void (*Terminate3)(
                    id,
                    SEL,
                    id,
                    id,
                    BOOL
                );

                Terminate3 terminate =
                    (Terminate3)objc_msgSend;

                terminate(
                    service,
                    terminateSelector,
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

    NSLog(
        @"[SleepMode] Device locked"
    );
}

- (void)deviceDidUnlock
{
    _deviceLocked = NO;
    _isEnteringSleep = NO;

    NSLog(
        @"[SleepMode] Device unlocked"
    );

    if (_enabled &&
        _started) {

        [self resetTimer];
    }
}

#pragma mark - Notification

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
