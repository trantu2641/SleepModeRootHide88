#import <Foundation/Foundation.h>

@class SleepManager;

NS_ASSUME_NONNULL_BEGIN

@interface SleepControlCenter : NSObject

+ (instancetype)sharedInstance;

@property(nonatomic, assign, getter=isEnabled) BOOL enabled;

- (void)enable;
- (void)disable;
- (void)toggle;

- (void)setTimeout:(NSTimeInterval)timeout;
- (NSTimeInterval)currentTimeout;

- (void)resetTimer;

extern NSString * const
    SleepControlCenterStateChangedNotification;

@end

NS_ASSUME_NONNULL_END
