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
{
    BOOL _enabled;
    NSTimeInterval _timeout;

    NSTimer *_timer;
    BOOL _started;
}

- (void)loadPreferences;
- (NSTimeInterval)currentTimeout;
- (void)handleSettingsChanged;

@end


@implementation SleepManager

#pragma mark - Singleton

+ (instancetype)sharedInstance
{
    static SleepManager *instance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });

    return instance;
}


#pragma mark - Init

- (instancetype)init
{
    self = [super init];

    if (self) {
        /*
         * Giữ mặc định 15 giây như bản 1.3.0.
         * Trạng thái bật/tắt mặc định đồng bộ với Settings mới.
         */
        _enabled = YES;
        _timeout = 15.0;
        _timer = nil;
        _started = NO;

        [self loadPreferences];

        /*
         * Settings chạy trong tiến trình riêng nên dùng Darwin
         * notification để báo SpringBoard đọc lại thiết lập.
         * Touch không đi qua notification này; touch gọi resetTimer
         * trực tiếp trong Tweak.xm như bản hoạt động 1.3.0.
         */
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
    if (_timer != nil) {
        [_timer invalidate];
        _timer = nil;
    }

    CFNotificationCenterRemoveObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge const void *)(self),
        (__bridge CFStringRef)kSleepModeChangedNotification,
        NULL
    );
}


#pragma mark - Preferences

- (void)loadPreferences
{
    /*
     * Settings bundle và SpringBoard phải đọc cùng một domain.
     * SleepModePrefs ghi vào suite com.trantu.sleepmode.
     */
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc] initWithSuiteName:kSleepModeDomain];

    if (defaults == nil) {
        _enabled = YES;
        _timeout = 15.0;
        return;
    }

    id enabledValue =
        [defaults objectForKey:kSleepModeEnabledKey];

    _enabled = (enabledValue != nil)
        ? [enabledValue boolValue]
        : YES;

    id timeoutValue =
        [defaults objectForKey:kSleepModeTimeoutKey];

    if (timeoutValue != nil) {
        NSTimeInterval timeout = [timeoutValue doubleValue];

        if (timeout >= 15.0 && timeout <= 7200.0) {
            _timeout = timeout;
        } else {
            _timeout = 15.0;
        }
    } else {
        _timeout = 15.0;
    }
}


- (NSTimeInterval)currentTimeout
{
    NSUserDefaults *defaults =
        [[NSUserDefaults alloc] initWithSuiteName:kSleepModeDomain];

    if (defaults == nil) {
        return 15.0;
    }

    id value = [defaults objectForKey:kSleepModeTimeoutKey];

    if (value == nil) {
        return 15.0;
    }

    NSTimeInterval timeout = [value doubleValue];

    if (timeout < 15.0 || timeout > 7200.0) {
        return 15.0;
    }

    return timeout;
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
        [[NSUserDefaults alloc] initWithSuiteName:kSleepModeDomain];

    if (defaults != nil) {
        [defaults setBool:enabled forKey:kSleepModeEnabledKey];
        [defaults synchronize];
    }

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
    if (timeout < 15.0) {
        timeout = 15.0;
    }

    if (timeout > 7200.0) {
        timeout = 7200.0;
    }

    _timeout = timeout;

    NSUserDefaults *defaults =
        [[NSUserDefaults alloc] initWithSuiteName:kSleepModeDomain];

    if (defaults != nil) {
        [defaults setDouble:timeout forKey:kSleepModeTimeoutKey];
        [defaults synchronize];
    }

    if (_enabled && _started) {
        [self start];
    }
}


#pragma mark - Start

- (void)start
{
    if (!_enabled) {
        return;
    }

    /*
     * Cơ chế timer giống bản 1.3.0:
     * hủy NSTimer cũ, tạo NSTimer một lần và đăng ký vào
     * NSRunLoopCommonModes để timer tiếp tục chạy trong SpringBoard.
     */
    if (_timer != nil) {
        [_timer invalidate];
        _timer = nil;
    }

    NSTimeInterval timeout = [self currentTimeout];

    if (timeout < 15.0 || timeout > 7200.0) {
        timeout = 15.0;
    }

    _timeout = timeout;

    _timer = [NSTimer timerWithTimeInterval:timeout
                                    target:self
                                  selector:@selector(timerFired:)
                                  userInfo:nil
                                   repeats:NO];

    if (_timer == nil) {
        _started = NO;
        return;
    }

    [[NSRunLoop mainRunLoop] addTimer:_timer
                             forMode:NSRunLoopCommonModes];

    _started = YES;
}


#pragma mark - Stop

- (void)stop
{
    _started = NO;

    if (_timer != nil) {
        [_timer invalidate];
        _timer = nil;
    }
}


#pragma mark - Reset Timer

- (void)resetTimer
{
    if (!_enabled) {
        return;
    }

    /* Đúng hành vi bản cũ: touch gọi lại start để đặt lại bộ đếm. */
    [self start];
}


#pragma mark - Timer Fired

- (void)timerFired:(NSTimer *)timer
{
    if (!_enabled || !_started) {
        return;
    }

    _timer = nil;

    /* Giữ nguyên cơ chế đóng ứng dụng hiện tại. */
