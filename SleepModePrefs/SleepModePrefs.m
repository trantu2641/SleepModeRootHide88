#import "SleepManager.h"

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

static NSString * const SMEnabledKey =
    @"SleepModeEnabled";

static NSString * const SMTimeoutKey =
    @"SleepModeTimeout";

static SleepManager *gSharedManager = nil;

@interface SleepManager ()

@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, assign) BOOL started;

@end

@implementation SleepManager

+ (instancetype)sharedInstance
{
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        gSharedManager = [[self alloc] init];
    });

    return gSharedManager;
}

- (instancetype)init
{
    self = [super init];

    if (self) {

        _enabled = YES;
        _timeout = 15.0;
        _started = NO;

        [self loadPreferences];
    }

    return self;
}

#pragma mark - Preferences

- (NSUserDefaults *)preferences
{
    /*
     * QUAN TRỌNG:
     * Core 1.3.0 dùng standardUserDefaults.
     */
    return [NSUserDefaults standardUserDefaults];
}

- (void)loadPreferences
{
    NSUserDefaults *defaults =
        [self preferences];

    if ([defaults objectForKey:SMEnabledKey] != nil) {

        _enabled =
            [defaults boolForKey:SMEnabledKey];
    }

    if ([defaults objectForKey:SMTimeoutKey] != nil) {

        NSTimeInterval value =
            [defaults doubleForKey:SMTimeoutKey];

        if (value >= 15.0 &&
            value <= 7200.0) {

            _timeout = value;
        }
    }
}

- (void)reloadPreferences
{
    [self stop];

    [self loadPreferences];

    if (self.enabled) {
        [self start];
    }
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
        [self preferences];

    [defaults setBool:
        enabled
        forKey:
            SMEnabledKey];

    [defaults synchronize];

    if (enabled) {
        [self start];
    } else {
        [self stop];
    }
}

#pragma mark - Timeout

- (NSTimeInterval)timeout
{
    return _timeout;
}

- (void)setTimeout:(NSTimeInterval)timeout
{
    if (timeout < 15.0 ||
        timeout > 7200.0) {

        timeout = 15.0;
    }

    _timeout = timeout;

    NSUserDefaults *defaults =
        [self preferences];

    [defaults setDouble:
        timeout
        forKey:
            SMTimeoutKey];

    [defaults synchronize];

    if (self.enabled) {
        [self start];
    }
}

#pragma mark - Timer

- (void)start
{
    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            [self stop];

            if (!self.enabled) {
                return;
            }

            NSTimeInterval timeout =
                self.timeout;

            if (timeout < 15.0) {
                timeout = 15.0;
            }

            self.timer =
            [NSTimer scheduledTimerWithTimeInterval:
                timeout
                target:self
                selector:@selector(timerFired:)
                userInfo:nil
                repeats:NO];

            self.started =
                (self.timer != nil);
        }
    );
}

- (void)stop
{
    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            if (self.timer != nil) {

                [self.timer invalidate];
                self.timer = nil;
            }

            self.started = NO;
        }
    );
}

- (void)resetTimer
{
    if (!self.enabled) {
        return;
    }

    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            if (!self.enabled) {
                return;
            }

            if (self.timer != nil) {

                [self.timer invalidate];
                self.timer = nil;
            }

            NSTimeInterval timeout =
                self.timeout;

            if (timeout < 15.0) {
                timeout = 15.0;
            }

            self.timer =
            [NSTimer scheduledTimerWithTimeInterval:
                timeout
                target:self
                selector:@selector(timerFired:)
                userInfo:nil
                repeats:NO];

            self.started =
                (self.timer != nil);
        }
    );
}

- (void)timerFired:(NSTimer *)timer
{
    if (!self.enabled) {
        return;
    }

    self.timer = nil;
    self.started = NO;

    [self terminateUserApps];

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)(0.15 *
                      NSEC_PER_SEC)
        ),
        dispatch_get_main_queue(),
        ^{

            if (self.enabled) {
                [self lockDevice];
            }
        }
    );
}

#pragma mark - Terminate applications

