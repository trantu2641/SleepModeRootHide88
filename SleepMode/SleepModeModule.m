#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

/*
 * Không link ControlCenterUIKit trong Makefile.
 * Khai báo protocol tối thiểu để bundle tự load trên iOS 16.x.
 */

@protocol CCUIContentModuleContext <NSObject>
@optional
- (void)dismissModule;
- (void)requestExpandModule;
- (void)requestDismiss;
@end

@protocol CCUIContentModule <NSObject>
@required
- (UIViewController *)contentViewController;
- (BOOL)isContentModuleEnabled;
- (void)setContentModuleEnabled:(BOOL)enabled;
@optional
- (void)setContentModuleContext:(id<CCUIContentModuleContext>)context;
@end

@protocol CCUIContentModuleContentViewController <NSObject>
@optional
- (BOOL)shouldExpandModuleOnTouch;
- (BOOL)shouldExpandModuleOnTouchDown;
- (void)willBecomeActive;
- (void)willResignActive;
- (void)buttonTapped:(id)sender;
@end


#pragma mark - SleepMode Shared Settings

static NSString * const kSleepModeEnabledKey = @"SleepModeEnabled";
static NSString * const kSleepModeTimeoutKey = @"SleepModeTimeout";


#pragma mark - Settings

static BOOL SleepModeEnabled(void)
{
    return [[NSUserDefaults standardUserDefaults]
            boolForKey:kSleepModeEnabledKey];
}

static void SleepModeSetEnabled(BOOL enabled)
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    [defaults setBool:enabled
               forKey:kSleepModeEnabledKey];

    [defaults synchronize];

    /*
     * Tweak đang inject SpringBoard sẽ nhận notification này.
     */
    [[NSNotificationCenter defaultCenter]
        postNotificationName:@"com.trantu.sleepmode.command"
                      object:nil
                    userInfo:@{
                        @"enabled" : @(enabled)
                    }];
}


static NSTimeInterval SleepModeTimeout(void)
{
    NSTimeInterval timeout =
        [[NSUserDefaults standardUserDefaults]
            doubleForKey:kSleepModeTimeoutKey];

    if (timeout <= 0.0) {
        timeout = 15.0;
    }

    return timeout;
}


static void SleepModeSetTimeout(NSTimeInterval timeout)
{
    if (timeout < 1.0) {
        timeout = 1.0;
    }

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    [defaults setDouble:timeout
                 forKey:kSleepModeTimeoutKey];

    [defaults synchronize];

    /*
     * Báo cho SleepManager cập nhật timeout ngay.
     */
    [[NSNotificationCenter defaultCenter]
        postNotificationName:@"com.trantu.sleepmode.command"
                      object:nil
                    userInfo:@{
                        @"timeout" : @(timeout)
                    }];
}


#pragma mark - Content View Controller

@interface SleepModeContentViewController :
    UIViewController <CCUIContentModuleContentViewController>

@property(nonatomic, strong) UIView *containerView;
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UILabel *statusLabel;
@property(nonatomic, strong) UIButton *toggleButton;
@property(nonatomic, strong) UIButton *timeoutButton;

@end


@implementation SleepModeContentViewController


- (instancetype)init
{
    self = [super init];

    if (self) {
        self.view.backgroundColor =
            [UIColor clearColor];
    }

    return self;
}


- (void)loadView
{
    UIView *rootView =
        [[UIView alloc] initWithFrame:CGRectZero];

    rootView.backgroundColor =
        [UIColor clearColor];

    self.view = rootView;
}


- (void)viewDidLoad
{
    [super viewDidLoad];

    [self buildUI];
    [self refreshUI];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(stateChanged:)
               name:@"com.trantu.sleepmode.stateChanged"
             object:nil];
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter]
        removeObserver:self];
}


#pragma mark - UI

