#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "SleepControlCenter.h"
#import "SleepManager.h"


#pragma mark - Minimal Control Center Interfaces

/*
 * SDK iPhoneOS 16.5 của Theos không có:
 *
 * ControlCenterUIKit/CCUIContentModule.h
 *
 * Vì vậy không import header đó.
 *
 * Module chỉ cần một số phương thức cơ bản để
 * Control Center giao tiếp với module.
 */

@protocol CCUIContentModule <NSObject>

@optional

- (UIViewController *)contentViewController;

- (UIViewController *)backgroundViewController;

- (void)setContentModuleContext:(id)context;

@end


#pragma mark - Forward Declaration

@class SleepModeModuleContentViewController;


#pragma mark - SleepModeModule

@interface SleepModeModule : NSObject <CCUIContentModule>

@property(nonatomic, strong)
    id contentModuleContext;

@property(nonatomic, strong)
    SleepModeModuleContentViewController
        *contentViewController;

@end


#pragma mark - Content View Controller

@interface SleepModeModuleContentViewController : UIViewController

@property(nonatomic, strong)
    UIButton *button;

@property(nonatomic, strong)
    UILabel *timeoutLabel;

- (void)updateState:(BOOL)enabled;

@end


#pragma mark - Module Implementation

@implementation SleepModeModule

- (instancetype)init
{
    self = [super init];

    if (self) {

        /*
         * Module lắng nghe thay đổi trạng thái từ
         * SleepControlCenter.
         *
         * SleepControlCenter không biết module này
         * tồn tại.
         */
        [[NSNotificationCenter defaultCenter]
            addObserver:self
            selector:@selector(stateChanged:)
            name:SleepControlCenterStateChangedNotification
            object:[SleepControlCenter sharedInstance]];
    }

    return self;
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter]
        removeObserver:self];
}


#pragma mark - Content Module Context

- (void)setContentModuleContext:(id)context
{
    _contentModuleContext = context;
}


#pragma mark - Content View Controller

- (UIViewController *)contentViewController
{
    if (_contentViewController == nil) {

        _contentViewController =
            [[SleepModeModuleContentViewController alloc]
                init];
    }

    return _contentViewController;
}


#pragma mark - State Notification

- (void)stateChanged:(NSNotification *)notification
{
    NSDictionary *userInfo =
        notification.userInfo;

    BOOL enabled =
        [userInfo[@"enabled"] boolValue];

    dispatch_async(dispatch_get_main_queue(), ^{

        if (self.contentViewController != nil) {

            [self.contentViewController
                updateState:enabled];
        }
    });
}

@end


#pragma mark - Content View Controller

@implementation SleepModeModuleContentViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor =
        [UIColor clearColor];

    self.view.clipsToBounds = YES;


    #pragma mark Button

    UIButton *button =
        [UIButton buttonWithType:UIButtonTypeSystem];

    button.translatesAutoresizingMaskIntoConstraints = NO;

    button.layer.cornerRadius = 14.0;

    button.titleLabel.font =
        [UIFont systemFontOfSize:18.0
                           weight:UIFontWeightSemibold];

    [button addTarget:self
               action:@selector(buttonPressed:)
     forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:button];

    self.button = button;


    #pragma mark Timeout Label

    UILabel *timeoutLabel =
        [[UILabel alloc] init];

    timeoutLabel.translatesAutoresizingMaskIntoConstraints =
        NO;

    timeoutLabel.textAlignment =
        NSTextAlignmentCenter;

    timeoutLabel.font =
        [UIFont systemFontOfSize:10.0
                           weight:UIFontWeightMedium];

    timeoutLabel.textColor =
        [UIColor colorWithWhite:1.0
                          alpha:0.65];

    [self.view addSubview:timeoutLabel];

    self.timeoutLabel =
        timeoutLabel;


    #pragma mark Layout

    [NSLayoutConstraint activateConstraints:@[

        [button.leadingAnchor
            constraintEqualToAnchor:
                self.view.leadingAnchor
                           constant:6.0],

        [button.trailingAnchor
            constraintEqualToAnchor:
                self.view.trailingAnchor
                           constant:-6.0],

        [button.topAnchor
            constraintEqualToAnchor:
                self.view.topAnchor
                           constant:4.0],

        [button.heightAnchor
            constraintEqualToConstant:42.0],

        [timeoutLabel.leadingAnchor
            constraintEqualToAnchor:
                self.view.leadingAnchor
                           constant:4.0],

        [timeoutLabel.trailingAnchor
            constraintEqualToAnchor:
                self.view.trailingAnchor
                           constant:-4.0],

        [timeoutLabel.topAnchor
            constraintEqualToAnchor:
                button.bottomAnchor
                           constant:1.0],

        [timeoutLabel.bottomAnchor
            constraintEqualToAnchor:
                self.view.bottomAnchor
                           constant:-3.0]
    ]];


    /*
     * Hiển thị trạng thái ban đầu.
     */
    SleepControlCenter *controlCenter =
        [SleepControlCenter sharedInstance];

    [self updateState:
        controlCenter.enabled];
}


