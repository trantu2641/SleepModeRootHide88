#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import <ControlCenterUIKit/ControlCenterUIKit.h>

static NSString * const kSleepModeEnabledKey =
    @"SleepModeEnabled";

static NSString * const kSleepModeTimeoutKey =
    @"SleepModeTimeout";

static NSString * const kSleepModeCommandNotification =
    @"com.trantu.sleepmode.command";

static NSString * const kSleepModeStateChangedNotification =
    @"com.trantu.sleepmode.stateChanged";

@interface SleepModeContentViewController :
    UIViewController

@end

@interface SleepModeContentViewController ()

@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UILabel *statusLabel;
@property(nonatomic, strong) UIButton *button;

@end

@implementation SleepModeContentViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor =
        [UIColor systemBackgroundColor];

    self.titleLabel =
        [[UILabel alloc] init];

    self.titleLabel.text =
        @"Chế độ ngủ";

    self.titleLabel.font =
        [UIFont systemFontOfSize:17
                          weight:UIFontWeightSemibold];

    self.titleLabel.textAlignment =
        NSTextAlignmentCenter;

    self.statusLabel =
        [[UILabel alloc] init];

    self.statusLabel.font =
        [UIFont systemFontOfSize:13
                          weight:UIFontWeightRegular];

    self.statusLabel.textAlignment =
        NSTextAlignmentCenter;

    self.statusLabel.numberOfLines = 2;

    self.button =
        [UIButton buttonWithType:UIButtonTypeSystem];

    [self.button setTitle:@"Bật"
                 forState:UIControlStateNormal];

    self.button.titleLabel.font =
        [UIFont systemFontOfSize:15
                          weight:UIFontWeightMedium];

    [self.button addTarget:self
                    action:@selector(togglePressed)
          forControlEvents:UIControlEventTouchUpInside];

    UIStackView *stack =
        [[UIStackView alloc]
            initWithArrangedSubviews:@[
                self.titleLabel,
                self.statusLabel,
                self.button
            ]];

    stack.axis =
        UILayoutConstraintAxisVertical;

    stack.spacing = 8.0;

    stack.alignment =
        UIStackViewAlignmentFill;

    stack.translatesAutoresizingMaskIntoConstraints =
        NO;

    [self.view addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor
            constraintEqualToAnchor:self.view.leadingAnchor
                           constant:8.0],

        [stack.trailingAnchor
            constraintEqualToAnchor:self.view.trailingAnchor
                           constant:-8.0],

        [stack.topAnchor
            constraintEqualToAnchor:self.view.topAnchor
                           constant:6.0],

        [stack.bottomAnchor
            constraintEqualToAnchor:self.view.bottomAnchor
                           constant:-6.0]
    ]];

    UILongPressGestureRecognizer *longPress =
        [[UILongPressGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(longPressed:)];

    longPress.minimumPressDuration =
        0.5;

    [self.button addGestureRecognizer:longPress];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(stateChanged:)
               name:kSleepModeStateChangedNotification
             object:nil];

    [self updateUI];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter]
        removeObserver:self];
}

#pragma mark - State

- (BOOL)isEnabled
{
    return [[NSUserDefaults standardUserDefaults]
                boolForKey:kSleepModeEnabledKey];
}

- (NSTimeInterval)timeout
{
    NSTimeInterval timeout =
        [[NSUserDefaults standardUserDefaults]
            doubleForKey:kSleepModeTimeoutKey];

    if (timeout <= 0)
        timeout = 15.0;

    return timeout;
}

#pragma mark - UI

- (void)updateUI
{
    BOOL enabled =
        [self isEnabled];

    NSTimeInterval timeout =
        [self timeout];

    if (enabled) {

        [self.button setTitle:@"Đang bật"
                     forState:UIControlStateNormal];

        self.statusLabel.text =
            [NSString stringWithFormat:
                @"Tự khóa sau %@",
                [self timeoutText:timeout]];

    } else {

        [self.button setTitle:@"Đang tắt"
                     forState:UIControlStateNormal];

        self.statusLabel.text =
            @"Chạm để bật";
    }
}

