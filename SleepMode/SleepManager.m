#import "SleepManager.h"

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
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

static void SMSettingsChangedCallback(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo
);

@interface SleepManager ()

@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, assign) BOOL started;
@property(nonatomic, assign) BOOL terminatingApps;

- (void)loadPreferences;
- (void)reloadPreferences;
- (void)timerFired:(NSTimer *)timer;
- (void)terminateUserApps;

@end

@implementation SleepManager

@synthesize enabled = _enabled;
@synthesize timeout = _timeout;

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
        _timeout = 15.0;
        _started = NO;
        _terminatingApps = NO;

        [self loadPreferences];

        // Settings app báo thay đổi trực tiếp cho SpringBoard, không cần respring.
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge const void *)(self),
            SMSettingsChangedCallback,
            (__bridge CFStringRef)kSleepModeChangedNotification,
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );
    }

    return self;
}

- (void)dealloc
{
    [self.timer invalidate];
    self.timer = nil;

    CFNotificationCenterRemoveObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge const void *)(self),
        (__bridge CFStringRef)kSleepModeChangedNotification,
        NULL
    );
}

#pragma mark - Preferences

- (NSUserDefaults *)preferences
{
    return [[NSUserDefaults alloc] initWithSuiteName:kSleepModeDomain];
}

- (void)loadPreferences
{
    NSUserDefaults *defaults = [self preferences];

    if (defaults == nil) {
        _enabled = YES;
        _timeout = 15.0;
        return;
    }

    id enabledValue = [defaults objectForKey:kSleepModeEnabledKey];
    _enabled = (enabledValue != nil)
        ? [enabledValue boolValue]
        : YES;

    id timeoutValue = [defaults objectForKey:kSleepModeTimeoutKey];

    if (timeoutValue != nil) {
        NSTimeInterval value = [timeoutValue doubleValue];
        _timeout = (value >= 15.0 && value <= 7200.0)
            ? value
            : 15.0;
    } else {
        _timeout = 15.0;
    }
}

- (void)reloadPreferences
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.timer invalidate];
        self.timer = nil;
        self.started = NO;

        [self loadPreferences];

        if (self.enabled) {
            [self start];
        } else {
            [self stop];
        }
    });
}

#pragma mark - Properties

- (BOOL)isEnabled
{
    return _enabled;
}

- (void)setEnabled:(BOOL)enabled
{
    _enabled = enabled;

    NSUserDefaults *defaults = [self preferences];
    [defaults setBool:enabled forKey:kSleepModeEnabledKey];
    [defaults synchronize];

    if (enabled) {
        [self start];
    } else {
        [self stop];
    }
}

- (NSTimeInterval)timeout
{
    return _timeout;
}

- (void)setTimeout:(NSTimeInterval)timeout
{
    if (timeout < 15.0 || timeout > 7200.0) {
        timeout = 15.0;
    }

    _timeout = timeout;

    NSUserDefaults *defaults = [self preferences];
    [defaults setDouble:timeout forKey:kSleepModeTimeoutKey];
    [defaults synchronize];

    if (self.enabled) {
        [self start];
    }
}

#pragma mark - Timer (giữ cơ chế 1.3.0)

- (void)start
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.timer invalidate];
        self.timer = nil;
        self.started = NO;

        if (!self.enabled) {
            return;
        }

        NSTimeInterval timeout = self.timeout;
        if (timeout < 15.0 || timeout > 7200.0) {
            timeout = 15.0;
        }

        self.timer = [NSTimer timerWithTimeInterval:timeout
                                             target:self
                                           selector:@selector(timerFired:)
                                           userInfo:nil
                                            repeats:NO];

        if (self.timer == nil) {
            return;
        }

        // Giống bản cũ: timer được thêm vào main run loop ở common modes.
        [[NSRunLoop mainRunLoop] addTimer:self.timer
                                  forMode:NSRunLoopCommonModes];

        self.started = YES;
    });
}

- (void)stop
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.started = NO;

        [self.timer invalidate];
        self.timer = nil;
    });
}

- (void)resetTimer
{
    if (!self.enabled) {
        return;
    }

    // Mỗi touch ở SpringBoard hủy bộ đếm cũ và bắt đầu lại từ đầu.
    [self start];
}

- (void)timerFired:(NSTimer *)timer
{
    if (!self.enabled) {
        self.started = NO;
        self.timer = nil;
        return;
    }

    self.timer = nil;
    self.started = NO;

    // Thứ tự cũ: đóng app người dùng trước, sau đó mới khóa máy.
    [self terminateUserApps];

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW,
                      (int64_t)(0.15 * NSEC_PER_SEC)),
        dispatch_get_main_queue(),
        ^{
            if (self.enabled) {
                [self lockDevice];
            }
        }
    );
}

