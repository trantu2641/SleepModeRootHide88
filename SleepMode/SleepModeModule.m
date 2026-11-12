#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#pragma mark - Private Control Center interfaces

@interface CCUIContentModuleContext : NSObject
- (void)requestExpandModule;
- (void)requestDismissModule;
- (void)setModule:(id)module;
@end

@interface CCUIContentModule : NSObject
@end

#pragma mark - Content View Controller

@interface SleepModeContentViewController : UIViewController
@property(nonatomic, assign) BOOL enabled;
@property(nonatomic, strong) UIButton *button;
@end

#pragma mark - Module

@interface SleepModeModule : CCUIContentModule

@property(nonatomic, strong)
SleepModeContentViewController *viewController;

@property(nonatomic, strong)
id contentModuleContext;

@end


#pragma mark - Constants

static NSString * const SleepModeEnabledKey =
    @"SleepModeEnabled";

static NSString * const SleepModeTimeoutKey =
    @"SleepModeTimeout";

static NSString * const SleepModeCommandNotification =
    @"com.trantu.sleepmode.command";

static NSString * const SleepModeStateChangedNotification =
    @"com.trantu.sleepmode.stateChanged";


#pragma mark - Settings

static BOOL SleepModeIsEnabled(void)
{
    return [[NSUserDefaults standardUserDefaults]
            boolForKey:SleepModeEnabledKey];
}

static NSTimeInterval SleepModeTimeout(void)
{
    NSTimeInterval timeout =
        [[NSUserDefaults standardUserDefaults]
            doubleForKey:SleepModeTimeoutKey];

    if (timeout <= 0.0)
        timeout = 15.0;

    return timeout;
}

static void SleepModeSetEnabled(BOOL enabled)
{
    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    [defaults setBool:enabled
               forKey:SleepModeEnabledKey];

    [defaults synchronize];

    NSDictionary *info = @{
        @"enabled": @(enabled)
    };

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SleepModeCommandNotification
        object:nil
        userInfo:info];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SleepModeStateChangedNotification
        object:nil];
}

static void SleepModeSetTimeout(NSTimeInterval timeout)
{
    if (timeout < 1.0)
        timeout = 1.0;

    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    [defaults setDouble:timeout
                 forKey:SleepModeTimeoutKey];

    [defaults synchronize];

    NSDictionary *info = @{
        @"timeout": @(timeout)
    };

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SleepModeCommandNotification
        object:nil
        userInfo:info];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SleepModeStateChangedNotification
        object:nil];
}


#pragma mark - Content View Controller

@implementation SleepModeContentViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor =
        [UIColor clearColor];

    self.enabled =
        SleepModeIsEnabled();

    UIButton *button =
        [UIButton buttonWithType:UIButtonTypeSystem];

    button.translatesAutoresizingMaskIntoConstraints = NO;

    UIImage *image =
        [UIImage systemImageNamed:@"moon.fill"];

    [button setImage:image
            forState:UIControlStateNormal];

    button.tintColor =
        [UIColor whiteColor];

    button.layer.cornerRadius = 12.0;

    button.backgroundColor =
        [UIColor colorWithWhite:1.0
                         alpha:0.12];

    [button addTarget:self
               action:@selector(toggleSleepMode)
     forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:button];

    [NSLayoutConstraint activateConstraints:@[
        [button.leadingAnchor
            constraintEqualToAnchor:self.view.leadingAnchor
                           constant:8.0],

        [button.trailingAnchor
            constraintEqualToAnchor:self.view.trailingAnchor
                           constant:-8.0],

        [button.topAnchor
            constraintEqualToAnchor:self.view.topAnchor
                           constant:8.0],

        [button.bottomAnchor
            constraintEqualToAnchor:self.view.bottomAnchor
                           constant:-8.0]
    ]];

    self.button = button;

    [self updateAppearance];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    self.enabled =
        SleepModeIsEnabled();

    [self updateAppearance];
}

- (void)toggleSleepMode
{
    BOOL enabled =
        !SleepModeIsEnabled();

    SleepModeSetEnabled(enabled);

    self.enabled = enabled;

    [self updateAppearance];
}

- (void)updateAppearance
{
    if (!self.button)
        return;

    BOOL enabled =
        SleepModeIsEnabled();

    UIImage *image =
        [UIImage systemImageNamed:
            enabled ? @"moon.fill" : @"moon"];

    [self.button setImage:image
                  forState:UIControlStateNormal];

    self.button.tintColor =
        enabled
        ? [UIColor whiteColor]
        : [UIColor colorWithWhite:1.0 alpha:0.75];
}

@end


#pragma mark - SleepModeModule

@implementation SleepModeModule

- (instancetype)init
{
    self = [super init];

    if (self)
    {
        _viewController =
            [[SleepModeContentViewController alloc]
                init];
    }

    return self;
}


#pragma mark - Required Control Center state

- (BOOL)isContentModuleEnabled
{
    return SleepModeIsEnabled();
}

- (void)setContentModuleEnabled:(BOOL)enabled
{
    SleepModeSetEnabled(enabled);

    [self.viewController
        updateAppearance];
}


#pragma mark - Content controller

- (UIViewController *)
    contentViewController
{
    if (!_viewController)
    {
        _viewController =
            [[SleepModeContentViewController alloc]
                init];
    }

    return _viewController;
}


#pragma mark - Context

- (void)setContentModuleContext:
    (id)context
{
    _contentModuleContext = context;
}


#pragma mark - Refresh

- (void)refreshState
{
    self.viewController.enabled =
        SleepModeIsEnabled();

    [self.viewController
        updateAppearance];
}

@end
