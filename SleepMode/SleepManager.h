#import <Foundation/Foundation.h>

@interface SleepManager : NSObject

+ (instancetype)sharedInstance;

@property(nonatomic, assign, getter=isEnabled) BOOL enabled;
@property(nonatomic, assign) NSTimeInterval timeout;

- (void)start;
- (void)stop;
- (void)resetTimer;
- (void)lockDevice;

@end
