#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>

#pragma mark - Private Control Center API

@interface CCUIToggleModule : NSObject
- (BOOL)isSelected;
- (void)setSelected:(BOOL)selected;
@end


#pragma mark - SleepModeModule

@interface SleepModeModule : CCUIToggleModule
@end


@implementation SleepModeModule

#pragma mark - Init

- (instancetype)init
{
    self = [super init];

    if (self) {
        /*
         * Không làm bất kỳ việc gì nặng trong init.
         * Control Center gọi init khi dựng danh sách module.
         */
    }

    return self;
}


#pragma mark - Selected state

- (BOOL)isSelected
{
    return [[NSUserDefaults standardUserDefaults]
            boolForKey:@"SleepModeEnabled"];
}


- (void)setSelected:(BOOL)selected
{
    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    [defaults setBool:selected
              forKey:@"SleepModeEnabled"];

    [defaults synchronize];

    NSDictionary *info = @{
        @"enabled" : @(selected)
    };

    /*
     * Gửi lệnh sang SleepMode tweak đang chạy trong SpringBoard.
     */
    [[NSNotificationCenter defaultCenter]
        postNotificationName:@"com.trantu.sleepmode.command"
        object:nil
        userInfo:info];

    /*
     * Báo cho các thành phần SleepMode cập nhật trạng thái.
     */
    [[NSNotificationCenter defaultCenter]
        postNotificationName:@"com.trantu.sleepmode.stateChanged"
        object:nil];
}


#pragma mark - Toggle

- (void)toggle
{
    BOOL current = [self isSelected];

    [self setSelected:!current];
}


#pragma mark - Press

- (void)handlePress
{
    [self toggle];
}


#pragma mark - Display name

- (NSString *)displayName
{
    return @"Chế độ ngủ";
}


#pragma mark - Identifier

- (NSString *)identifier
{
    return @"com.trantu.sleepmode.module";
}


#pragma mark - Accessibility

- (NSString *)accessibilityLabel
{
    return @"Chế độ ngủ";
}

@end
