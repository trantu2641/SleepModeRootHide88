#import <Foundation/Foundation.h>

@class SleepManager;

NS_ASSUME_NONNULL_BEGIN

extern NSString * const SleepModeCommandNotification;
extern NSString * const SleepModeStateChangedNotification;

extern NSString * const SleepModeEnabledKey;
extern NSString * const SleepModeTimeoutKey;

@interface SleepControlCenter : NSObject

+ (instancetype)sharedInstance;

@property(nonatomic, assign, getter=isEnabled) BOOL enabled;

- (void)enable;
- (void)disable;
- (void)toggle;

- (void)setTimeout:(NSTimeInterval)timeout;
- (NSTimeInterval)currentTimeout;

- (void)resetTimer;

@end

NS_ASSUME_NONNULL_END
