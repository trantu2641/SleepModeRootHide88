#import "SleepManager.h"

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

static NSString * const kSleepModeDomain =
    @"com.trantu.sleepmode";

static NSString * const kSleepModeEnabledKey =
    @"SleepModeEnabled";

static NSString * const kSleepModeTimeoutKey =
    @"SleepModeTimeout";

static NSString * const kSleepModeChangedNotification =
    @"com.trantu.sleepmode.settingsChanged";

@interface SleepManager ()
{
    BOOL _enabled;
    NSTimeInterval _timeout;

    NSTimer *_timer;
    BOOL _started;
}
@end

@implementation SleepManager

+ (instancetype)sharedInstance
{
    static SleepManager *instance = nil;
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

        _enabled = YES;
        _timeout = 300.0;
        _started = NO;
        _timer = nil;

        [self loadPreferences];

        [[NSNotificationCenter defaultCenter]
            addObserver:self
            selector:@selector(settingsChanged:)
            name:kSleepModeChangedNotification
            object:nil];
    }

    return self;
}

- (void)dealloc
{
    [_timer invalidate];
    _timer = nil;

    [[NSNotificationCenter defaultCenter]
        removeObserver:self];
}

#pragma mark - Preferences

- (void)loadPreferences
{
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc]
            initWithSuiteName:kSleepModeDomain];

    if (defaults == nil) {
        return;
    }

    if ([defaults objectForKey:kSleepModeEnabledKey] != nil) {

        _enabled =
            [defaults boolForKey:kSleepModeEnabledKey];
    }

    if ([defaults objectForKey:kSleepModeTimeoutKey] != nil) {

        double savedTimeout =
            [defaults doubleForKey:kSleepModeTimeoutKey];

        if (savedTimeout >= 15.0 &&
            savedTimeout <= 7200.0) {

            _timeout = savedTimeout;
        }
    }
}

- (NSTimeInterval)currentTimeout
{
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc]
            initWithSuiteName:kSleepModeDomain];

    if (defaults == nil) {
        return 300.0;
    }

    id value =
        [defaults objectForKey:kSleepModeTimeoutKey];

    if (value == nil) {
        return 300.0;
    }

    double timeout =
        [value doubleValue];

    if (timeout >= 15.0 &&
        timeout <= 7200.0) {

        return timeout;
    }

    return 300.0;
}

#pragma mark - Enabled

- (BOOL)isEnabled
{
    return _enabled;
}

- (void)setEnabled:(BOOL)enabled
{
    _enabled = enabled;

    NSUserDefaults *defaults =
        [[NSUserDefaults alloc]
            initWithSuiteName:kSleepModeDomain];

    if (defaults != nil) {

        [defaults setBool:enabled
                   forKey:kSleepModeEnabledKey];

        [defaults synchronize];
    }

    if (enabled) {
        [self start];
    } else {
        [self stop];
    }

    [[NSNotificationCenter defaultCenter]
        postNotificationName:kSleepModeChangedNotification
        object:nil];
}

#pragma mark - Timeout

- (NSTimeInterval)timeout
{
    return _timeout;
}

- (void)setTimeout:(NSTimeInterval)timeout
{
    if (timeout < 15.0) {
        timeout = 15.0;
    }

    if (timeout > 7200.0) {
        timeout = 7200.0;
    }

    _timeout = timeout;

    NSUserDefaults *defaults =
        [[NSUserDefaults alloc]
            initWithSuiteName:kSleepModeDomain];

    if (defaults != nil) {

        [defaults setDouble:timeout
                     forKey:kSleepModeTimeoutKey];

        [defaults synchronize];
    }

    if (_started) {
        [self resetTimer];
    }
}

#pragma mark - Start / Stop

- (void)start
{
    if (!_enabled) {
        return;
    }

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
    if (!_enabled) {
        return;
    }

    if (!_started) {
        return;
    }

    if (_timer != nil) {
        [_timer invalidate];
        _timer = nil;
    }

    NSTimeInterval timeout =
        [self currentTimeout];

    if (timeout < 15.0) {
        timeout = 15.0;
    }

    if (timeout > 7200.0) {
        timeout = 7200.0;
    }

    _timeout = timeout;

    _timer =
        [NSTimer timerWithTimeInterval:timeout
                                target:self
                              selector:@selector(timerFired:)
                              userInfo:nil
                               repeats:NO];

    if (_timer == nil) {
        return;
    }

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

    /*
     * Giữ nguyên cơ chế:
     * 1. Đóng app người dùng.
     * 2. Sau 0.15 giây khóa máy.
     */
    [self terminateUserApps];

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW,
                      (int64_t)(0.15 * NSEC_PER_SEC)),
        dispatch_get_main_queue(),
        ^{
            @autoreleasepool {

                if (!self->_enabled ||
                    !self->_started) {
                    return;
                }

                [self lockDevice];
            }
        }
    );
}

