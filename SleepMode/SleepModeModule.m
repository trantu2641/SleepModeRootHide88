#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#pragma mark - Control Center Protocols

@protocol CCUIContentModuleContext <NSObject>
@optional
- (void)enqueueUserInitiatedTaskWithCompletionHandler:(void (^)(void))completion;
@end

@protocol CCUIContentModuleContentViewController <NSObject>
@required
- (BOOL)shouldExpandModuleOnTouch;
- (BOOL)shouldExpandModuleOnTouchDown;
@end

@protocol CCUIContentModule <NSObject>
@required
- (UIViewController<CCUIContentModuleContentViewController> *)contentViewController;
- (void)setContentModuleContext:(id<CCUIContentModuleContext>)context;
- (BOOL)isContentModuleEnabled;
- (void)setContentModuleEnabled:(BOOL)enabled;
@end


#pragma mark - Constants

static NSString * const SMEnabledKey =
    @"SleepModeEnabled";

static NSString * const SMTimeoutKey =
    @"SleepModeTimeout";

static NSString * const SMCommandNotification =
    @"com.trantu.sleepmode.command";

static NSString * const SMStateChangedNotification =
    @"com.trantu.sleepmode.stateChanged";


#pragma mark - State

static BOOL SMIsEnabled(void)
{
    return [[NSUserDefaults standardUserDefaults]
            boolForKey:SMEnabledKey];
}


static void SMSetEnabled(BOOL enabled)
{
    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    [defaults setBool:enabled
               forKey:SMEnabledKey];

    [defaults synchronize];

    NSLog(@"[SleepMode] enabled = %d", enabled);

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SMCommandNotification
        object:nil
        userInfo:@{
            @"enabled": @(enabled)
        }];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SMStateChangedNotification
        object:nil];
}


static NSTimeInterval SMCurrentTimeout(void)
{
    NSTimeInterval timeout =
        [[NSUserDefaults standardUserDefaults]
            doubleForKey:SMTimeoutKey];

    if (timeout <= 0.0) {
        timeout = 15.0;
    }

    return timeout;
}


static void SMSetTimeout(NSTimeInterval timeout)
{
    if (timeout < 1.0) {
        timeout = 1.0;
    }

    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    [defaults setDouble:timeout
                 forKey:SMTimeoutKey];

    [defaults synchronize];

    NSLog(@"[SleepMode] timeout = %.0f seconds",
          timeout);

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SMCommandNotification
        object:nil
        userInfo:@{
            @"timeout": @(timeout)
        }];

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SMStateChangedNotification
        object:nil];
}


static void SMResetTimer(void)
{
    NSLog(@"[SleepMode] reset timer");

    [[NSNotificationCenter defaultCenter]
        postNotificationName:SMCommandNotification
        object:nil
        userInfo:@{
            @"reset": @YES
        }];
}


#pragma mark - Content View Controller

@interface SleepModeContentViewController :
    UIViewController
    <CCUIContentModuleContentViewController>

@property(nonatomic, strong)
    UILabel *statusLabel;

@property(nonatomic, strong)
    UIButton *toggleButton;

@property(nonatomic, strong)
    UIButton *timeoutButton;

@end


@implementation SleepModeContentViewController

- (instancetype)init
{
    self = [super init];

    if (self) {
        self.preferredContentSize =
            CGSizeMake(320.0, 220.0);
    }

    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor =
        [UIColor clearColor];

    CGFloat width =
        self.view.bounds.size.width;

    if (width <= 0.0) {
        width = 320.0;
    }


    self.statusLabel =
        [[UILabel alloc]
            initWithFrame:
                CGRectMake(20.0,
                           18.0,
                           width - 40.0,
                           32.0)];

    self.statusLabel.textAlignment =
        NSTextAlignmentCenter;

    self.statusLabel.font =
        [UIFont systemFontOfSize:18.0
                          weight:UIFontWeightSemibold];

    [self.view addSubview:self.statusLabel];


    self.toggleButton =
        [UIButton buttonWithType:UIButtonTypeSystem];

    self.toggleButton.frame =
        CGRectMake(20.0,
                   60.0,
                   width - 40.0,
                   48.0);

    self.toggleButton.layer.cornerRadius =
        12.0;

    self.toggleButton.backgroundColor =
        [UIColor secondarySystemBackgroundColor];

    [self.toggleButton addTarget:self
                          action:@selector(togglePressed:)
                forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:self.toggleButton];


    self.timeoutButton =
        [UIButton buttonWithType:UIButtonTypeSystem];

    self.timeoutButton.frame =
        CGRectMake(20.0,
                   118.0,
                   width - 40.0,
                   48.0);

    self.timeoutButton.layer.cornerRadius =
        12.0;

    self.timeoutButton.backgroundColor =
        [UIColor secondarySystemBackgroundColor];

    [self.timeoutButton addTarget:self
                           action:@selector(timeoutPressed:)
                 forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:self.timeoutButton];


    [self updateUI];


    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(stateChanged:)
               name:SMStateChangedNotification
             object:nil];
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter]
        removeObserver:self];
}


- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    [self updateUI];
}


- (void)stateChanged:(NSNotification *)notification
{
    (void)notification;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateUI];
    });
}


- (void)updateUI
{
    BOOL enabled =
        SMIsEnabled();

    NSTimeInterval timeout =
        SMCurrentTimeout();

    NSString *timeoutText;

    if (timeout < 60.0) {

        timeoutText =
            [NSString stringWithFormat:
                @"%d giây",
                (int)timeout];

    } else if (timeout < 3600.0) {

        timeoutText =
            [NSString stringWithFormat:
                @"%d phút",
                (int)(timeout / 60.0)];

    } else {

        timeoutText =
            [NSString stringWithFormat:
                @"%d giờ",
                (int)(timeout / 3600.0)];
    }


    if (enabled) {

        self.statusLabel.text =
            @"Chế độ ngủ: ĐANG BẬT";

        [self.toggleButton
            setTitle:@"Tắt chế độ ngủ"
            forState:UIControlStateNormal];

    } else {

        self.statusLabel.text =
            @"Chế độ ngủ: ĐANG TẮT";

        [self.toggleButton
            setTitle:@"Bật chế độ ngủ"
            forState:UIControlStateNormal];
    }


    [self.timeoutButton
        setTitle:
            [NSString stringWithFormat:
                @"Tự khóa sau: %@",
                timeoutText]
        forState:UIControlStateNormal];
}


#pragma mark - Actions

- (void)togglePressed:(id)sender
{
    (void)sender;

    SMSetEnabled(!SMIsEnabled());
}


- (void)timeoutPressed:(id)sender
{
    (void)sender;

    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:@"Thời gian tự khóa"
            message:@"Chọn thời gian chờ"
            preferredStyle:UIAlertControllerStyleActionSheet];


    NSArray *items = @[
        @{@"title": @"15 giây", @"value": @15.0},
        @{@"title": @"1 phút",  @"value": @60.0},
        @{@"title": @"5 phút",  @"value": @300.0},
        @{@"title": @"15 phút", @"value": @900.0},
        @{@"title": @"30 phút", @"value": @1800.0},
        @{@"title": @"1 giờ",   @"value": @3600.0},
        @{@"title": @"2 giờ",   @"value": @7200.0}
    ];


    NSTimeInterval current =
        SMCurrentTimeout();


    for (NSDictionary *item in items) {

        NSString *title =
            item[@"title"];

        NSNumber *value =
            item[@"value"];

        BOOL selected =
            fabs(current - value.doubleValue) < 0.5;

        NSString *displayTitle =
            selected
                ? [NSString stringWithFormat:
                    @"✓ %@",
                    title]
                : title;


        UIAlertAction *action =
            [UIAlertAction
                actionWithTitle:displayTitle
                style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {

            (void)action;

            SMSetTimeout(
                value.doubleValue
            );

            if (SMIsEnabled()) {
                SMResetTimer();
            }
        }];


        [alert addAction:action];
    }


    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"Hủy"
            style:UIAlertActionStyleCancel
            handler:nil]];


    UIViewController *presenting =
        self.presentingViewController;

    if (!presenting) {
        presenting = self;
    }


    UIPopoverPresentationController *popover =
        alert.popoverPresentationController;

    if (popover) {

        popover.sourceView =
            self.view;

        popover.sourceRect =
            CGRectMake(
                CGRectGetMidX(
                    self.view.bounds
                ),
                CGRectGetMidY(
                    self.view.bounds
                ),
                1.0,
                1.0
            );
    }


    [presenting
        presentViewController:alert
        animated:YES
        completion:nil];
}


#pragma mark - CCUIContentModuleContentViewController

- (BOOL)shouldExpandModuleOnTouch
{
    return NO;
}


- (BOOL)shouldExpandModuleOnTouchDown
{
    return NO;
}

@end


#pragma mark - SleepModeModule

@interface SleepModeModule :
    NSObject
    <CCUIContentModule>

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
            [[SleepModeContentViewController alloc]
                init];
    }

    return self;
}


- (UIViewController<CCUIContentModuleContentViewController> *)
    contentViewController
{
    return self.viewController;
}


- (void)setContentModuleContext:
    (id<CCUIContentModuleContext>)context
{
    _contentModuleContext =
        context;
}


- (BOOL)isContentModuleEnabled
{
    return SMIsEnabled();
}


- (void)setContentModuleEnabled:(BOOL)enabled
{
    SMSetEnabled(enabled);
}

@end