- (NSString *)timeoutText:(NSTimeInterval)timeout
{
    if (timeout < 60.0) {
        return [NSString stringWithFormat:
            @"%.0f giây",
            timeout];
    }

    if (timeout < 3600.0) {

        NSInteger minutes =
            (NSInteger)(timeout / 60.0);

        return [NSString stringWithFormat:
            @"%ld phút",
            (long)minutes];
    }

    NSInteger hours =
        (NSInteger)(timeout / 3600.0);

    return [NSString stringWithFormat:
        @"%ld giờ",
        (long)hours];
}

#pragma mark - Toggle

- (void)togglePressed
{
    BOOL enabled =
        ![self isEnabled];

    [[NSUserDefaults standardUserDefaults]
        setBool:enabled
        forKey:kSleepModeEnabledKey];

    [[NSUserDefaults standardUserDefaults]
        synchronize];

    [self postCommand:@{
        @"enabled": @(enabled)
    }];

    [self updateUI];
}

#pragma mark - Timeout

- (void)longPressed:(UILongPressGestureRecognizer *)gesture
{
    if (gesture.state !=
        UIGestureRecognizerStateBegan) {
        return;
    }

    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:@"Thời gian tự khóa"
                             message:@"Chọn thời gian"
                      preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray *items = @[
        @[@"15 giây", @15.0],
        @[@"1 phút",  @60.0],
        @[@"5 phút",  @300.0],
        @[@"15 phút", @900.0],
        @[@"30 phút", @1800.0],
        @[@"1 giờ", @3600.0],
        @[@"2 giờ", @7200.0]
    ];

    for (NSArray *item in items) {

        NSString *title =
            item[0];

        NSNumber *value =
            item[1];

        UIAlertAction *action =
            [UIAlertAction
                actionWithTitle:title
                         style:UIAlertActionStyleDefault
                       handler:^(UIAlertAction *action) {

            [[NSUserDefaults standardUserDefaults]
                setDouble:[value doubleValue]
                   forKey:kSleepModeTimeoutKey];

            [[NSUserDefaults standardUserDefaults]
                synchronize];

            [self postCommand:@{
                @"timeout": value
            }];

            [self updateUI];
        }];

        [alert addAction:action];
    }

    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"Hủy"
                     style:UIAlertActionStyleCancel
                   handler:nil]];

    [self presentViewController:alert
                       animated:YES
                     completion:nil];
}

#pragma mark - Notification

- (void)stateChanged:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateUI];
    });
}

#pragma mark - Command

- (void)postCommand:(NSDictionary *)info
{
    [[NSNotificationCenter defaultCenter]
        postNotificationName:kSleepModeCommandNotification
                      object:nil
                    userInfo:info];
}

@end

#pragma mark - CCUIContentModule

@interface SleepModeModule :
    NSObject <CCUIContentModule>

@property(nonatomic, strong)
    SleepModeContentViewController *viewController;

@end

@implementation SleepModeModule

- (instancetype)init
{
    self = [super init];

    if (self) {
        _viewController =
            [[SleepModeContentViewController alloc]
                init];
    }

    return self;
}

- (UIViewController *)contentViewController
{
    return self.viewController;
}

- (BOOL)isContentModuleEnabled
{
    return [[NSUserDefaults standardUserDefaults]
                boolForKey:kSleepModeEnabledKey];
}

- (void)setContentModuleEnabled:(BOOL)enabled
{
    [[NSUserDefaults standardUserDefaults]
        setBool:enabled
        forKey:kSleepModeEnabledKey];

    [[NSUserDefaults standardUserDefaults]
        synchronize];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:kSleepModeCommandNotification
                      object:nil
                    userInfo:@{
                        @"enabled": @(enabled)
                    }];

    [self.viewController updateUI];
}

@end
