#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

static NSString * const kPrefsPath =
    @"/var/mobile/Library/Preferences/com.trantu.sleepmode.plist";

static NSString * const kSettingsChangedNotification =
    @"com.trantu.sleepmode.settingsChanged";

static NSString * const kEnabledKey = @"SleepModeEnabled";
static NSString * const kTimeoutKey = @"SleepModeTimeout";

static id SMSharedManager(void)
{
    Class managerClass = objc_getClass("SleepManager");
    if (managerClass == Nil) {
        NSLog(@"[SleepModeSettingsBridge] Core SleepManager not loaded");
        return nil;
    }

    SEL selector = @selector(sharedInstance);
    if (![managerClass respondsToSelector:selector]) {
        NSLog(@"[SleepModeSettingsBridge] sharedInstance selector missing");
        return nil;
    }

    return ((id (*)(id, SEL))objc_msgSend)(managerClass, selector);
}

static void SMApplySettings(void)
{
    id manager = SMSharedManager();
    if (manager == nil) return;

    NSDictionary *settings =
        [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];

    BOOL enabled = YES;
    NSTimeInterval timeout = 15.0;

    if ([settings isKindOfClass:[NSDictionary class]]) {
        id enabledValue = settings[kEnabledKey];
        id timeoutValue = settings[kTimeoutKey];

        if ([enabledValue isKindOfClass:[NSNumber class]]) {
            enabled = [enabledValue boolValue];
        }

        if ([timeoutValue isKindOfClass:[NSNumber class]]) {
            NSTimeInterval candidate = [timeoutValue doubleValue];
            if (candidate >= 1.0) timeout = candidate;
        }
    }

    SEL timeoutSelector = @selector(setTimeout:);
    if ([manager respondsToSelector:timeoutSelector]) {
        ((void (*)(id, SEL, NSTimeInterval))objc_msgSend)(
            manager, timeoutSelector, timeout
        );
    } else {
        NSLog(@"[SleepModeSettingsBridge] setTimeout: unavailable");
    }

    SEL enabledSelector = @selector(setEnabled:);
    if ([manager respondsToSelector:enabledSelector]) {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(
            manager, enabledSelector, enabled
        );
    } else {
        NSLog(@"[SleepModeSettingsBridge] setEnabled: unavailable");
    }

    NSLog(@"[SleepModeSettingsBridge] Applied Settings: enabled=%d timeout=%.1f",
          enabled, timeout);
}

static void SMSettingsChanged(
    CFNotificationCenterRef center,
    void *observer,
    CFStringRef name,
    const void *object,
    CFDictionaryRef userInfo
)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        SMApplySettings();
    });
}

%hook SpringBoard

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
    %orig(application);

    /* The original 1.1.0 dylib owns startup and touch tracking. */
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
        dispatch_get_main_queue(),
        ^{ SMApplySettings(); }
    );
}

%end

%ctor
{
    @autoreleasepool {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            SMSettingsChanged,
            (__bridge CFStringRef)kSettingsChangedNotification,
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );

        NSLog(@"[SleepModeSettingsBridge] Loaded");
    }
}
