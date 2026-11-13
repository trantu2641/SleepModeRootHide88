#ifndef SleepManager_h
#define SleepManager_h

#import <Foundation/Foundation.h>

/* Runtime interface exported by the untouched SleepMode 1.1.0 core. */
@interface SleepManager : NSObject
+ (instancetype)sharedInstance;
- (void)start;
- (void)userDidInteract;
- (void)setEnabled:(BOOL)enabled;
- (void)setTimeout:(NSTimeInterval)timeout;
- (BOOL)isEnabled;
@end

#endif