- (void)terminateUserApps
{
    @try {

        Class SBApplicationController =
            NSClassFromString(
                @"SBApplicationController"
            );

        Class FBSystemService =
            NSClassFromString(
                @"FBSystemService"
            );

        if (!SBApplicationController ||
            !FBSystemService) {

            return;
        }

        id applicationController =
            [SBApplicationController
                respondsToSelector:
                    @selector(sharedInstance)]
            ?
            ((id (*)(id, SEL))objc_msgSend)(
                SBApplicationController,
                @selector(sharedInstance)
            )
            :
            nil;

        id systemService =
            [FBSystemService
                respondsToSelector:
                    @selector(sharedInstance)]
            ?
            ((id (*)(id, SEL))objc_msgSend)(
                FBSystemService,
                @selector(sharedInstance)
            )
            :
            nil;

        if (!applicationController ||
            !systemService) {

            return;
        }

        SEL allApplicationsSelector =
            NSSelectorFromString(
                @"allApplications"
            );

        if (![applicationController
              respondsToSelector:
                  allApplicationsSelector]) {

            return;
        }

        NSArray *applications =
            ((id (*)(id, SEL))objc_msgSend)(
                applicationController,
                allApplicationsSelector
            );

        if (![applications
              isKindOfClass:
                  [NSArray class]]) {

            return;
        }

        SEL terminateSelector =
            NSSelectorFromString(
                @"terminateApplication:forReason:andReport:"
            );

        if (![systemService
              respondsToSelector:
                  terminateSelector]) {

            return;
        }

        SEL bundleIdentifierSelector =
            NSSelectorFromString(
                @"bundleIdentifier"
            );

        for (id application in applications) {

            @autoreleasepool {

                NSString *bundleIdentifier = nil;

                if ([application
                     respondsToSelector:
                         bundleIdentifierSelector]) {

                    bundleIdentifier =
                        ((id (*)(id, SEL))objc_msgSend)(
                            application,
                            bundleIdentifierSelector
                        );
                }

                if (![bundleIdentifier
                      isKindOfClass:
                          [NSString class]]) {

                    continue;
                }

                if ([bundleIdentifier
                     isEqualToString:
                         @"com.apple.springboard"]) {

                    continue;
                }

                if ([bundleIdentifier
                     isEqualToString:
                         @"com.apple.Preferences"]) {

                    continue;
                }

                if ([bundleIdentifier
                     hasPrefix:
                         @"com.apple.SafariViewService"]) {

                    continue;
                }

                if ([bundleIdentifier
                     hasPrefix:
                         @"com.apple.WebKit"]) {

                    continue;
                }

                ((void (*)(id, SEL, id, NSInteger, BOOL))
                    objc_msgSend)(
                        systemService,
                        terminateSelector,
                        bundleIdentifier,
                        1,
                        NO
                    );
            }
        }
    }
    @catch (NSException *exception) {

        NSLog(
            @"[SleepMode] terminateUserApps exception: %@",
            exception
        );
    }
}

#pragma mark - Lock

- (void)lockDevice
{
    @try {

        Class SBBackBoardController =
            NSClassFromString(
                @"SBBackBoardController"
            );

        if (SBBackBoardController) {

            SEL sharedSelector =
                NSSelectorFromString(
                    @"sharedInstance"
                );

            SEL lockSelector =
                NSSelectorFromString(
                    @"lockScreen"
                );

            if ([SBBackBoardController
                 respondsToSelector:
                     sharedSelector]) {

                id controller =
                    ((id (*)(id, SEL))objc_msgSend)(
                        SBBackBoardController,
                        sharedSelector
                    );

                if (controller &&
                    [controller
                     respondsToSelector:
                         lockSelector]) {

                    ((void (*)(id, SEL))objc_msgSend)(
                        controller,
                        lockSelector
                    );

                    return;
                }
            }
        }
    }
    @catch (NSException *exception) {

        NSLog(
            @"[SleepMode] BackBoard lock exception: %@",
            exception
        );
    }

    @try {

        UIApplication *application =
            [UIApplication sharedApplication];

        SEL lockSelector =
            NSSelectorFromString(
                @"_lockScreen"
            );

        if ([application
             respondsToSelector:
                 lockSelector]) {

            ((void (*)(id, SEL))objc_msgSend)(
                application,
                lockSelector
            );
        }
    }
    @catch (NSException *exception) {

        NSLog(
            @"[SleepMode] fallback lock exception: %@",
            exception
        );
    }
}

@end
