#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import <ControlCenterUIKit/CCUIContentModule.h>
#import <ControlCenterUIKit/CCUIContentModuleContext.h>

#import "SleepControlCenter.h"


@interface SleepModeModuleContentViewController :
    UIViewController
<CCUIContentModuleContentViewController>

@property(nonatomic, weak)
    id<CCUIContentModuleContext> contentModuleContext;

@property(nonatomic, strong)
    UIButton *button;

@end


@interface SleepModeModule :
    NSObject
<CCUIContentModule>

@property(nonatomic, strong)
    SleepModeModuleContentViewController *
        contentViewController;

@end


@implementation SleepModeModule

- (instancetype)init
{
    self = [super init];

    if (self) {

        _contentViewController =
            [[SleepModeModuleContentViewController alloc]
                initWithNibName:nil
                bundle:nil];
    }

    return self;
}

- (UIViewController<CCUIContentModuleContentViewController *> *)
    contentViewController
{
    return _contentViewController;
}

@end


#pragma mark - Content View Controller

@implementation SleepModeModuleContentViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor =
        [UIColor clearColor];

    [self createButton];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
        selector:@selector(stateChanged:)
        name:SleepControlCenterStateChangedNotification
        object:nil];

    [self updateButtonState];
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter]
        removeObserver:self];
}


#pragma mark - Button

- (void)createButton
{
    UIButton *button =
        [UIButton buttonWithType:UIButtonTypeSystem];

    self.button =
        button;

    button.translatesAutoresizingMaskIntoConstraints =
        NO;

    /*
     * SF Symbol.
     *
     * iOS 16 có sẵn moon.fill.
     */
    UIImage *image =
        [UIImage systemImageNamed:@"moon.fill"];

    [button setImage:image
            forState:UIControlStateNormal];

    button.tintColor =
        [UIColor whiteColor];

    button.backgroundColor =
        [UIColor colorWithWhite:1.0
                          alpha:0.12];

    button.layer.cornerRadius =
        18.0;

    button.clipsToBounds =
        YES;

    [button addTarget:self
               action:@selector(buttonTapped:)
     forControlEvents:UIControlEventTouchUpInside];

    /*
     * Ấn giữ khoảng 0.5 giây
     * để mở chọn thời gian.
     */
    UILongPressGestureRecognizer *
        longPress =
            [[UILongPressGestureRecognizer alloc]
                initWithTarget:self
                action:@selector(handleLongPress:)];

    longPress.minimumPressDuration =
        0.5;

    longPress.cancelsTouchesInView =
        YES;

    [button addGestureRecognizer:
        longPress];

    [self.view addSubview:button];

    [NSLayoutConstraint activateConstraints:@[
        [button.leadingAnchor
            constraintEqualToAnchor:
                self.view.leadingAnchor
            constant:8.0],

        [button.trailingAnchor
            constraintEqualToAnchor:
                self.view.trailingAnchor
            constant:-8.0],

        [button.topAnchor
            constraintEqualToAnchor:
                self.view.topAnchor
            constant:8.0],

        [button.bottomAnchor
            constraintEqualToAnchor:
                self.view.bottomAnchor
            constant:-8.0]
    ]];
}


#pragma mark - Tap

- (void)buttonTapped:(UIButton *)sender
{
    SleepControlCenter *control =
        [SleepControlCenter sharedInstance];

    [control toggle];

    [self updateButtonState];

    /*
     * Báo cho Control Center biết
     * trạng thái đã thay đổi.
     */
    if ([self.contentModuleContext
            respondsToSelector:
                @selector(updateState)]) {

        [self.contentModuleContext
            updateState];
    }
}


#pragma mark - Long Press

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
    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:
                @"SleepMode"
            message:
                @"Chọn thời gian tự khóa"
            preferredStyle:
                UIAlertControllerStyleActionSheet];


    NSArray *timeouts = @[
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


    SleepControlCenter *control =
        [SleepControlCenter sharedInstance];


    for (NSDictionary *item in timeouts) {

        NSString *title =
            item[@"title"];

        NSTimeInterval value =
            [item[@"value"] doubleValue];


        NSString *displayTitle =
            title;


        if ([self isCurrentTimeout:value]) {

            displayTitle =
                [NSString stringWithFormat:
                    @"✓ %@",
                    title];
        }


        [alert addAction:
            [UIAlertAction
                actionWithTitle:
                    displayTitle
                style:
                    UIAlertActionStyleDefault
                handler:
                    ^(UIAlertAction *action) {

            [control setTimeout:value];

            [control resetTimer];

            [self updateButtonState];
        }]];
    }


    [alert addAction:
        [UIAlertAction
            actionWithTitle:
                @"Hủy"
            style:
                UIAlertActionStyleCancel
            handler:nil]];


    /*
     * Control Center nằm trên SpringBoard.
     */
    UIViewController *presenter =
        [self presenterViewController];

    if (presenter != nil) {

        [presenter
            presentViewController:
                alert
            animated:YES
            completion:nil];
    }
}


- (BOOL)isCurrentTimeout:
    (NSTimeInterval)value
{
    SleepControlCenter *control =
        [SleepControlCenter sharedInstance];

    NSTimeInterval current =
        control.currentTimeout;

    return fabs(current - value) < 0.01;
}


#pragma mark - Presenter

- (UIViewController *)presenterViewController
{
    UIViewController *controller =
        self;

    while (controller.presentedViewController != nil) {

        controller =
            controller.presentedViewController;
    }

    /*
     * Nếu content VC đang nằm trong
     * container của Control Center,
     * thử lấy parent.
     */
    UIViewController *parent =
        controller.parentViewController;

    if (parent != nil) {

        controller =
            parent;
    }

    return controller;
}


#pragma mark - State

- (void)updateButtonState
{
    SleepControlCenter *control =
        [SleepControlCenter sharedInstance];

    BOOL enabled =
        control.isEnabled;


    UIImage *image;

    if (enabled) {

        image =
            [UIImage systemImageNamed:
                @"moon.fill"];

        self.button.tintColor =
            [UIColor whiteColor];

        self.button.backgroundColor =
            [UIColor colorWithWhite:1.0
                              alpha:0.25];
    }

    else {

        image =
            [UIImage systemImageNamed:
                @"moon"];

        self.button.tintColor =
            [UIColor colorWithWhite:1.0
                              alpha:0.65];

        self.button.backgroundColor =
            [UIColor colorWithWhite:1.0
                              alpha:0.10];
    }


    [self.button
        setImage:image
        forState:UIControlStateNormal];
}


- (void)stateChanged:
    (NSNotification *)notification
{
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            [self updateButtonState];
        }
    );
}

@end
