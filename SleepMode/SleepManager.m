#import "SleepManager.h"

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>


#pragma mark -
#pragma mark Constants

static NSString * const SMPreferencesDomain =
    @"com.trantu.sleepmode";

static NSString * const SMEnabledKey =
    @"SleepModeEnabled";

static NSString * const SMTimeoutKey =
    @"SleepModeTimeout";

static NSString * const SMSettingsChangedNotification =
    @"com.trantu.sleepmode.settingsChanged";

static NSString * const SMTouchNotification =
    @"com.trantu.sleepmode.touch";


#pragma mark -
#pragma mark Forward Declarations

static void SMSettingsChangedCallback(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo
);

static void SMTouchCallback(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo
);


#pragma mark -
#pragma mark Interface

@interface SleepManager ()

@property(nonatomic, assign) dispatch_source_t timerSource;
@property(nonatomic, assign) BOOL terminatingApps;

@end


#pragma mark -
#pragma mark Implementation

@implementation SleepManager


#pragma mark Singleton

+ (instancetype)sharedInstance
{
    static SleepManager *instance = nil;

    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });

    return instance;
}


#pragma mark Init

- (instancetype)init
{
    self = [super init];

    if (self) {

        _enabled = YES;
        _timeout = 300.0;
        _terminatingApps = NO;
        _timerSource = nil;

        [self loadPreferences];


        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge const void *)(self),
            SMSettingsChangedCallback,
            (__bridge CFStringRef)
                SMSettingsChangedNotification,
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );


        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge const void *)(self),
            SMTouchCallback,
            (__bridge CFStringRef)
                SMTouchNotification,
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );


        NSLog(
            @"[SleepMode] manager initialized"
        );
    }

    return self;
}


- (void)dealloc
{
    [self stop];


    CFNotificationCenterRemoveObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge const void *)(self),
        (__bridge CFStringRef)
            SMSettingsChangedNotification,
        NULL
    );


    CFNotificationCenterRemoveObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge const void *)(self),
        (__bridge CFStringRef)
            SMTouchNotification,
        NULL
    );
}


#pragma mark Preferences

- (NSUserDefaults *)preferences
{
    return [[NSUserDefaults alloc]
        initWithSuiteName:
            SMPreferencesDomain];
}


- (void)loadPreferences
{
    NSUserDefaults *defaults =
        [self preferences];


    if ([defaults objectForKey:
         SMEnabledKey] != nil) {

        self.enabled =
            [defaults boolForKey:
                SMEnabledKey];
    }


    if ([defaults objectForKey:
         SMTimeoutKey] != nil) {

        NSTimeInterval value =
            [defaults doubleForKey:
                SMTimeoutKey];


        /*
         * Cho phép 15 giây.
         */

        if (value >= 1.0) {

            self.timeout =
                value;
        }
    }


    NSLog(
        @"[SleepMode] preferences: enabled=%@ timeout=%.0f",
        self.enabled ? @"YES" : @"NO",
        self.timeout
    );
}


- (void)reloadPreferences
{
    if (![NSThread isMainThread]) {

        dispatch_async(
            dispatch_get_main_queue(),
            ^{

                [self reloadPreferences];
            }
        );

        return;
    }


    NSLog(
        @"[SleepMode] reload preferences"
    );


    [self stop];

    [self loadPreferences];


    if (self.enabled) {

        [self start];
    }
}


#pragma mark Timer

- (void)start
{
    if (!self.enabled) {

        NSLog(
            @"[SleepMode] start: disabled"
        );

        return;
    }


    NSTimeInterval timeout =
        self.timeout;


    if (timeout < 1.0) {

        timeout = 15.0;
    }


    NSLog(
        @"[SleepMode] START timer = %.0f seconds",
        timeout
    );


    [self stop];


    dispatch_queue_t queue =
        dispatch_get_main_queue();


    dispatch_source_t timer =
        dispatch_source_create(
            DISPATCH_SOURCE_TYPE_TIMER,
            0,
            0,
            queue
        );


    if (!timer) {

        NSLog(
            @"[SleepMode] ERROR: timer creation failed"
        );

        return;
    }


    self.timerSource =
        timer;


    uint64_t delay =
        (uint64_t)(
            timeout *
            (double)NSEC_PER_SEC
        );


    dispatch_source_set_timer(
        timer,
        dispatch_time(
            DISPATCH_TIME_NOW,
            delay
        ),
        DISPATCH_TIME_FOREVER,
        0
    );


    __weak SleepManager *weakSelf =
        self;


    dispatch_source_set_event_handler(
        timer,
        ^{

            SleepManager *strongSelf =
                weakSelf;


            if (!strongSelf) {

                return;
            }


            NSLog(
                @"[SleepMode] TIMER FIRED"
            );


            strongSelf.timerSource = nil;


            [strongSelf timerFired];
        }
    );


    dispatch_resume(timer);


    NSLog(
        @"[SleepMode] TIMER RUNNING"
    );
}


