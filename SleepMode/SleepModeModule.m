#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#pragma mark - Private Control Center Protocols

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


static NSString * const SMEnabledKey = @"SleepModeEnabled";
static NSString * const SMTimeoutKey = @"SleepModeTimeout";

static NSString * const SMCommandNotification =
    @"com.trantu.sleepmode.command";

static NSString * const SMStateChangedNotification =
    @"com.trantu.sleepmode.stateChanged";


#pragma mark - Shared State

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

    NSLog(@"[SleepMode] timeout = %.0f", timeout);

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

@property(nonatomic, strong) UIButton *toggleButton;
@property(nonatomic, strong) UILabel *statusLabel;

@end


@implementation SleepModeContentViewController

- (instancetype)init
{
    self = [super init];

    if (self) {
        self.preferredContentSize =
            CGSizeMake(320.0, 180.0);
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

    CGFloat height =
        self.view.bounds.size.height;

    if (width <= 0.0) {
        width = 320.0;
    }

    if (height <= 0.0) {
        height = 180.0;
    }


    self.statusLabel =
        [[UILabel alloc] initWithFrame:
            CGRectMake(20.0,
                       20.0,
                       width - 40.0,
                       35.0)];

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
                   70.0,
                   width - 40.0,
                   50.0);

    self.toggleButton.layer.cornerRadius =
        12.0;

    self.toggleButton.backgroundColor =
        [UIColor secondarySystemBackgroundColor];

    [self.toggleButton setTitle:
        @"Bật / Tắt"
        forState:UIControlStateNormal];

    [self.toggleButton addTarget:self
                          action:@selector(togglePressed:)
                forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:self.toggleButton];


    [self updateUI];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(stateChanged:)
               name:SMStateChangedNotification
             object:nil];
}


- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    [self updateUI];
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter]
        removeObserver:self];
}


- (void)stateChanged:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateUI];
    });
}


- (void)updateUI
{
    BOOL enabled = SMIsEnabled();

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
}


- (void)togglePressed:(id)sender
{
    (void)sender;

    SMSetEnabled(!SMIsEnabled());
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


#pragma mark - CCUIContentModule

- (UIViewController<CCUIContentModuleContentViewController> *)
    contentViewController
{
    return self.viewController;
}


- (void)setContentModuleContext:
    (id<CCUIContentModuleContext>)context
{
    _contentModuleContext = context;
}


- (BOOL)isContentModuleEnabled
{
    return SMIsEnabled();
}


- (void)setContentModuleEnabled:(BOOL)enabled
{
    SMSetEnabled(enabled);
}


#pragma mark - Control Center expansion behavior

- (BOOL)shouldExpandModuleOnTouch
{
    return NO;
}


- (BOOL)shouldExpandModuleOnTouchDown
{
    return NO;
}

@end
