#import "SleepManager.h"

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/message.h>

static NSString * const kPrefsPath =
    @"/var/mobile/Library/Preferences/com.trantu.sleepmode.plist";

static NSString * const kSettingsChangedNotification =
    @"com.trantu.sleepmode.settingsChanged";

static NSString * const kStateChangedNotification =
    @"com.trantu.sleepmode.stateChanged";

static NSString * const kEnabledKey =
    @"SleepModeEnabled";

static NSString * const kTimeoutKey =
    @"SleepModeTimeout";


@interface SleepManager ()

- (NSDictionary *)loadSettings;

- (void)settingsChanged;

- (void)timerFired;
- (void)stopTimer;

- (void)enterSleepMode;
- (void)lockDevice;
- (void)terminateUserApplications;

- (void)deviceDidLock;
- (void)deviceDidUnlock;

- (void)postStateChanged;

@end


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

    if (manager == nil) {
        return;
    }

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            [manager settingsChanged];
        }
    );
}


@implementation SleepManager


+ (instancetype)sharedInstance
{
    static SleepManager *manager = nil;

    static dispatch_once_t onceToken;

    dispatch_once(
        &onceToken,
        ^{
            manager = [[self alloc] init];
        }
    );

    return manager;
}


- (instancetype)init
{
    self = [super init];

    if (self) {

        NSDictionary *settings =
            [self loadSettings];

        NSNumber *enabled =
            settings[kEnabledKey];

        NSNumber *timeout =
            settings[kTimeoutKey];

        _enabled =
            enabled != nil
                ? [enabled boolValue]
                : YES;

        _timeout =
            timeout != nil
                ? [timeout doubleValue]
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
                kSettingsChangedNotification,
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );


        NSLog(
            @"[SleepMode] Core initialized: enabled=%d timeout=%.1f",
            _enabled,
            _timeout
        );
    }

    return self;
}


- (void)dealloc
{
    [self stopTimer];

    CFNotificationCenterRemoveObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge const void *)(self),
        (__bridge CFStringRef)
            kSettingsChangedNotification,
        NULL
    );

    [[NSNotificationCenter defaultCenter]
        removeObserver:self];
}


#pragma mark - Settings


- (NSDictionary *)loadSettings
{
    NSDictionary *settings =
        [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];

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

    NSNumber *enabled =
        settings[kEnabledKey];

    NSNumber *timeout =
        settings[kTimeoutKey];


    if (enabled != nil) {
        _enabled =
            [enabled boolValue];
    }


    if (timeout != nil) {

        NSTimeInterval value =
            [timeout doubleValue];

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
        @"[SleepMode] SpringBoard started"
    );

    [self resetTimer];
}


- (void)stop
{
    _started = NO;

    [self stopTimer];

    NSLog(
        @"[SleepMode] Timer stopped"
    );
}


#pragma mark - Timer


- (void)resetTimer
{
    if (!_enabled ||
        !_started ||
        _deviceLocked ||
        _isEnteringSleep) {

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
        NSLog(
            @"[SleepMode] Timer creation failed"
        );

        return;
    }


    _timer = timer;


    uint64_t interval =
        (uint64_t)(
            _timeout *
            NSEC_PER_SEC
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
        @"[SleepMode] Timer started, timeout = %.1f seconds",
        _timeout
    );
}


- (void)stopTimer
{
    if (_timer != nil) {

        dispatch_source_cancel(_timer);

        _timer = nil;

        NSLog(
            @"[SleepMode] Timer stopped"
        );
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
        @"[SleepMode] Timeout reached after %.1f seconds",
        elapsed
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
        _deviceLocked ||
        _isEnteringSleep) {

        return;
    }


    _lastInteraction =
        CFAbsoluteTimeGetCurrent();


    NSLog(
        @"[SleepMode] User interaction detected"
    );


    [self resetIdleTimer];

    [self resetTimer];
}


- (void)resetIdleTimer
{
    Class coordinatorClass =
        NSClassFromString(
            @"SBIdleTimerGlobalCoordinator"
        );

    if (coordinatorClass == Nil) {
        return;
    }


    id coordinator =
        ((id (*)(id, SEL))
            objc_msgSend)(
                coordinatorClass,
                @selector(sharedInstance)
            );

    if (coordinator == nil) {
        return;
    }


    SEL selector =
        @selector(resetIdleTimer);


    if ([coordinator
            respondsToSelector:selector]) {

        ((void (*)(id, SEL))
            objc_msgSend)(
                coordinator,
                selector
            );

        NSLog(
            @"[SleepMode] System idle timer reset"
        );
    }
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
        @"[SleepMode] Timeout reached"
    );


    [self terminateUserApplications];

    [self lockDevice];
}


