#import "SleepManager.h"

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/message.h>

static NSString * const kSleepModeEnabledKey =
    @"SleepModeEnabled";

static NSString * const kSleepModeTimeoutKey =
    @"SleepModeTimeout";

static NSString * const kSleepModeChangedNotification =
    @"com.trantu.sleepmode.settingsChanged";

static NSString * const kSleepModePrefsDomain =
    @"com.trantu.sleepmode";


@interface SleepManager ()

- (void)timerFired;
- (void)stopTimer;
- (void)enterSleepMode;
- (void)lockDevice;
- (void)terminateUserApplications;

- (void)deviceDidLock;
- (void)deviceDidUnlock;

- (void)settingsChanged;

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

        NSDictionary *settings =
            [NSDictionary dictionaryWithContentsOfFile:
                @"/var/mobile/Library/Preferences/com.trantu.sleepmode.plist"];

        NSNumber *enabledValue =
            settings[kSleepModeEnabledKey];

        NSNumber *timeoutValue =
            settings[kSleepModeTimeoutKey];

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


        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge const void *)(self),
            DarwinSettingsChanged,
            (__bridge CFStringRef)
                kSleepModeChangedNotification,
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );
    }

    return self;
}


static void DarwinSettingsChanged(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo
)
{
    SleepManager *manager =
        (__bridge SleepManager *)observer;

    if (manager != nil) {
        dispatch_async(
            dispatch_get_main_queue(),
            ^{
                [manager settingsChanged];
            }
        );
    }
}


- (void)dealloc
{
    [self stopTimer];

    CFNotificationCenterRemoveObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge const void *)(self),
        (__bridge CFStringRef)
            kSleepModeChangedNotification,
        NULL
    );

    [[NSNotificationCenter defaultCenter]
        removeObserver:self];
}


#pragma mark - Settings


- (NSDictionary *)loadSettings
{
    NSDictionary *settings =
        [NSDictionary dictionaryWithContentsOfFile:
            @"/var/mobile/Library/Preferences/com.trantu.sleepmode.plist"];

    if (![settings isKindOfClass:[NSDictionary class]]) {
        return @{};
    }

    return settings;
}


- (BOOL)isEnabled
{
    return _enabled;
}


- (void)setEnabled:(BOOL)enabled
{
    _enabled = enabled;

    if (_enabled) {
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

    if (_started && _enabled) {
        [self resetTimer];
    }

    [self postStateChanged];
}


- (void)settingsChanged
{
    NSDictionary *settings =
        [self loadSettings];

    NSNumber *enabledValue =
        settings[kSleepModeEnabledKey];

    NSNumber *timeoutValue =
        settings[kSleepModeTimeoutKey];


    if (enabledValue != nil) {
        _enabled =
            [enabledValue boolValue];
    }

    if (timeoutValue != nil) {

        NSTimeInterval value =
            [timeoutValue doubleValue];

        if (value >= 1.0) {
            _timeout = value;
        }
    }


    NSLog(
        @"[SleepMode] Settings changed: enabled=%d timeout=%.1f",
        _enabled,
        _timeout
    );


    if (_enabled) {
        if (!_started) {
            [self start];
        } else {
            [self resetTimer];
        }
    } else {
        [self stop];
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
        @"[SleepMode] START timeout=%.1f",
        _timeout
    );

    [self resetTimer];
}


- (void)stop
{
    _started = NO;

    [self stopTimer];

    NSLog(@"[SleepMode] STOP");
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
        NSLog(@"[SleepMode] ERROR: timer creation failed");
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


    __weak SleepManager *weakSelf =
        self;


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
        @"[SleepMode] TIMER %.1f seconds",
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
        @"[SleepMode] TIMEOUT elapsed=%.2f target=%.2f",
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


    /*
     * Không tạo timer mới nếu chưa có timer.
     * resetTimer() tự hủy timer cũ và tạo timer mới.
     */
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
        @"[SleepMode] ENTER SLEEP"
    );


    [self terminateUserApplications];

    [self lockDevice];
}


#pragma mark - Lock


- (void)lockDevice
{
    NSLog(
        @"[SleepMode] LOCK DEVICE"
    );


    /*
     * iOS 16 SpringBoard:
     * SBLockScreenManager
     */

    Class cls =
        NSClassFromString(
            @"SBLockScreenManager"
        );


    if (cls != Nil) {

        id manager =
            ((id (*)(id, SEL))
                objc_msgSend)(
                    cls,
                    @selector(sharedInstance)
                );


        if (manager != nil) {

            SEL selector =
                @selector(
                    lockUIFromSource:
                    withOptions:
                );


            if ([manager
                    respondsToSelector:selector]) {

                typedef void (*LockFunc)(
                    id,
                    SEL,
                    NSInteger,
                    id
                );


                LockFunc fn =
                    (LockFunc)objc_msgSend;


                fn(
                    manager,
                    selector,
                    1,
                    nil
                );


                NSLog(
                    @"[SleepMode] LOCK OK: lockUIFromSource:"
                );

                return;
            }


            selector =
                @selector(
                    _simulateLockButtonPress
                );


            if ([manager
                    respondsToSelector:selector]) {

                ((void (*)(id, SEL))
                    objc_msgSend)(
                        manager,
                        selector
                    );


                NSLog(
                    @"[SleepMode] LOCK OK: simulateLockButtonPress"
                );

                return;
            }
        }
    }


    /*
     * Fallback
     */

    Class backBoard =
        NSClassFromString(
            @"SBBackBoardController"
        );


    if (backBoard != Nil) {

        id controller =
            ((id (*)(id, SEL))
                objc_msgSend)(
                    backBoard,
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


            NSLog(
                @"[SleepMode] LOCK OK: SBBackBoardController"
            );

            return;
        }
    }


    NSLog(
        @"[SleepMode] ERROR: NO LOCK API"
    );
}


#pragma mark - Close Apps


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


    SEL selector =
        @selector(allApplications);


    NSArray *applications = nil;


    if ([controller
            respondsToSelector:selector]) {

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


    if ([serviceClass
            respondsToSelector:selector]) {

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


    BOOL has4 =
        [service respondsToSelector:
            terminate4];


    BOOL has3 =
        [service respondsToSelector:
            terminate3];


    NSSet *protectedApps =
        [NSSet setWithObjects:
            @"com.apple.springboard",
            @"com.apple.Preferences",
            nil];


    for (id app in applications) {

        selector =
            @selector(bundleIdentifier);


        NSString *bundleIdentifier = nil;


        if ([app respondsToSelector:selector]) {

            bundleIdentifier =
                ((id (*)(id, SEL))
                    objc_msgSend)(
                        app,
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

            if (has4) {

                typedef void (*Fn)(
                    id,
                    SEL,
                    id,
                    id,
                    BOOL,
                    id
                );


                ((Fn)objc_msgSend)(
                    service,
                    terminate4,
                    app,
                    @"SleepMode",
                    NO,
                    @"SleepMode"
                );

            } else if (has3) {

                typedef void (*Fn)(
                    id,
                    SEL,
                    id,
                    id,
                    BOOL
                );


                ((Fn)objc_msgSend)(
                    service,
                    terminate3,
                    app,
                    @"SleepMode",
                    NO
                );
            }

        }
        @catch (__unused NSException *exception) {
        }
    }
}


#pragma mark - Lock State


- (void)deviceDidLock
{
    _deviceLocked = YES;

    [self stopTimer];
}


- (void)deviceDidUnlock
{
    _deviceLocked = NO;
    _isEnteringSleep = NO;

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
