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

#pragma mark - Start / Stop

- (void)start
{
    if (!self.enabled)
        return;

    [self.timer invalidate];

    self.timer = [NSTimer timerWithTimeInterval:self.timeout
                                         target:self
                                       selector:@selector(timerFired:)
                                       userInfo:nil
                                        repeats:NO];

    [[NSRunLoop mainRunLoop] addTimer:self.timer
                              forMode:NSRunLoopCommonModes];

    self.started = YES;
}

- (void)stop
{
    [self.timer invalidate];
    self.timer = nil;

    self.started = NO;
}

#pragma mark - Reset

- (void)resetTimer
{
    if (!self.enabled)
        return;

    [self start];
}

#pragma mark - Timer

- (void)timerFired:(NSTimer *)timer
{
    self.timer = nil;
    self.started = NO;

    if (!self.enabled)
        return;

    [self terminateUserApps];

    [self lockDevice];
}

#pragma mark - Kill Apps

- (void)terminateUserApps
{
    Class workspaceClass =
        NSClassFromString(@"FBSystemService");

    if (workspaceClass) {
        id service = nil;

        SEL sharedInstanceSEL =
            NSSelectorFromString(@"sharedInstance");

        if ([workspaceClass respondsToSelector:sharedInstanceSEL]) {
            service = ((id (*)(id, SEL))objc_msgSend)(
                workspaceClass,
                sharedInstanceSEL
            );
        }

        if (service) {
            SEL terminateAllSEL =
                NSSelectorFromString(@"terminateApplication:forReason:andReport:");

            if ([service respondsToSelector:terminateAllSEL]) {
                NSArray *applications = @[];

                ((void (*)(id, SEL, id, int, BOOL))objc_msgSend)(
                    service,
                    terminateAllSEL,
                    applications,
                    1,
                    YES
                );
            }
        }
    }
}

#pragma mark - Lock

- (void)lockDevice
{
    Class backBoardClass =
        NSClassFromString(@"SBBackBoardController");

    if (backBoardClass) {

        id controller = nil;

        SEL sharedInstanceSEL =
            NSSelectorFromString(@"sharedInstance");

        if ([backBoardClass respondsToSelector:sharedInstanceSEL]) {
            controller = ((id (*)(id, SEL))objc_msgSend)(
                backBoardClass,
                sharedInstanceSEL
            );
        }

        if (controller) {

            SEL lockSEL =
                NSSelectorFromString(@"lockScreen");

            if ([controller respondsToSelector:lockSEL]) {

                ((void (*)(id, SEL))objc_msgSend)(
                    controller,
                    lockSEL
                );

                return;
            }
        }
    }

    /*
     * Fallback.
     */

    Class springBoardClass =
        NSClassFromString(@"SpringBoard");

    if (springBoardClass) {

        id springBoard =
            [springBoardClass performSelector:
                NSSelectorFromString(@"sharedApplication")];

        SEL lockSEL =
            NSSelectorFromString(@"_lockScreen");

        if ([springBoard respondsToSelector:lockSEL]) {
            ((void (*)(id, SEL))objc_msgSend)(
                springBoard,
                lockSEL
            );
        }
    }
}

@end