#pragma mark - Lock


- (void)lockDevice
{
    NSLog(
        @"[SleepMode] Locking device"
    );


    /*
     * 1.1.0 thực tế có:
     *
     * SBIdleTimerGlobalCoordinator
     * lockFromSource:
     *
     * type encoding trong binary:
     * v20@0:8B16
     */

    Class idleClass =
        NSClassFromString(
            @"SBIdleTimerGlobalCoordinator"
        );


    if (idleClass != Nil) {

        id idleManager =
            ((id (*)(id, SEL))
                objc_msgSend)(
                    idleClass,
                    @selector(sharedInstance)
                );


        SEL lockSelector =
            @selector(lockFromSource:);


        if (idleManager != nil &&
            [idleManager
                respondsToSelector:lockSelector]) {

            typedef void (*LockFunction)(
                id,
                SEL,
                BOOL
            );


            LockFunction function =
                (LockFunction)objc_msgSend;


            function(
                idleManager,
                lockSelector,
                YES
            );


            NSLog(
                @"[SleepMode] Locking device via SBIdleTimerGlobalCoordinator"
            );


            return;
        }
    }


    /*
     * Fallback thực tế cũng xuất hiện trong 1.1.0:
     *
     * SBLockScreenManager
     * _simulateLockButtonPress
     */

    Class lockManagerClass =
        NSClassFromString(
            @"SBLockScreenManager"
        );


    if (lockManagerClass != Nil) {

        id lockManager =
            ((id (*)(id, SEL))
                objc_msgSend)(
                    lockManagerClass,
                    @selector(sharedInstance)
                );


        SEL simulateSelector =
            @selector(
                _simulateLockButtonPress
            );


        if (lockManager != nil &&
            [lockManager
                respondsToSelector:
                    simulateSelector]) {

            ((void (*)(id, SEL))
                objc_msgSend)(
                    lockManager,
                    simulateSelector
                );


            NSLog(
                @"[SleepMode] Locking device via SBLockScreenManager"
            );


            return;
        }
    }


    NSLog(
        @"[SleepMode] Unable to lock device"
    );


    _isEnteringSleep = NO;
}


#pragma mark - Close Apps


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

        NSLog(
            @"[SleepMode] Cannot get SBApplicationController"
        );

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
            @"[SleepMode] No running applications found"
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


    if (![service
            respondsToSelector:
                terminateSelector]) {

        NSLog(
            @"[SleepMode] Termination selector unavailable"
        );

        return;
    }


    /*
     * 1.1.0 có các process Apple/WebKit được bảo vệ.
     * Không dùng hasPrefix:@"com.apple." vì Safari
     * và một số app hệ thống vẫn phải được xử lý.
     */
    NSSet *protectedApps =
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

        SEL bundleIdentifierSelector =
            @selector(bundleIdentifier);


        NSString *bundleIdentifier = nil;


        if ([application
                respondsToSelector:
                    bundleIdentifierSelector]) {

            bundleIdentifier =
                ((id (*)(id, SEL))
                    objc_msgSend)(
                        application,
                        bundleIdentifierSelector
                    );
        }


        if (bundleIdentifier.length == 0) {
            continue;
        }


        if ([protectedApps
                containsObject:
                    bundleIdentifier]) {

            continue;
        }


        NSLog(
            @"[SleepMode] Terminating app: %@",
            bundleIdentifier
        );


        @try {

            typedef void (*TerminateFunction)(
                id,
                SEL,
                id,
                id,
                BOOL,
                id
            );


            TerminateFunction function =
                (TerminateFunction)objc_msgSend;


            function(
                service,
                terminateSelector,
                application,
                @"SleepMode automatic idle termination",
                NO,
                @"SleepMode"
            );

        }
        @catch (__unused NSException *exception) {

            NSLog(
                @"[SleepMode] Failed terminating app: %@",
                bundleIdentifier
            );
        }
    }
}


#pragma mark - Lock State


- (void)deviceDidLock
{
    _deviceLocked = YES;

    _isEnteringSleep = NO;

    [self stopTimer];


    NSLog(
        @"[SleepMode] DeviceDidLock"
    );
}


- (void)deviceDidUnlock
{
    _deviceLocked = NO;
    _isEnteringSleep = NO;


    NSLog(
        @"[SleepMode] DeviceDidUnlock"
    );


    if (_enabled &&
        _started) {

        [self resetTimer];
    }
}


#pragma mark - State Notification


- (void)postStateChanged
{
    [[NSNotificationCenter defaultCenter]
        postNotificationName:
            kStateChangedNotification
        object:self
        userInfo:@{
            @"enabled": @(_enabled),
            @"timeout": @(_timeout)
        }];
}


@end
