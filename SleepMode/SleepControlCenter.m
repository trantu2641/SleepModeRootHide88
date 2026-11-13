#import "SleepManager.h"

#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>


static NSString * const SMPreferencesDomain =
    @"com.trantu.sleepmode";

static NSString * const SMEnabledKey =
    @"SleepModeEnabled";

static NSString * const SMTimeoutKey =
    @"SleepModeTimeout";

static NSString * const SMSettingsChangedNotification =
    @"com.trantu.sleepmode.settingsChanged";


static SleepManager *gSharedManager = nil;


@interface SleepManager ()

@property(nonatomic, strong) dispatch_source_t timerSource;
@property(nonatomic, assign) BOOL terminatingApps;

@end


@implementation SleepManager


#pragma mark -
#pragma mark Singleton


+ (instancetype)sharedInstance
{
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        gSharedManager = [[self alloc] init];
    });

    return gSharedManager;
}


#pragma mark -
#pragma mark Init


- (instancetype)init
{
    self = [super init];

    if (self) {

        _enabled = NO;
        _timeout = 300.0;

        [self loadPreferences];


        /*
         * Nhận thay đổi từ Settings.
         */
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge const void *)(self),
            SMSettingsChangedCallback,
            CFSTR("com.trantu.sleepmode.settingsChanged"),
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );
    }

    return self;
}


#pragma mark -
#pragma mark Preferences


- (NSUserDefaults *)preferences
{
    return [[NSUserDefaults alloc]
        initWithSuiteName:SMPreferencesDomain];
}


- (void)loadPreferences
{
    NSUserDefaults *defaults =
        [self preferences];


    /*
     * Nếu chưa có key thì giữ mặc định:
     *
     * SleepMode = OFF
     * Timeout = 5 phút
     */
    if ([defaults objectForKey:SMEnabledKey] != nil) {

        self.enabled =
            [defaults boolForKey:SMEnabledKey];

    } else {

        self.enabled = NO;
    }


    if ([defaults objectForKey:SMTimeoutKey] != nil) {

        NSTimeInterval timeout =
            [defaults doubleForKey:SMTimeoutKey];

        if (timeout >= 1.0) {
            self.timeout = timeout;
        }

    } else {

        self.timeout = 300.0;
    }
}


#pragma mark -
#pragma mark Start


- (void)start
{
    [self stop];


    if (!self.enabled) {
        NSLog(@"[SleepMode] disabled");
        return;
    }


    NSTimeInterval timeout =
        self.timeout;


    if (timeout < 1.0) {
        timeout = 60.0;
    }


    NSLog(
        @"[SleepMode] START timer = %.0f seconds",
        timeout
    );


    dispatch_queue_t queue =
        dispatch_get_main_queue();


    dispatch_source_t source =
        dispatch_source_create(
            DISPATCH_SOURCE_TYPE_TIMER,
            0,
            0,
            queue
        );


    if (!source) {
        NSLog(@"[SleepMode] ERROR: cannot create timer");
        return;
    }


    self.timerSource = source;


    uint64_t delay =
        (uint64_t)(timeout * NSEC_PER_SEC);


    dispatch_source_set_timer(
        source,
        dispatch_time(
            DISPATCH_TIME_NOW,
            delay
        ),
        DISPATCH_TIME_FOREVER,
        100 * NSEC_PER_MSEC
    );


    __weak SleepManager *weakSelf =
        self;


    dispatch_source_set_event_handler(
        source,
        ^{

            SleepManager *strongSelf =
                weakSelf;

            if (!strongSelf) {
                return;
            }


            NSLog(
                @"[SleepMode] TIMER FIRED"
            );


            dispatch_source_t currentSource =
                strongSelf.timerSource;

            strongSelf.timerSource = nil;


            if (currentSource) {
                dispatch_source_cancel(
                    currentSource
                );
            }


            if (!strongSelf.enabled) {
                return;
            }


            [strongSelf timerFired];
        }
    );


    dispatch_resume(source);
}