#pragma mark - Button

- (void)buttonPressed:(UIButton *)sender
{
    SleepControlCenter *controlCenter =
        [SleepControlCenter sharedInstance];

    [controlCenter toggle];

    [self updateState:
        controlCenter.enabled];
}


#pragma mark - Long Press

/*
 * Nếu Control Center gọi long press riêng thì
 * module có thể mở màn hình chọn thời gian.
 *
 * Ở đây tạo thêm gesture để dùng được khi module
 * được hiển thị dạng UIViewController.
 */
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    if (self.view.gestureRecognizers.count == 0) {

        UILongPressGestureRecognizer *longPress =
            [[UILongPressGestureRecognizer alloc]
                initWithTarget:self
                action:@selector(handleLongPress:)];

        longPress.minimumPressDuration = 0.5;

        [self.view addGestureRecognizer:
            longPress];
    }
}


- (void)handleLongPress:
    (UILongPressGestureRecognizer *)gesture
{
    if (gesture.state !=
        UIGestureRecognizerStateBegan) {

        return;
    }

    [self showTimeoutMenu];
}


#pragma mark - Timeout Menu

- (void)showTimeoutMenu
{
    SleepControlCenter *controlCenter =
        [SleepControlCenter sharedInstance];

    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:@"SleepMode"
                             message:@"Chọn thời gian tự khóa"
                      preferredStyle:
                          UIAlertControllerStyleActionSheet];


    NSArray<NSDictionary *> *options = @[

        @{
            @"title": @"15 giây",
            @"value": @(15.0)
        },

        @{
            @"title": @"1 phút",
            @"value": @(60.0)
        },

        @{
            @"title": @"5 phút",
            @"value": @(300.0)
        },

        @{
            @"title": @"15 phút",
            @"value": @(900.0)
        },

        @{
            @"title": @"30 phút",
            @"value": @(1800.0)
        },

        @{
            @"title": @"1 giờ",
            @"value": @(3600.0)
        },

        @{
            @"title": @"2 giờ",
            @"value": @(7200.0)
        }
    ];


    for (NSDictionary *option in options) {

        NSString *title =
            option[@"title"];

        NSTimeInterval value =
            [option[@"value"] doubleValue];

        UIAlertAction *action =
            [UIAlertAction
                actionWithTitle:title
                         style:UIAlertActionStyleDefault
                       handler:^(__unused UIAlertAction *action) {

            [controlCenter setTimeout:value];

            [self updateTimeoutLabel];
        }];

        [alert addAction:action];
    }


    UIAlertAction *cancel =
        [UIAlertAction
            actionWithTitle:@"Hủy"
                     style:UIAlertActionStyleCancel
                   handler:nil];

    [alert addAction:cancel];


    /*
     * UIAlertController phải được trình bày
     * từ một UIViewController đang hiển thị.
     */
    UIViewController *presenter =
        self;

    while (presenter.presentedViewController != nil) {

        presenter =
            presenter.presentedViewController;
    }

    [presenter presentViewController:
        alert
                           animated:YES
                         completion:nil];
}


#pragma mark - State

- (void)updateState:(BOOL)enabled
{
    if (![NSThread isMainThread]) {

        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateState:enabled];
        });

        return;
    }


    NSString *title =
        enabled ? @"ON" : @"OFF";

    [self.button setTitle:
        title
                  forState:
                      UIControlStateNormal];


    if (enabled) {

        self.button.backgroundColor =
            [UIColor colorWithWhite:1.0
                              alpha:0.28];

        [self.button setTitleColor:
            [UIColor whiteColor]
                          forState:
                              UIControlStateNormal];

    } else {

        self.button.backgroundColor =
            [UIColor colorWithWhite:0.0
                              alpha:0.18];

        [self.button setTitleColor:
            [UIColor colorWithWhite:1.0
                              alpha:0.65]
                          forState:
                              UIControlStateNormal];
    }


    [self updateTimeoutLabel];
}


#pragma mark - Timeout Label

- (void)updateTimeoutLabel
{
    NSTimeInterval timeout =
        [SleepControlCenter sharedInstance]
            .currentTimeout;

    NSString *text = nil;


    if (timeout < 60.0) {

        text =
            [NSString stringWithFormat:
                @"%.0f giây",
                timeout];

    } else if (timeout < 3600.0) {

        NSInteger minutes =
            (NSInteger)round(timeout / 60.0);

        text =
            [NSString stringWithFormat:
                @"%ld phút",
                (long)minutes];

    } else {

        double hours =
            timeout / 3600.0;

        if (fabs(hours -
                 round(hours)) < 0.01) {

            text =
                [NSString stringWithFormat:
                    @"%.0f giờ",
                    hours];

        } else {

            text =
                [NSString stringWithFormat:
                    @"%.1f giờ",
                    hours];
        }
    }


    self.timeoutLabel.text =
        [NSString stringWithFormat:
            @"Tự khóa sau %@",
            text];
}

@end
