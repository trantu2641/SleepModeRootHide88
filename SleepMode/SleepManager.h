#import <Foundation/Foundation.h>

@interface SleepManager : NSObject

+ (instancetype)sharedInstance;

@property(nonatomic, assign) BOOL enabled;
@property(nonatomic, assign) NSTimeInterval timeout;

- (void)start;
- (void)stop;

- (void)resetTimer;
- (void)userDidInteract;

- (void)enterSleepMode;

@end
