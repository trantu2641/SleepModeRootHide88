#import "SleepManager.h"

#import <UIKit/UIKit.h>
#import <objc/message.h>

@interface SleepManager ()

@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, assign) BOOL started;

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
        _enabled = NO;
        _timeout = 15.0;
        _started = NO;
    }

    return self;
}

#pragma mark - Start

- (void)start
{
    if (!self.enabled) {
        return;
    }

    [self.timer invalidate];
    self.timer = nil;

    self.timer =
        [NSTimer timerWithTimeInterval:self.timeout
                                target:self
                              selector:@selector(timerFired:)
                              userInfo:nil
                               repeats:NO];

    [[NSRunLoop mainRunLoop]
        addTimer:self.timer
        forMode:NSRunLoopCommonModes];

    self.started = YES;
}

#pragma mark - Stop

- (void)stop
{
    [self.timer invalidate];

    self.timer = nil;
    self.started = NO;
}

#pragma mark - Reset

- (void)resetTimer
{
    if (!self.enabled) {
        return;
    }

    [self start];
}

#pragma mark - Timer

- (void)timerFired:(NSTimer *)timer
{
    self.timer = nil;
    self.started = NO;

    if (!self.enabled) {
        return;
    }

    [self terminateUserApps];

    [self lockDevice];
}

#pragma mark - Terminate Apps

- (void)terminateUserApps
{
    /*
     * Không dùng performSelector:
     * tránh ARC warning/error với selector động.
     *
     * Phần này cố gắng gọi private SpringBoard service
     * nếu tồn tại.
     */

    Class serviceClass =
        NSClassFromString(@"FBSystemService");

    if (!serviceClass) {
        return;
    }

    SEL sharedInstanceSEL =
        NSSelectorFromString(@"sharedInstance");

    if (![serviceClass respondsToSelector:sharedInstanceSEL]) {
        return;
    }

    id service =
        ((id (*)(id, SEL))objc_msgSend)(
            serviceClass,
            sharedInstanceSEL
        );

    if (!service) {
        return;
    }

    SEL terminateSEL =
        NSSelectorFromString(
            @"terminateApplication:forReason:andReport:"
        );

    if (![service respondsToSelector:terminateSEL]) {
        return;
    }

    /*
     * Không truyền danh sách app giả.
     *
     * Một số bản iOS không cho terminate toàn bộ
     * user app theo cách này.
     *
     * Nếu private API không tồn tại thì bỏ qua,
     * sau đó vẫn khóa máy.
     */
}

#pragma mark - Lock Device

- (void)lockDevice
{
    /*
     * Cách chính:
     * SBBackBoardController
     */

    Class backBoardClass =
        NSClassFromString(@"SBBackBoardController");

    if (backBoardClass) {

        SEL sharedInstanceSEL =
            NSSelectorFromString(@"sharedInstance");

        if ([backBoardClass
                respondsToSelector:sharedInstanceSEL]) {

            id controller =
                ((id (*)(id, SEL))objc_msgSend)(
                    backBoardClass,
                    sharedInstanceSEL
                );

            if (controller) {

                SEL lockSEL =
                    NSSelectorFromString(@"lockScreen");

                if ([controller
                        respondsToSelector:lockSEL]) {

                    ((void (*)(id, SEL))objc_msgSend)(
                        controller,
                        lockSEL
                    );

                    return;
                }
            }
        }
    }

    /*
     * Fallback:
     * SpringBoard._lockScreen
     *
     * Không dùng performSelector để tránh
     * ARC performSelector-leaks.
     */

    Class springBoardClass =
        NSClassFromString(@"SpringBoard");

    if (!springBoardClass) {
        return;
    }

    SEL sharedApplicationSEL =
        NSSelectorFromString(@"sharedApplication");

    if (![springBoardClass
            respondsToSelector:sharedApplicationSEL]) {
        return;
    }

    id springBoard =
        ((id (*)(id, SEL))objc_msgSend)(
            springBoardClass,
            sharedApplicationSEL
        );

    if (!springBoard) {
        return;
    }

    SEL lockSEL =
        NSSelectorFromString(@"_lockScreen");

    if ([springBoard
            respondsToSelector:lockSEL]) {

        ((void (*)(id, SEL))objc_msgSend)(
            springBoard,
            lockSEL
        );
    }
}

@end
