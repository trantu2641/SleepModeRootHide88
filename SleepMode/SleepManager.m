#import "SleepManager.h"

#import <UIKit/UIKit.h>
#import <objc/message.h>


static NSString * const kSleepModeEnabledKey =
    @"Enabled";

static NSString * const kSleepModeTimeoutKey =
    @"Timeout";


@interface SleepManager ()

@property(nonatomic, strong) NSTimer *timer;

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

        NSUserDefaults *defaults =
            [NSUserDefaults standardUserDefaults];

        BOOL enabled =
            [defaults objectForKey:kSleepModeEnabledKey]
                ? [defaults boolForKey:kSleepModeEnabledKey]
                : NO;

        NSTimeInterval timeout =
            [defaults objectForKey:kSleepModeTimeoutKey]
                ? [defaults doubleForKey:kSleepModeTimeoutKey]
                : 60.0;

        _enabled = enabled;
        _timeout = timeout;
    }

    return self;
}


#pragma mark - Enabled

- (void)setEnabled:(BOOL)enabled
{
    _enabled = enabled;

    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    [defaults setBool:enabled
               forKey:kSleepModeEnabledKey];

    [defaults synchronize];

    if (enabled) {
        [self start];
    }
    else {
        [self stop];
    }
}


#pragma mark - Timeout

- (void)setTimeout:(NSTimeInterval)timeout
{
    if (timeout < 1.0) {
        timeout = 1.0;
    }

    _timeout = timeout;

    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    [defaults setDouble:timeout
                 forKey:kSleepModeTimeoutKey];

    [defaults synchronize];

    if (self.enabled) {
        [self resetTimer];
    }
}


#pragma mark - Timer

- (void)start
{
    [self stop];

    if (!self.enabled) {
        return;
    }

    [self resetTimer];
}


- (void)stop
{
    [self.timer invalidate];
    self.timer = nil;
}


- (void)resetTimer
{
    if (!self.enabled) {
        return;
    }

    [self.timer invalidate];
    self.timer = nil;


    NSTimeInterval interval =
        self.timeout;

    if (interval < 1.0) {
        interval = 1.0;
    }


    self.timer =
        [NSTimer scheduledTimerWithTimeInterval:interval
                                         target:self
                                       selector:@selector(timerFired:)
                                       userInfo:nil
                                        repeats:NO];


    /*
     * Đảm bảo timer vẫn chạy trong lúc UITrackingRunLoopMode
     * hoặc các mode khác đang hoạt động.
     */
    [[NSRunLoop mainRunLoop]
        addTimer:self.timer
        forMode:NSRunLoopCommonModes];
}


#pragma mark - Timer fired

- (void)timerFired:(NSTimer *)timer
{
    self.timer = nil;

    if (!self.enabled) {
        return;
    }

    /*
     * Khi timer hết hạn, khóa màn hình.
     */
    [self lockDevice];
}


#pragma mark - Lock device

- (void)lockDevice
{
    Class backBoardControllerClass =
        NSClassFromString(@"SBBackBoardController");

    if (backBoardControllerClass) {

        SEL sharedSelector =
            @selector(sharedInstance);

        if ([backBoardControllerClass
                respondsToSelector:sharedSelector]) {

            id controller =
                ((id (*)(id, SEL))
                 objc_msgSend)(
                    backBoardControllerClass,
                    sharedSelector
                );

            SEL lockSelector =
                @selector(lockScreen);

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


    /*
     * Fallback.
     */
    UIApplication *application =
        [UIApplication sharedApplication];

    SEL lockSelector =
        @selector(_lockScreen);

    if ([application respondsToSelector:lockSelector]) {

        ((void (*)(id, SEL))
         objc_msgSend)(
            application,
            lockSelector
        );
    }
}

@end
