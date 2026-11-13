#import "SleepManager.h"

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

@interface SleepManager ()
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) NSTimeInterval timeout;
@property (nonatomic, assign) BOOL started;
@property (nonatomic, assign) BOOL deviceLocked;
@property (nonatomic, assign) BOOL isEnteringSleep;
@property (nonatomic, assign) NSTimeInterval lastInteraction;
@property (nonatomic, strong) dispatch_source_t timer;
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
        _lastInteraction = CFAbsoluteTimeGetCurrent();
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

        [self installDarwinObserver];
    }

    return self;
}

- (void)dealloc
{
    [self stopTimer];

    [[NSNotificationCenter defaultCenter]
        removeObserver:self];

    CFNotificationCenterRemoveObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge const void *)(self),
        NULL,
        NULL
    );
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
    _lastInteraction = CFAbsoluteTimeGetCurrent();

    NSLog(
        @"[SleepMode] Timer started, timeout = %.1f seconds",
        _timeout
    );

    [self resetTimer];
}

- (void)stop
{
    _started = NO;
    [self stopTimer];

    NSLog(@"[SleepMode] Timer stopped");
}

#pragma mark - Timer

- (void)resetTimer
{
    if (!_enabled || !_started || _deviceLocked) {
        return;
    }

    _lastInteraction =
        CFAbsoluteTimeGetCurrent();

    [self stopTimer];

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
        (uint64_t)(_timeout * NSEC_PER_SEC);

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

    dispatch_source_set_event_handler(timer, ^{
        __strong SleepManager *strongSelf = weakSelf;

        if (strongSelf == nil) {
            return;
        }

        [strongSelf timerFired];
    });

    dispatch_resume(timer);

    NSLog(@"[SleepMode] Timer reset");
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
        CFAbsoluteTimeGetCurrent() -
        _lastInteraction;

    if (elapsed < _timeout) {
        [self resetTimer];
        return;
    }

    NSLog(
        @"[SleepMode] Timeout reached after %.1f seconds",
        elapsed
    );

    _isEnteringSleep = YES;

    [self stopTimer];

    [self enterSleepMode];
}

#pragma mark - User Interaction

- (void)userDidInteract
{
    if (!_enabled || !_started) {
        return;
    }

    if (_isEnteringSleep) {
        return;
    }

    _lastInteraction =
        CFAbsoluteTimeGetCurrent();

    NSLog(@"[SleepMode] User interaction detected");

    [self resetTimer];
}

- (void)resetIdleTimer
{
    [self userDidInteract];
}

#pragma mark - Sleep

- (void)enterSleepMode
{
    if (!_enabled || _deviceLocked) {
        _isEnteringSleep = NO;
        return;
    }

    NSLog(@"[SleepMode] Timeout reached");

    [self terminateUserApplications];

    [self lockDevice];
}

#pragma mark - Lock

- (void)lockDevice
{
    NSLog(@"[SleepMode] Locking device");

    Class lockManagerClass =
        NSClassFromString(@"SBLockScreenManager");

    if (lockManagerClass != Nil) {

        id lockManager =
            [lockManagerClass sharedInstance];

        if (lockManager != nil &&
            [lockManager respondsToSelector:
                @selector(lockUIFromSource:withOptions:)]) {

            NSLog(
                @"[SleepMode] Locking device via SBLockScreenManager"
            );

            @try {
                [lockManager
                    lockUIFromSource:1
                    withOptions:nil];

                return;
            }
            @catch (__unused NSException *exception) {
            }
        }

        if (lockManager != nil &&
            [lockManager respondsToSelector:
                @selector(_simulateLockButtonPress)]) {

            NSLog(
                @"[SleepMode] Locking device via _simulateLockButtonPress"
            );

            @try {
                [lockManager
                    _simulateLockButtonPress];

                return;
            }
            @catch (__unused NSException *exception) {
            }
        }
    }

    Class backBoardClass =
        NSClassFromString(@"SBBackBoardController");

    if (backBoardClass != Nil &&
        [backBoardClass respondsToSelector:
            @selector(sharedInstance)]) {

        id controller =
            [backBoardClass sharedInstance];

        if ([controller respondsToSelector:
                @selector(lockScreen)]) {

            @try {
                [controller lockScreen];
                return;
            }
            @catch (__unused NSException *exception) {
            }
        }
    }

    NSLog(@"[SleepMode] Unable to lock device");
}