- (void)buildUI
{
    self.containerView =
        [[UIView alloc] initWithFrame:CGRectZero];

    self.containerView.translatesAutoresizingMaskIntoConstraints = NO;

    self.containerView.backgroundColor =
        [UIColor clearColor];

    [self.view addSubview:self.containerView];


    self.titleLabel =
        [[UILabel alloc] initWithFrame:CGRectZero];

    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    self.titleLabel.text =
        @"Chế độ ngủ";

    self.titleLabel.textColor =
        [UIColor whiteColor];

    self.titleLabel.font =
        [UIFont systemFontOfSize:16.0
                          weight:UIFontWeightSemibold];

    [self.containerView addSubview:self.titleLabel];


    self.statusLabel =
        [[UILabel alloc] initWithFrame:CGRectZero];

    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;

    self.statusLabel.textColor =
        [UIColor secondaryLabelColor];

    self.statusLabel.font =
        [UIFont systemFontOfSize:13.0
                          weight:UIFontWeightRegular];

    [self.containerView addSubview:self.statusLabel];


    self.toggleButton =
        [UIButton buttonWithType:UIButtonTypeSystem];

    self.toggleButton.translatesAutoresizingMaskIntoConstraints = NO;

    [self.toggleButton setTitle:@"BẬT"
                       forState:UIControlStateNormal];

    self.toggleButton.titleLabel.font =
        [UIFont systemFontOfSize:15.0
                          weight:UIFontWeightSemibold];

    [self.toggleButton addTarget:self
                          action:@selector(togglePressed:)
                forControlEvents:UIControlEventTouchUpInside];

    [self.containerView addSubview:self.toggleButton];


    self.timeoutButton =
        [UIButton buttonWithType:UIButtonTypeSystem];

    self.timeoutButton.translatesAutoresizingMaskIntoConstraints = NO;

    self.timeoutButton.titleLabel.font =
        [UIFont systemFontOfSize:13.0
                          weight:UIFontWeightMedium];

    [self.timeoutButton addTarget:self
                           action:@selector(timeoutPressed:)
                 forControlEvents:UIControlEventTouchUpInside];

    [self.containerView addSubview:self.timeoutButton];


    [NSLayoutConstraint activateConstraints:@[

        [self.containerView.leadingAnchor
            constraintEqualToAnchor:self.view.leadingAnchor
                           constant:12.0],

        [self.containerView.trailingAnchor
            constraintEqualToAnchor:self.view.trailingAnchor
                           constant:-12.0],

        [self.containerView.topAnchor
            constraintEqualToAnchor:self.view.topAnchor
                           constant:10.0],

        [self.containerView.bottomAnchor
            constraintEqualToAnchor:self.view.bottomAnchor
                            constant:-10.0],


        [self.titleLabel.leadingAnchor
            constraintEqualToAnchor:self.containerView.leadingAnchor],

        [self.titleLabel.topAnchor
            constraintEqualToAnchor:self.containerView.topAnchor],

        [self.titleLabel.trailingAnchor
            constraintEqualToAnchor:self.containerView.trailingAnchor],


        [self.statusLabel.leadingAnchor
            constraintEqualToAnchor:self.titleLabel.leadingAnchor],

        [self.statusLabel.topAnchor
            constraintEqualToAnchor:self.titleLabel.bottomAnchor
                           constant:4.0],

        [self.statusLabel.trailingAnchor
            constraintEqualToAnchor:self.titleLabel.trailingAnchor],


        [self.toggleButton.leadingAnchor
            constraintEqualToAnchor:self.containerView.leadingAnchor],

        [self.toggleButton.topAnchor
            constraintEqualToAnchor:self.statusLabel.bottomAnchor
                           constant:8.0],

        [self.toggleButton.heightAnchor
            constraintEqualToConstant:36.0],


        [self.timeoutButton.leadingAnchor
            constraintEqualToAnchor:self.toggleButton.trailingAnchor
                           constant:8.0],

        [self.timeoutButton.trailingAnchor
            constraintEqualToAnchor:self.containerView.trailingAnchor],

        [self.timeoutButton.centerYAnchor
            constraintEqualToAnchor:self.toggleButton.centerYAnchor],

        [self.timeoutButton.heightAnchor
            constraintEqualToConstant:36.0]
    ]];
}