#pragma mark -
#pragma mark Stop


- (void)stop
{
    dispatch_source_t source =
        self.timerSource;


    self.timerSource = nil;


    if (source) {

        NSLog(
            @"[SleepMode] STOP timer"
        );

        dispatch_source_cancel(source);
    }
}


#pragma mark -
#pragma mark Reset


- (void)resetTimer
{
    if (!self.enabled) {
        return;
    }


    NSLog(
        @"[SleepMode] RESET timer"
    );


    [self start];
}


#pragma mark -
#pragma mark Settings Changed


- (void)reloadPreferences
{
    NSLog(
        @"[SleepMode] Reload preferences"
    );


    [self stop];


    [self loadPreferences];


    NSLog(
        @"[SleepMode] enabled=%d timeout=%.0f",
        self.enabled,
        self.timeout
    );


    if (self.enabled) {
        [self start];
    }
}


#pragma mark -
#pragma mark Timer Fired


- (void)timerFired
{
    if (!self.enabled) {
        return;
    }


    NSLog(
        @"[SleepMode] AUTO LOCK"
    );


    /*
     * Giữ nguyên thứ tự:
     *
     * 1. Đóng app
     * 2. Chờ 0.15 giây
     * 3. Khóa iPhone
     */

    [self terminateUserApps];


    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)(0.15 * NSEC_PER_SEC)
        ),
        dispatch_get_main_queue(),
        ^{

            if (self.enabled) {

                [self lockDevice];
            }
        }
    );
}


#pragma mark -
#pragma mark Terminate Apps


- (void)terminateUserApps
{
    if (self.terminatingApps) {
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
                @"[SleepMode] SpringBoard classes unavailable"
            );

            self.terminatingApps = NO;
            return;
        }


        id applicationController = nil;

        if ([SBApplicationController
             respondsToSelector:
             @selector(sharedInstance)]) {

            applicationController =
                ((id (*)(id, SEL))
                 objc_msgSend)(
                    SBApplicationController,
                    @selector(sharedInstance)
                );
        }


        id systemService = nil;

        if ([FBSystemService
             respondsToSelector:
             @selector(sharedInstance)]) {

            systemService =
                ((id (*)(id, SEL))
                 objc_msgSend)(
                    FBSystemService,
                    @selector(sharedInstance)
                );
        }


        if (!applicationController ||
            !systemService) {

            NSLog(
                @"[SleepMode] services unavailable"
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

                NSString *bundleIdentifier =
                    nil;


                SEL bundleIdentifierSelector =
                    NSSelectorFromString(
                        @"bundleIdentifier"
                    );


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


                if (![bundleIdentifier
                     isKindOfClass:
                     [NSString class]]) {

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
                 * Không đóng SafariViewService.
                 */

                if ([bundleIdentifier
                     hasPrefix:
                     @"com.apple.SafariViewService"]) {

                    continue;
                }


                /*
                 * Không đóng WebKit.
                 */

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


#pragma mark -
#pragma mark Lock Device


- (void)lockDevice
{
    NSLog(
        @"[SleepMode] LOCK DEVICE"
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

                    ((void (*)(id, SEL))
                        objc_msgSend)(
                            controller,
                            lockSelector
                        );

                    NSLog(
                        @"[SleepMode] lockScreen OK"
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
            [UIApplication sharedApplication];


        SEL lockSelector =
            NSSelectorFromString(
                @"_lockScreen"
            );


        if ([application
             respondsToSelector:
             lockSelector]) {

            ((void (*)(id, SEL))
                objc_msgSend)(
                    application,
                    lockSelector
                );


            NSLog(
                @"[SleepMode] fallback lock OK"
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
#pragma mark Darwin Notification


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


    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            [manager reloadPreferences];
        }
    );
}
