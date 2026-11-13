#ifndef SleepManager_h
#define SleepManager_h

#import <Foundation/Foundation.h>

@interface SleepManager : NSObject {
    BOOL _enabled;
    NSTimeInterval _timeout;

    BOOL _started;
    BOOL _deviceLocked;
    BOOL _isEnteringSleep;

    NSTimeInterval _lastInteraction;

    dispatch_source_t _timer;
}

+ (instancetype)sharedInstance;

- (void)start;
- (void)stop;

- (void)resetTimer;
- (void)resetIdleTimer;
- (void)userDidInteract;

- (BOOL)isEnabled;
- (void)setEnabled:(BOOL)enabled;

- (NSTimeInterval)timeout;
- (void)setTimeout:(NSTimeInterval)timeout;

@end

#endif