#pragma mark - State

- (void)refreshUI
{
    BOOL enabled = SleepModeEnabled();

    NSTimeInterval timeout =
        SleepModeTimeout();

    NSString *timeoutText =
        [self timeoutText:timeout];


    if (enabled) {

        self.statusLabel.text =
            [NSString stringWithFormat:
                @"Đang bật • Tự khóa sau %@",
                timeoutText];

        [self.toggleButton
            setTitle:@"TẮT"
           forState:UIControlStateNormal];

    } else {

        self.statusLabel.text =
            [NSString stringWithFormat:
                @"Đang tắt • %@",
                timeoutText];

        [self.toggleButton
            setTitle:@"BẬT"
           forState:UIControlStateNormal];
    }


    [self.timeoutButton
        setTitle:[NSString stringWithFormat:
                  @"Thời gian: %@",
                  timeoutText]
      forState:UIControlStateNormal];
}


- (NSString *)timeoutText:(NSTimeInterval)timeout
{
    if (timeout < 60.0) {

        return [NSString stringWithFormat:
                @"%.0f giây",
                timeout];

    } else if (timeout < 3600.0) {

        NSInteger minutes =
            (NSInteger)round(timeout / 60.0);

        return [NSString stringWithFormat:
                @"%ld phút",
                (long)minutes];

    } else {

        NSInteger hours =
            (NSInteger)round(timeout / 3600.0);

        return [NSString stringWithFormat:
                @"%ld giờ",
                (long)hours];
    }
}


#pragma mark - Notification

- (void)stateChanged:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshUI];
    });
}


#pragma mark - Actions

- (void)togglePressed:(id)sender
{
    BOOL enabled =
        SleepModeEnabled();

    SleepModeSetEnabled(!enabled);

    [self refreshUI];
}


- (void)timeoutPressed:(id)sender
{
    NSTimeInterval current =
        SleepModeTimeout();

    NSTimeInterval nextTimeout = 15.0;

    if (current <= 15.0) {
        nextTimeout = 60.0;
    }
    else if (current <= 60.0) {
        nextTimeout = 300.0;
    }
    else if (current <= 300.0) {
        nextTimeout = 900.0;
    }
    else if (current <= 900.0) {
        nextTimeout = 1800.0;
    }
    else if (current <= 1800.0) {
        nextTimeout = 3600.0;
    }
    else {
        nextTimeout = 7200.0;
    }

    SleepModeSetTimeout(nextTimeout);

    [self refreshUI];
}


#pragma mark - Control Center Content VC

- (BOOL)shouldExpandModuleOnTouch
{
    return YES;
}


- (BOOL)shouldExpandModuleOnTouchDown
{
    return NO;
}


- (void)willBecomeActive
{
    [self refreshUI];
}


- (void)willResignActive
{
}


@end



#pragma mark - SleepModeModule

@interface SleepModeModule : NSObject <CCUIContentModule>

@property(nonatomic, strong)
    SleepModeContentViewController *viewController;

@property(nonatomic, weak)
    id<CCUIContentModuleContext> contentModuleContext;

@end


@implementation SleepModeModule


- (instancetype)init
{
    self = [super init];

    if (self) {

        _viewController =
            [[SleepModeContentViewController alloc] init];
    }

    return self;
}


#pragma mark - CCUIContentModule

- (UIViewController *)contentViewController
{
    if (!self.viewController) {

        self.viewController =
            [[SleepModeContentViewController alloc] init];
    }

    return self.viewController;
}


- (BOOL)isContentModuleEnabled
{
    return SleepModeEnabled();
}


- (void)setContentModuleEnabled:(BOOL)enabled
{
    SleepModeSetEnabled(enabled);

    if (self.viewController) {
        [self.viewController refreshUI];
    }
}


- (void)setContentModuleContext:
    (id<CCUIContentModuleContext>)context
{
    _contentModuleContext = context;
}


@end
