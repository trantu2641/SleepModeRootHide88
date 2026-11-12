#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma mark - Shared State

static NSString * const kSleepModeEnabledKey =
    @"SleepModeEnabled";

static NSString * const kSleepModeTimeoutKey =
    @"SleepModeTimeout";

static NSString * const kSleepModeNotification =
    @"com.trantu.sleepmode.stateChanged";

#pragma mark - CCUIContentModule

@protocol CCUIContentModule <NSObject>

@optional

- (UIViewController *)contentViewController;

- (UIViewController *)backgroundViewController;

- (void)setContentModuleContext:(id)context;

@end

#pragma mark - SleepModeModule

@interface SleepModeModule : NSObject

@property(nonatomic, retain)
    id contentModuleContext;

@end

#pragma mark - Content View Controller

@interface SleepModeContentViewController : UIViewController

@property(nonatomic, retain)
    UILabel *titleLabel;

@property(nonatomic, retain)
    UILabel *stateLabel;

@property(nonatomic, retain)
    UIButton *toggleButton;

@property(nonatomic, retain)
    UILabel *hintLabel;

@end

#pragma mark - Module

@implementation SleepModeModule

+ (void)load
{
    Protocol *protocol =
        objc_getProtocol("CCUIContentModule");

    if (protocol &&
        !class_conformsToProtocol(self, protocol)) {

        class_addProtocol(self, protocol);
    }
}

- (UIViewController *)contentViewController
{
    return [[SleepModeContentViewController alloc] init];
}

- (void)setContentModuleContext:(id)context
{
    _contentModuleContext = context;
}

@end

#pragma mark - Content View Controller

@implementation SleepModeContentViewController

#pragma mark - ViewDidLoad

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor =
        [UIColor clearColor];

    [self buildUI];

    [self updateUI];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
        selector:@selector(updateUI)
        name:kSleepModeNotification
        object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter]
        removeObserver:self];
}

#pragma mark - Build UI

- (void)buildUI
{
    UILabel *titleLabel =
        [[UILabel alloc] init];

    titleLabel.translatesAutoresizingMaskIntoConstraints =
        NO;

    titleLabel.text =
        @"Chế độ ngủ";

    titleLabel.textColor =
        [UIColor whiteColor];

    titleLabel.font =
        [UIFont systemFontOfSize:
            18.0
            weight:UIFontWeightSemibold];

    titleLabel.textAlignment =
        NSTextAlignmentCenter;

    [self.view addSubview:titleLabel];

    self.titleLabel =
        titleLabel;

    UILabel *stateLabel =
        [[UILabel alloc] init];

    stateLabel.translatesAutoresizingMaskIntoConstraints =
        NO;

    stateLabel.textColor =
        [UIColor colorWithWhite:0.85
                          alpha:1.0];

    stateLabel.font =
        [UIFont systemFontOfSize:13.0
                          weight:UIFontWeightRegular];

    stateLabel.textAlignment =
        NSTextAlignmentCenter;

    [self.view addSubview:stateLabel];

    self.stateLabel =
        stateLabel;

    UIButton *toggleButton =
        [UIButton buttonWithType:UIButtonTypeSystem];

    toggleButton.translatesAutoresizingMaskIntoConstraints =
        NO;

    toggleButton.layer.cornerRadius =
        14.0;

    toggleButton.clipsToBounds =
        YES;

    [toggleButton addTarget:self
                     action:@selector(togglePressed:)
           forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:toggleButton];

    self.toggleButton =
        toggleButton;

    UILabel *hintLabel =
        [[UILabel alloc] init];

    hintLabel.translatesAutoresizingMaskIntoConstraints =
        NO;

    hintLabel.text =
        @"Nhấn giữ để chọn thời gian";

    hintLabel.textColor =
        [UIColor colorWithWhite:0.65
                          alpha:1.0];

    hintLabel.font =
        [UIFont systemFontOfSize:11.0];

    hintLabel.textAlignment =
        NSTextAlignmentCenter;

    [self.view addSubview:hintLabel];

    self.hintLabel =
        hintLabel;

    UILongPressGestureRecognizer *longPress =
        [[UILongPressGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(handleLongPress:)];

    longPress.minimumPressDuration =
        0.5;

    [toggleButton addGestureRecognizer:
        longPress];

    [NSLayoutConstraint activateConstraints:@[

        [titleLabel.topAnchor
            constraintEqualToAnchor:
                self.view.topAnchor
                constant:10.0],

        [titleLabel.leadingAnchor
            constraintEqualToAnchor:
                self.view.leadingAnchor
                constant:8.0],

        [titleLabel.trailingAnchor
            constraintEqualToAnchor:
                self.view.trailingAnchor
                constant:-8.0],

        [stateLabel.topAnchor
            constraintEqualToAnchor:
                titleLabel.bottomAnchor
                constant:2.0],

        [stateLabel.leadingAnchor
            constraintEqualToAnchor:
                self.view.leadingAnchor
                constant:8.0],

        [stateLabel.trailingAnchor
            constraintEqualToAnchor:
                self.view.trailingAnchor
                constant:-8.0],

        [toggleButton.centerXAnchor
            constraintEqualToAnchor:
                self.view.centerXAnchor],

        [toggleButton.topAnchor
            constraintEqualToAnchor:
                stateLabel.bottomAnchor
                constant:6.0],

        [toggleButton.widthAnchor
            constraintEqualToConstant:90.0],

        [toggleButton.heightAnchor
            constraintEqualToConstant:28.0],

        [hintLabel.topAnchor
            constraintEqualToAnchor:
                toggleButton.bottomAnchor
                constant:4.0],

        [hintLabel.leadingAnchor
            constraintEqualToAnchor:
                self.view.leadingAnchor
                constant:5.0],

        [hintLabel.trailingAnchor
            constraintEqualToAnchor:
                self.view.trailingAnchor
                constant:-5.0],

        [hintLabel.bottomAnchor
            constraintLessThanOrEqualToAnchor:
                self.view.bottomAnchor
                constant:-5.0]
    ]];
}

#pragma mark - State

- (BOOL)sleepModeEnabled
{
    return [[NSUserDefaults standardUserDefaults]
        boolForKey:kSleepModeEnabledKey];
}

- (NSTimeInterval)sleepModeTimeout
{
    double timeout =
        [[NSUserDefaults standardUserDefaults]
            doubleForKey:kSleepModeTimeoutKey];

    if (timeout < 1.0) {
        timeout = 15.0;
    }

    return timeout;
}

#pragma mark - Update UI

- (void)updateUI
{
    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            BOOL enabled =
                [self sleepModeEnabled];

            NSTimeInterval timeout =
                [self sleepModeTimeout];

            if (enabled) {

                self.stateLabel.text =
                    [NSString stringWithFormat:
                        @"Đang bật · %@",
                        [self timeoutText:timeout]];

                self.stateLabel.textColor =
                    [UIColor colorWithRed:0.35
                                    green:1.0
                                     blue:0.45
                                    alpha:1.0];

                [self.toggleButton
                    setTitle:@"Đang bật"
                    forState:UIControlStateNormal];

                self.toggleButton.backgroundColor =
                    [UIColor colorWithRed:0.20
                                    green:0.65
                                     blue:0.30
                                    alpha:1.0];
            }
            else {

                self.stateLabel.text =
                    @"Đang tắt";

                self.stateLabel.textColor =
                    [UIColor colorWithWhite:0.75
                                      alpha:1.0];

                [self.toggleButton
                    setTitle:@"Đã tắt"
                    forState:UIControlStateNormal];

                self.toggleButton.backgroundColor =
                    [UIColor colorWithWhite:0.25
                                      alpha:1.0];
            }

            [self.toggleButton
                setTitleColor:
                    [UIColor whiteColor]
                forState:UIControlStateNormal];
        }
    );
}

