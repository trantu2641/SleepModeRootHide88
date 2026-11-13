#ifndef SleepManager_h
#define SleepManager_h

#import <Foundation/Foundation.h>

@interface SleepManager : NSObject

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