#pragma mark - Terminate user applications

- (void)terminateUserApps
{
    if (self.terminatingApps) {
        return;
    }

    self.terminatingApps = YES;

    @try {
        Class applicationControllerClass =
            NSClassFromString(@"SBApplicationController");

        Class systemServiceClass =
            NSClassFromString(@"FBSystemService");

        if (applicationControllerClass == Nil || systemServiceClass == Nil) {
            return;
        }

        SEL sharedInstanceSelector = NSSelectorFromString(@"sharedInstance");

        id applicationController = nil;
        if ([applicationControllerClass respondsToSelector:sharedInstanceSelector]) {
            applicationController =
                ((id (*)(id, SEL))objc_msgSend)(
                    applicationControllerClass,
                    sharedInstanceSelector
                );
        }

        id systemService = nil;
        if ([systemServiceClass respondsToSelector:sharedInstanceSelector]) {
            systemService =
                ((id (*)(id, SEL))objc_msgSend)(
                    systemServiceClass,
                    sharedInstanceSelector
                );
        }

        if (applicationController == nil || systemService == nil) {
            return;
        }

        SEL allApplicationsSelector =
            NSSelectorFromString(@"allApplications");

        if (![applicationController respondsToSelector:allApplicationsSelector]) {
            return;
        }

        NSArray *applications =
            ((id (*)(id, SEL))objc_msgSend)(
                applicationController,
                allApplicationsSelector
            );

        if (![applications isKindOfClass:[NSArray class]]) {
            return;
        }

        SEL terminateSelector = NSSelectorFromString(
            @"terminateApplication:forReason:andReport:"
        );

        if (![systemService respondsToSelector:terminateSelector]) {
            return;
        }

        SEL bundleIdentifierSelector = NSSelectorFromString(@"bundleIdentifier");

        for (id application in applications) {
            @autoreleasepool {
                if (![application respondsToSelector:bundleIdentifierSelector]) {
                    continue;
                }

                NSString *bundleIdentifier =
                    ((id (*)(id, SEL))objc_msgSend)(
                        application,
                        bundleIdentifierSelector
                    );

                if (![bundleIdentifier isKindOfClass:[NSString class]] ||
                    bundleIdentifier.length == 0) {
                    continue;
                }

                // Không tự đóng SpringBoard và màn hình Cài đặt đang thao tác.
                if ([bundleIdentifier isEqualToString:@"com.apple.springboard"] ||
                    [bundleIdentifier isEqualToString:@"com.apple.Preferences"] ||
                    [bundleIdentifier hasPrefix:@"com.apple.SafariViewService"] ||
                    [bundleIdentifier hasPrefix:@"com.apple.WebKit"]) {
                    continue;
                }

                ((void (*)(id, SEL, id, NSInteger, BOOL))objc_msgSend)(
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
        NSLog(@"[SleepMode] terminateUserApps exception: %@", exception);
    }
    @finally {
        self.terminatingApps = NO;
    }
}

#pragma mark - Lock device

- (void)lockDevice
{
    @try {
        Class backBoardControllerClass =
            NSClassFromString(@"SBBackBoardController");

        if (backBoardControllerClass != Nil) {
            SEL sharedInstanceSelector = NSSelectorFromString(@"sharedInstance");
            SEL lockSelector = NSSelectorFromString(@"lockScreen");

            if ([backBoardControllerClass respondsToSelector:sharedInstanceSelector]) {
                id controller =
                    ((id (*)(id, SEL))objc_msgSend)(
                        backBoardControllerClass,
                        sharedInstanceSelector
                    );

                if (controller != nil && [controller respondsToSelector:lockSelector]) {
                    ((void (*)(id, SEL))objc_msgSend)(controller, lockSelector);
                    return;
                }
            }
        }
    }
    @catch (NSException *exception) {
        NSLog(@"[SleepMode] BackBoard lock exception: %@", exception);
    }

    @try {
        UIApplication *application = [UIApplication sharedApplication];
        SEL lockSelector = NSSelectorFromString(@"_lockScreen");

        if ([application respondsToSelector:lockSelector]) {
            ((void (*)(id, SEL))objc_msgSend)(application, lockSelector);
        }
    }
    @catch (NSException *exception) {
        NSLog(@"[SleepMode] fallback lock exception: %@", exception);
    }
}

@end

#pragma mark - Darwin settings notification

static void SMSettingsChangedCallback(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo
)
{
    SleepManager *manager = (__bridge SleepManager *)observer;

    dispatch_async(dispatch_get_main_queue(), ^{
        [manager reloadPreferences];
    });
}
