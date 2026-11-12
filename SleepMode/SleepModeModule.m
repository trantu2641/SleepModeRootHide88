#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>


#pragma mark - Constants

static NSString * const
    kSleepControlCenterClassName =
        @"SleepControlCenter";

static NSString * const
    kSleepControlCenterNotification =
        @"com.trantu.sleepmode.stateChanged";


#pragma mark - Runtime Helpers

static id SleepControlCenterInstance(void)
{
    Class cls =
        NSClassFromString(
            kSleepControlCenterClassName);

    if (cls == Nil) {
        NSLog(@"[Chế độ ngủ] Không tìm thấy SleepControlCenter");
        return nil;
    }

    SEL selector =
        NSSelectorFromString(@"sharedInstance");

    if (![cls respondsToSelector:selector]) {
        NSLog(@"[Chế độ ngủ] Không tìm thấy sharedInstance");
        return nil;
    }

    id (*SendMessage)(id, SEL) =
        (id (*)(id, SEL))objc_msgSend;

    return SendMessage((id)cls, selector);
}


static BOOL SleepControlCenterEnabled(void)
{
    id manager =
        SleepControlCenterInstance();

    if (manager == nil) {
        return NO;
    }

    SEL selector =
        NSSelectorFromString(@"isEnabled");

    if (![manager respondsToSelector:selector]) {
        return NO;
    }

    BOOL (*SendMessage)(id, SEL) =
        (BOOL (*)(id, SEL))objc_msgSend;

    return SendMessage(manager, selector);
}


static NSTimeInterval SleepControlCenterTimeout(void)
{
    id manager =
        SleepControlCenterInstance();

    if (manager == nil) {
        return 15.0;
    }

    SEL selector =
        NSSelectorFromString(@"currentTimeout");

    if (![manager respondsToSelector:selector]) {
        return 15.0;
    }

    NSTimeInterval (*SendMessage)(id, SEL) =
        (NSTimeInterval (*)(id, SEL))objc_msgSend;

    return SendMessage(manager, selector);
}


static void SleepControlCenterToggle(void)
{
    id manager =
        SleepControlCenterInstance();

    if (manager == nil) {
        NSLog(@"[Chế độ ngủ] Không thể bật/tắt");
        return;
    }

    SEL selector =
        NSSelectorFromString(@"toggle");

    if (![manager respondsToSelector:selector]) {
        NSLog(@"[Chế độ ngủ] Không tìm thấy toggle");
        return;
    }

    void (*SendMessage)(id, SEL) =
        (void (*)(id, SEL))objc_msgSend;

    SendMessage(manager, selector);
}


static void SleepControlCenterSetTimeout(
    NSTimeInterval timeout)
{
    id manager =
        SleepControlCenterInstance();

    if (manager == nil) {
        NSLog(@"[Chế độ ngủ] Không thể đặt thời gian");
        return;
    }

    SEL selector =
        NSSelectorFromString(@"setTimeout:");

    if (![manager respondsToSelector:selector]) {
        NSLog(@"[Chế độ ngủ] Không tìm thấy setTimeout:");
        return;
    }

    void (*SendMessage)(id, SEL, NSTimeInterval) =
        (void (*)(id, SEL, NSTimeInterval))objc_msgSend;

    SendMessage(manager, selector, timeout);
}


#pragma mark - Minimal Control Center Protocol

@protocol CCUIContentModule <NSObject>

@optional

- (UIViewController *)contentViewController;

- (UIViewController *)backgroundViewController;

- (void)setContentModuleContext:(id)context;

@end


#pragma mark - Forward Declaration

@class SleepModeModuleContentViewController;


#pragma mark - Module

@interface SleepModeModule : NSObject <CCUIContentModule>

@property(nonatomic, strong)
    id contentModuleContext;

@property(nonatomic, strong)
    SleepModeModuleContentViewController
        *contentViewController;

@end


#pragma mark - Content View Controller

@interface SleepModeModuleContentViewController :
    UIViewController

@property(nonatomic, strong)
    UIButton *button;

@property(nonatomic, strong)
    UILabel *timeoutLabel;

- (void)updateState:(BOOL)enabled;

- (void)updateTimeoutLabel;

@end


#pragma mark - Module Implementation

@implementation SleepModeModule

- (instancetype)init
{
    self = [super init];

    if (self) {

        NSLog(@"[Chế độ ngủ] Khởi tạo module");

        [[NSNotificationCenter defaultCenter]
            addObserver:self
            selector:@selector(stateChanged:)
            name:kSleepControlCenterNotification
            object:nil];
    }

    return self;
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter]
        removeObserver:self];
}


- (void)setContentModuleContext:(id)context
{
    _contentModuleContext = context;
}


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

    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            if (self.contentViewController != nil) {

                [self.contentViewController
                    updateState:enabled];
            }
        });
}

@end


#pragma mark - Content View Controller

