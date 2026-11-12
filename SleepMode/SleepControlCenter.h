#import <Foundation/Foundation.h>

@class SleepManager;

NS_ASSUME_NONNULL_BEGIN

@interface SleepControlCenter : NSObject

+ (instancetype)sharedInstance;

/*
 * Trạng thái SleepMode
 */
@property(nonatomic, assign, getter=isEnabled) BOOL enabled;

/*
 * Thời gian chờ tính bằng giây.
 *
 * Ví dụ:
 *
 * 60      = 1 phút
 * 300     = 5 phút
 * 900     = 15 phút
 * 1800    = 30 phút
 * 3600    = 1 giờ
 * 7200    = 2 giờ
 */
@property(nonatomic, assign) NSTimeInterval timeout;


/*
 * Bật SleepMode
 */
- (void)enable;

/*
 * Tắt SleepMode
 */
- (void)disable;

/*
 * Đảo trạng thái bật / tắt
 */
- (void)toggle;


/*
 * Thay đổi thời gian chờ
 */
- (void)setTimeout:(NSTimeInterval)timeout;


/*
 * Reset bộ đếm hoạt động.
 */
- (void)resetTimer;


/*
 * Trạng thái hiện tại.
 */
- (BOOL)isEnabled;

/*
 * Timeout hiện tại.
 */
- (NSTimeInterval)currentTimeout;


/*
 * Notification:
 *
 * com.trantu.sleepmode.stateChanged
 *
 * object = SleepControlCenter
 *
 * userInfo:
 *
 * {
 *     enabled = YES / NO;
 *     timeout = số giây;
 * }
 */
extern NSString * const
    SleepControlCenterStateChangedNotification;

@end

NS_ASSUME_NONNULL_END