#pragma mark - Settings notification

- (void)settingsChanged:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {

            [self loadPreferences];

            if (self->_enabled) {
                [self start];
            } else {
                [self stop];
            }
        }
    });
}

#pragma mark - Lock Device

- (void)lockDevice
{
    @autoreleasepool {

        Class SBBackBoardController =
            objc_getClass("SBBackBoardController");

        if (SBBackBoardController != Nil) {

            SEL sharedSelector =
                NSSelectorFromString(@"sharedInstance");

            if ([SBBackBoardController
                    respondsToSelector:sharedSelector]) {

                id controller =
                    ((id (*)(id, SEL))
                        objc_msgSend)(
                            SBBackBoardController,
                            sharedSelector
                        );

                SEL lockSelector =
                    NSSelectorFromString(@"lockScreen");

                if ([controller
                        respondsToSelector:lockSelector]) {

                    ((void (*)(id, SEL))
                        objc_msgSend)(
                            controller,
                            lockSelector
                        );

                    return;
                }
            }
        }

        UIApplication *application =
            [UIApplication sharedApplication];

        SEL fallbackSelector =
            NSSelectorFromString(@"_lockScreen");

        if ([application
                respondsToSelector:fallbackSelector]) {

            ((void (*)(id, SEL))
                objc_msgSend)(
                    application,
                    fallbackSelector
                );
        }
    }
}

#pragma mark - Terminate User Apps

- (void)terminateUserApps
{
    @autoreleasepool {

        Class SBApplicationController =
            objc_getClass("SBApplicationController");

        if (SBApplicationController == Nil) {
            return;
        }

        SEL sharedSelector =
            NSSelectorFromString(@"sharedInstance");

        if (![SBApplicationController
                respondsToSelector:sharedSelector]) {
            return;
        }

        id appController =
            ((id (*)(id, SEL))
                objc_msgSend)(
                    SBApplicationController,
                    sharedSelector
                );

        if (appController == nil) {
            return;
        }

        SEL applicationsSelector =
            NSSelectorFromString(@"applications");

        if (![appController
                respondsToSelector:applicationsSelector]) {
            return;
        }

        id applications =
            ((id (*)(id, SEL))
                objc_msgSend)(
                    appController,
                    applicationsSelector
                );

        if (![applications
                isKindOfClass:[NSArray class]]) {
            return;
        }

        Class FBSystemService =
            objc_getClass("FBSystemService");

        if (FBSystemService == Nil) {
            return;
        }

        SEL fbSharedSelector =
            NSSelectorFromString(@"sharedInstance");

        if (![FBSystemService
                respondsToSelector:fbSharedSelector]) {
            return;
        }

        id service =
            ((id (*)(id, SEL))
                objc_msgSend)(
                    FBSystemService,
                    fbSharedSelector
                );

        if (service == nil) {
            return;
        }

        SEL terminateSelector =
            NSSelectorFromString(
                @"terminateApplication:forReason:andReport:");

        if (![service
                respondsToSelector:terminateSelector]) {
            return;
        }

        for (id application in applications) {

            @autoreleasepool {

                SEL bundleIdentifierSelector =
                    NSSelectorFromString(
                        @"bundleIdentifier");

                if (![application
                        respondsToSelector:
                            bundleIdentifierSelector]) {
                    continue;
                }

                NSString *bundleIdentifier =
                    ((id (*)(id, SEL))
                        objc_msgSend)(
                            application,
                            bundleIdentifierSelector
                        );

                if (bundleIdentifier.length == 0) {
                    continue;
                }

                /*
                 * Không đóng SpringBoard.
                 */
                if ([bundleIdentifier
                        isEqualToString:
                            @"com.apple.springboard"]) {
                    continue;
                }

                /*
                 * Không đóng Settings.
                 */
                if ([bundleIdentifier
                        isEqualToString:
                            @"com.apple.Preferences"]) {
                    continue;
                }

                /*
                 * Không đóng các process WebKit/Safari
                 * hệ thống.
                 */
                if ([bundleIdentifier
                        hasPrefix:
                            @"com.apple.SafariViewService"]) {
                    continue;
                }

                if ([bundleIdentifier
                        hasPrefix:@"com.apple.WebKit"]) {
                    continue;
                }

                ((void (*)(id, SEL, id, int, BOOL))
                    objc_msgSend)(
                        service,
                        terminateSelector,
                        application,
                        5,
                        NO
                    );
            }
        }
    }
}

@end