#pragma mark - Toggle

- (void)togglePressed:(UIButton *)sender
{
    BOOL enabled =
        [self sleepModeEnabled];

    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    [defaults setBool:!enabled
               forKey:kSleepModeEnabledKey];

    [defaults synchronize];

    /*
     * Gọi API của tweak qua notification.
     * Tweak sẽ nhận và áp dụng trạng thái.
     */
    [[NSNotificationCenter defaultCenter]
        postNotificationName:kSleepModeNotification
        object:nil];

    [self updateUI];
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
                @"Thời gian tự khóa"
            message:
                @"Chọn thời gian không thao tác"
            preferredStyle:
                UIAlertControllerStyleActionSheet];

    NSArray *values = @[
        @15.0,
        @60.0,
        @300.0,
        @900.0,
        @1800.0,
        @3600.0,
        @7200.0
    ];

    NSArray *titles = @[
        @"15 giây",
        @"1 phút",
        @"5 phút",
        @"15 phút",
        @"30 phút",
        @"1 giờ",
        @"2 giờ"
    ];

    for (NSUInteger i = 0;
         i < values.count;
         i++) {

        NSTimeInterval value =
            [values[i] doubleValue];

        NSString *title =
            titles[i];

        [alert addAction:
            [UIAlertAction
                actionWithTitle:title
                style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {

                    NSUserDefaults *defaults =
                        [NSUserDefaults standardUserDefaults];

                    [defaults setDouble:value
                                 forKey:kSleepModeTimeoutKey];

                    [defaults synchronize];

                    [[NSNotificationCenter defaultCenter]
                        postNotificationName:
                            kSleepModeNotification
                        object:nil];

                    [self updateUI];
                }]];
    }

    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"Hủy"
            style:UIAlertActionStyleCancel
            handler:nil]];

    UIViewController *presenter =
        self;

    while (presenter.presentedViewController) {
        presenter =
            presenter.presentedViewController;
    }

    [presenter
        presentViewController:alert
                     animated:YES
                   completion:nil];
}

#pragma mark - Timeout Text

- (NSString *)timeoutText:
    (NSTimeInterval)timeout
{
    if (timeout < 60.0) {

        return [NSString stringWithFormat:
            @"%.0f giây",
            timeout];
    }

    if (timeout < 3600.0) {

        NSInteger minutes =
            (NSInteger)round(timeout / 60.0);

        return [NSString stringWithFormat:
            @"%ld phút",
            (long)minutes];
    }

    NSInteger hours =
        (NSInteger)round(timeout / 3600.0);

    return [NSString stringWithFormat:
        @"%ld giờ",
        (long)hours];
}

@end
