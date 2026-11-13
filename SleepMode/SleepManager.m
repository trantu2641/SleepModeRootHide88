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

static void SMSettingsChangedCallback(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo
);

@interface SleepManager ()

@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, assign) BOOL terminatingApps;

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

        /*
         * Giữ cơ chế core cũ.
         * Chỉ thay giá trị mặc định từ 300s -> 15s.
         */
        _enabled = YES;
        _timeout = 15.0;

        [self loadPreferences];

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

- (NSUserDefaults *)preferences
{
    return [[NSUserDefaults alloc]
        initWithSuiteName:SMPreferencesDomain];
}

- (void)loadPreferences
{
    NSUserDefaults *defaults = [self preferences];

    if ([defaults objectForKey:SMEnabledKey] != nil) {
        self.enabled =
            [defaults boolForKey:SMEnabledKey];
    }

    if ([defaults objectForKey:SMTimeoutKey] != nil) {

        NSTimeInterval value =
            [defaults doubleForKey:SMTimeoutKey];

        /*
         * Cho phép toàn bộ các giá trị menu:
         *
         * 15
         * 60
         * 300
         * 900
         * 1800
         * 3600
         * 7200
         */
        if (value >= 15.0 &&
            value <= 7200.0) {

            self.timeout = value;
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
        }
    );
}

- (void)stop
{
    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            if (self.timer) {
                [self.timer invalidate];
                self.timer = nil;
            }
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

            if (self.timer) {
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
        }
    );
}

- (void)timerFired:(NSTimer *)timer
{
    if (!self.enabled) {
        return;
    }

    self.timer = nil;

    /*
     * Đúng thứ tự core cũ:
     *
     * 1. Đóng app người dùng
     * 2. Chờ 0.15s
     * 3. Khóa máy
     */
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

            self.terminatingApps = NO;
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
            ((id (*)(id, SEL))objc_msgSend)(
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

            self.terminatingApps = NO;
            return;
        }

        for (id application in applications) {

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
                 * Không tự đóng SpringBoard.
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
                 * Không đóng các process dịch vụ
                 * được core cũ bỏ qua.
                 */
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

                /*
                 * Quan trọng:
                 * truyền bundleIdentifier,
                 * không truyền object application.
                 */
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

#pragma mark - Settings notification

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