- (void)stop
{
    dispatch_source_t timer =
        self.timerSource;


    if (!timer) {

        return;
    }


    self.timerSource = nil;


    NSLog(
        @"[SleepMode] STOP timer"
    );


    dispatch_source_cancel(timer);
}


- (void)resetTimer
{
    if (!self.enabled) {

        return;
    }


    NSLog(
        @"[SleepMode] reset timer"
    );


    [self start];
}


#pragma mark Timer Fired

- (void)timerFired
{
    if (!self.enabled) {

        NSLog(
            @"[SleepMode] timer fired but disabled"
        );

        return;
    }


    NSLog(
        @"[SleepMode] TIMER FIRED -> terminate apps"
    );


    [self terminateUserApps];


    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)
                (0.15 *
                 NSEC_PER_SEC)
        ),
        dispatch_get_main_queue(),
        ^{

            if (!self.enabled) {

                return;
            }


            NSLog(
                @"[SleepMode] AUTO LOCK"
            );


            [self lockDevice];
        }
    );
}


#pragma mark Terminate Applications

- (void)terminateUserApps
{
    if (self.terminatingApps) {

        NSLog(
            @"[SleepMode] terminate already running"
        );

        return;
    }


    self.terminatingApps = YES;


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

            NSLog(
                @"[SleepMode] SB/FB classes unavailable"
            );

            self.terminatingApps = NO;

            return;
        }


        SEL sharedSelector =
            NSSelectorFromString(
                @"sharedInstance"
            );


        id applicationController =
            nil;


        id systemService =
            nil;


        if ([SBApplicationController
             respondsToSelector:
             sharedSelector]) {

            applicationController =
                ((id (*)(id, SEL))
                    objc_msgSend)(
                        SBApplicationController,
                        sharedSelector
                    );
        }


        if ([FBSystemService
             respondsToSelector:
             sharedSelector]) {

            systemService =
                ((id (*)(id, SEL))
                    objc_msgSend)(
                        FBSystemService,
                        sharedSelector
                    );
        }


        if (!applicationController ||
            !systemService) {

            NSLog(
                @"[SleepMode] SB/FB services unavailable"
            );

            self.terminatingApps = NO;

            return;
        }


        SEL allApplicationsSelector =
            NSSelectorFromString(
                @"allApplications"
            );


        if (![applicationController
              respondsToSelector:
              allApplicationsSelector]) {

            NSLog(
                @"[SleepMode] allApplications unavailable"
            );

            self.terminatingApps = NO;

            return;
        }


        NSArray *applications =
            ((id (*)(id, SEL))
                objc_msgSend)(
                    applicationController,
                    allApplicationsSelector
                );


        if (![applications
              isKindOfClass:
              [NSArray class]]) {

            NSLog(
                @"[SleepMode] invalid applications array"
            );

            self.terminatingApps = NO;

            return;
        }


        SEL terminateSelector =
            NSSelectorFromString(
                @"terminateApplication:forReason:andReport:"
            );


        if (![systemService
              respondsToSelector:
              terminateSelector]) {

            NSLog(
                @"[SleepMode] terminate selector unavailable"
            );

            self.terminatingApps = NO;

            return;
        }


        for (id application
             in applications) {

            @autoreleasepool {

                SEL bundleIdentifierSelector =
                    NSSelectorFromString(
                        @"bundleIdentifier"
                    );


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


                NSLog(
                    @"[SleepMode] terminate %@",
                    bundleIdentifier
                );


                ((void (*)(id,
                           SEL,
                           id,
                           NSInteger,
                           BOOL))
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
            @"[SleepMode] terminate exception: %@",
            exception
        );
    }


    self.terminatingApps = NO;
}


#pragma mark Lock Device

- (void)lockDevice
{
    NSLog(
        @"[SleepMode] lockDevice()"
    );


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
                    ((id (*)(id, SEL))
                        objc_msgSend)(
                            SBBackBoardController,
                            sharedSelector
                        );


                if (controller &&
                    [controller
                     respondsToSelector:
                     lockSelector]) {

                    NSLog(
                        @"[SleepMode] locking via BackBoard"
                    );


                    ((void (*)(id, SEL))
                        objc_msgSend)(
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


    /*
     * Fallback.
     */

    @try {

        UIApplication *application =
            [UIApplication
                sharedApplication];


        SEL lockSelector =
            NSSelectorFromString(
                @"_lockScreen"
            );


        if ([application
             respondsToSelector:
             lockSelector]) {

            NSLog(
                @"[SleepMode] locking via UIApplication"
            );


            ((void (*)(id, SEL))
                objc_msgSend)(
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


#pragma mark -
#pragma mark Darwin Callbacks

static void SMSettingsChangedCallback(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo
)
{
    SleepManager *manager =
        (__bridge SleepManager *)observer;


    if (!manager) {

        return;
    }


    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            [manager reloadPreferences];
        }
    );
}


static void SMTouchCallback(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo
)
{
    SleepManager *manager =
        (__bridge SleepManager *)observer;


    if (!manager) {

        return;
    }


    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            [manager resetTimer];
        }
    );
}