#pragma mark - Applications

- (void)terminateUserApplications
{
    Class controllerClass =
        NSClassFromString(@"SBApplicationController");

    if (controllerClass == Nil) {
        NSLog(
            @"[SleepMode] SBApplicationController unavailable"
        );
        return;
    }

    id controller =
        [controllerClass sharedInstance];

    if (controller == nil) {
        NSLog(
            @"[SleepMode] Cannot get SBApplicationController"
        );
        return;
    }

    NSArray *applications = nil;

    if ([controller respondsToSelector:
            @selector(allApplications)]) {

        applications =
            [controller allApplications];
    }

    if (![applications isKindOfClass:[NSArray class]]) {
        NSLog(
            @"[SleepMode] No running applications found"
        );
        return;
    }

    Class serviceClass =
        NSClassFromString(@"FBSSystemService");

    if (serviceClass == Nil) {
        serviceClass =
            NSClassFromString(@"FBSystemService");
    }

    if (serviceClass == Nil) {
        NSLog(
            @"[SleepMode] FBSSystemService unavailable"
        );
        return;
    }

    id service = nil;

    if ([serviceClass respondsToSelector:
            @selector(sharedService)]) {

        service =
            [serviceClass sharedService];
    }

    if (service == nil &&
        [serviceClass respondsToSelector:
            @selector(sharedInstance)]) {

        service =
            [serviceClass sharedInstance];
    }

    if (service == nil) {
        NSLog(
            @"[SleepMode] FBSSystemService unavailable"
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

    if (![service respondsToSelector:terminateSelector]) {
        NSLog(
            @"[SleepMode] Termination selector unavailable"
        );
        return;
    }

    NSSet *protectedApplications =
        [NSSet setWithObjects:
            @"com.apple.springboard",
            @"com.apple.Preferences",
            @"com.apple.WebKit.Networking",
            @"com.apple.WebKit.WebContent",
            @"com.apple.WebKit.GPU",
            @"com.apple.UIKit.pasteboardd",
            @"com.apple.Pasteboard",
            nil];

    for (id application in applications) {

        NSString *bundleIdentifier = nil;

        if ([application respondsToSelector:
                @selector(bundleIdentifier)]) {

            bundleIdentifier =
                [application bundleIdentifier];
        }

        if (bundleIdentifier.length == 0) {
            continue;
        }

        if ([protectedApplications
                containsObject:bundleIdentifier]) {

            continue;
        }

        if ([bundleIdentifier
                hasPrefix:@"com.apple."]) {

            continue;
        }

        NSLog(
            @"[SleepMode] Terminating app: %@",
            bundleIdentifier
        );

        @try {
            [service
                terminateApplication:application
                forReason:@"SleepMode automatic idle termination"
                andReport:NO
                withDescription:@"SleepMode"];
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

    NSLog(@"[SleepMode] DeviceDidLock");
}

- (void)deviceDidUnlock
{
    _deviceLocked = NO;
    _isEnteringSleep = NO;

    NSLog(@"[SleepMode] DeviceDidUnlock");

    if (_enabled && _started) {
        [self resetTimer];
    }
}

#pragma mark - Darwin Notification

static void SleepModeDarwinCallback(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo
)
{
    SleepManager *manager =
        (__bridge SleepManager *)observer;

    if (manager == nil) {
        return;
    }

    if (name != NULL &&
        CFStringCompare(
            name,
            CFSTR("com.trantu.sleepmode.touch"),
            0
        ) == kCFCompareEqualTo) {

        dispatch_async(
            dispatch_get_main_queue(),
            ^{
                [manager userDidInteract];
            }
        );
    }
}

- (void)installDarwinObserver
{
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge const void *)(self),
        SleepModeDarwinCallback,
        CFSTR("com.trantu.sleepmode.touch"),
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately
    );
}

#pragma mark - State

- (void)postStateChanged
{
    [[NSNotificationCenter defaultCenter]
        postNotificationName:
            @"com.trantu.sleepmode.stateChanged"
        object:self
        userInfo:@{
            @"enabled":
                @(_enabled),

            @"timeout":
                @(_timeout)
        }];
}

@end
