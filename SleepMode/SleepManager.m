#import "SleepManager.h"

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
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

static NSString * const SMTouchNotification =
    @"com.trantu.sleepmode.touch";


@interface SleepManager ()

@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, assign) BOOL terminatingApps;
@property(nonatomic, assign) BOOL initialized;

@end


@implementation SleepManager


#pragma mark -
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


#pragma mark -
#pragma mark Init


- (instancetype)init
{
    self = [super init];

    if (self) {

        _enabled = YES;
        _timeout = 300.0;
        _terminatingApps = NO;
        _initialized = YES;

        [self loadPreferences];

        /*
         * Nhận thay đổi từ Settings ngay lập tức.
         */
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge const void *)(self),
            SMSettingsChangedCallback,
            (__bridge CFStringRef)SMSettingsChangedNotification,
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );

        /*
         * Giữ cơ chế touch notification.
         */
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge const void *)(self),
            SMTouchCallback,
            (__bridge CFStringRef)SMTouchNotification,
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );
    }

    return self;
}


- (void)dealloc
{
    CFNotificationCenterRemoveObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge const void *)(self),
        (__bridge CFStringRef)SMSettingsChangedNotification,
        NULL
    );

    CFNotificationCenterRemoveObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge const void *)(self),
        (__bridge CFStringRef)SMTouchNotification,
        NULL
    );

    [_timer invalidate];
    _timer = nil;
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
     * Enabled
     */

    if ([defaults objectForKey:SMEnabledKey] != nil) {

        self.enabled =
            [defaults boolForKey:SMEnabledKey];
    }


    /*
     * Timeout
     *
     * Cho phép từ 1 giây trở lên.
     *
     * Quan trọng:
     * 15 giây phải được đọc bình thường.
     */

    if ([defaults objectForKey:SMTimeoutKey] != nil) {

        NSTimeInterval value =
            [defaults doubleForKey:SMTimeoutKey];

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
    /*
     * Chỉ thực hiện trên main thread.
     */

    if (![NSThread isMainThread]) {

        dispatch_async(
            dispatch_get_main_queue(),
            ^{

                [self reloadPreferences];
            }
        );

        return;
    }


    [self stop];

    [self loadPreferences];


    if (self.enabled) {

        [self start];
    }
}


#pragma mark -
#pragma mark Timer


- (void)start
{
    if (![NSThread isMainThread]) {

        dispatch_async(
            dispatch_get_main_queue(),
            ^{

                [self start];
            }
        );

        return;
    }


    [self stop];


    if (!self.enabled) {

        NSLog(
            @"[SleepMode] start ignored: disabled"
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


    self.timer =
        [NSTimer timerWithTimeInterval:timeout
                                target:self
                              selector:@selector(timerFired:)
                              userInfo:nil
                               repeats:NO];


    /*
     * NSRunLoopCommonModes để timer không bị treo
     * khi SpringBoard chuyển mode.
     */
    [[NSRunLoop mainRunLoop]
        addTimer:self.timer
        forMode:NSRunLoopCommonModes];
}


- (void)stop
{
    if (![NSThread isMainThread]) {

        dispatch_async(
            dispatch_get_main_queue(),
            ^{

                [self stop];
            }
        );

        return;
    }


    if (self.timer) {

        NSLog(
            @"[SleepMode] STOP timer"
        );

        [self.timer invalidate];

        self.timer = nil;
    }
}


- (void)resetTimer
{
    if (!self.enabled) {

        return;
    }


    if (![NSThread isMainThread]) {

        dispatch_async(
            dispatch_get_main_queue(),
            ^{

                [self resetTimer];
            }
        );

        return;
    }


    NSLog(
        @"[SleepMode] touch -> reset timer"
    );


    [self stop];

    [self start];
}


#pragma mark -
#pragma mark Timer Fired


- (void)timerFired:(NSTimer *)timer
{
    if (!self.enabled) {

        return;
    }


    self.timer = nil;


    NSLog(
        @"[SleepMode] TIMER FIRED"
    );


    /*
     * Giữ nguyên thứ tự:
     *
     * 1. Đóng app
     * 2. Chờ 0.15 giây
     * 3. Khóa máy
     */

    [self terminateUserApps];


    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)(0.15 * NSEC_PER_SEC)
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


#pragma mark -
#pragma mark Terminate Applications


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
                @"[SleepMode] required classes not found"
            );

            self.terminatingApps = NO;

            return;
        }


        SEL sharedSelector =
            NSSelectorFromString(
                @"sharedInstance"
            );


        id applicationController = nil;

        id systemService = nil;


        if ([SBApplicationController
             respondsToSelector:sharedSelector]) {

            applicationController =
                ((id (*)(id, SEL))objc_msgSend)(
                    SBApplicationController,
                    sharedSelector
                );
        }


        if ([FBSystemService
             respondsToSelector:sharedSelector]) {

            systemService =
                ((id (*)(id, SEL))objc_msgSend)(
                    FBSystemService,
                    sharedSelector
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

            NSLog(
                @"[SleepMode] allApplications unavailable"
            );

            self.terminatingApps = NO;

            return;
        }


        NSArray *applications =
            ((id (*)(id, SEL))objc_msgSend)(
                applicationController,
                allApplicationsSelector
            );


        if (![applications isKindOfClass:
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
                 * Không đóng WebKit helper.
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

                    NSLog(
                        @"[SleepMode] lock via SBBackBoardController"
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
            [UIApplication sharedApplication];


        SEL lockSelector =
            NSSelectorFromString(
                @"_lockScreen"
            );


        if ([application
             respondsToSelector:
             lockSelector]) {

            NSLog(
                @"[SleepMode] lock via UIApplication"
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
