#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const SleepControlCenterStateChangedNotification;

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