@implementation SleepModeModuleContentViewController


#pragma mark - View

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor =
        [UIColor clearColor];

    self.view.clipsToBounds = YES;


    /*
     * Nút chính
     */

    UIButton *button =
        [UIButton buttonWithType:
            UIButtonTypeSystem];

    button.translatesAutoresizingMaskIntoConstraints =
        NO;

    button.layer.cornerRadius =
        14.0;

    button.titleLabel.font =
        [UIFont systemFontOfSize:17.0
                           weight:UIFontWeightSemibold];

    [button addTarget:self
               action:@selector(buttonPressed:)
     forControlEvents:
         UIControlEventTouchUpInside];

    [self.view addSubview:button];

    self.button = button;


    /*
     * Nhãn thời gian
     */

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

    timeoutLabel.numberOfLines = 1;

    [self.view addSubview:timeoutLabel];

    self.timeoutLabel =
        timeoutLabel;


    /*
     * Bố cục
     */

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
            constraintEqualToConstant:40.0],

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
     * Trạng thái ban đầu
     */

    BOOL enabled =
        SleepControlCenterEnabled();

    [self updateState:enabled];
}


#pragma mark - Button

- (void)buttonPressed:(UIButton *)sender
{
    NSLog(@"[Chế độ ngủ] Nhấn nút");

    SleepControlCenterToggle();

    BOOL enabled =
        SleepControlCenterEnabled();

    [self updateState:enabled];
}


#pragma mark - Long Press

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    BOOL alreadyInstalled =
        NO;

    for (UIGestureRecognizer *gesture
         in self.view.gestureRecognizers) {

        if ([gesture isKindOfClass:
                [UILongPressGestureRecognizer class]]) {

            alreadyInstalled = YES;
            break;
        }
    }

    if (!alreadyInstalled) {

        UILongPressGestureRecognizer *longPress =
            [[UILongPressGestureRecognizer alloc]
                initWithTarget:self
                action:@selector(handleLongPress:)];

        longPress.minimumPressDuration =
            0.5;

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

    NSLog(@"[Chế độ ngủ] Mở chọn thời gian");

    [self showTimeoutMenu];
}


#pragma mark - Timeout Menu

- (void)showTimeoutMenu
{
    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:
                @"Chế độ ngủ"
            message:
                @"Chọn thời gian tự động khóa"
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

        NSTimeInterval timeout =
            [option[@"value"] doubleValue];


        UIAlertAction *action =
            [UIAlertAction
                actionWithTitle:title
                style:UIAlertActionStyleDefault
                handler:^(__unused UIAlertAction *action) {

            NSLog(
                @"[Chế độ ngủ] Thời gian = %.0f",
                timeout);

            SleepControlCenterSetTimeout(
                timeout);

            [self updateTimeoutLabel];
        }];


        [alert addAction:action];
    }


    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"Hủy"
            style:UIAlertActionStyleCancel
            handler:nil]];


    UIViewController *presenter =
        self;

    while (presenter.presentedViewController != nil) {

        presenter =
            presenter.presentedViewController;
    }


    [presenter
        presentViewController:
            alert
        animated:YES
        completion:nil];
}


#pragma mark - State

- (void)updateState:(BOOL)enabled
{
    if (![NSThread isMainThread]) {

        dispatch_async(
            dispatch_get_main_queue(),
            ^{
                [self updateState:enabled];
            });

        return;
    }


    NSString *title =
        enabled
            ? @"Đang bật"
            : @"Đang tắt";


    [self.button
        setTitle:title
        forState:UIControlStateNormal];


    if (enabled) {

        self.button.backgroundColor =
            [UIColor colorWithWhite:1.0
                              alpha:0.28];

        [self.button
            setTitleColor:
                [UIColor whiteColor]
            forState:
                UIControlStateNormal];

    } else {

        self.button.backgroundColor =
            [UIColor colorWithWhite:0.0
                              alpha:0.18];

        [self.button
            setTitleColor:
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
        SleepControlCenterTimeout();


    NSString *text = nil;


    if (timeout < 60.0) {

        text =
            [NSString stringWithFormat:
                @"%.0f giây",
                timeout];

    }

    else if (timeout < 3600.0) {

        NSInteger minutes =
            (NSInteger)round(
                timeout / 60.0);

        text =
            [NSString stringWithFormat:
                @"%ld phút",
                (long)minutes];
    }

    else {

        double hours =
            timeout / 3600.0;

        if (fabs(
                hours - round(hours)) < 0.01) {

            text =
                [NSString stringWithFormat:
                    @"%.0f giờ",
                    hours];

        }

        else {

            text =
                [NSString stringWithFormat:
                    @"%.1f giờ",
                    hours];
        }
    }


    self.timeoutLabel.text =
        [NSString stringWithFormat:
            @"Tự động khóa sau %@",
            text];
}

@end
