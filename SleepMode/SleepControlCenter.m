#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "SleepControlCenter.h"
#import "SleepManager.h"


#pragma mark - Minimal Control Center Protocol

@protocol CCUIContentModule <NSObject>

@optional

- (UIViewController *)contentViewController;

- (UIViewController *)backgroundViewController;

- (void)setContentModuleContext:(id)context;

@end


#pragma mark - SleepMode Module

@interface SleepModeModule : NSObject <CCUIContentModule>

@property(nonatomic, strong)
    id contentModuleContext;

@property(nonatomic, strong)
    UIViewController *contentViewController;

@end


#pragma mark - Content View Controller

@interface SleepModeModuleContentViewController : UIViewController

@property(nonatomic, strong)
    UIButton *button;

@property(nonatomic, strong)
    UILabel *label;

@end


@implementation SleepModeModule

- (instancetype)init
{
    self = [super init];

    if (self) {

        [[SleepControlCenter sharedInstance]
            addObserver:self
            forKeyPath:@"enabled"
            options:NSKeyValueObservingOptionInitial |
                    NSKeyValueObservingOptionNew
            context:NULL];
    }

    return self;
}

- (void)dealloc
{
    @try {

        [[SleepControlCenter sharedInstance]
            removeObserver:self
            forKeyPath:@"enabled"];

    } @catch (__unused NSException *exception) {
    }
}

#pragma mark - Control Center Context

- (void)setContentModuleContext:(id)context
{
    _contentModuleContext = context;
}

#pragma mark - Content View Controller

- (UIViewController *)contentViewController
{
    if (!_contentViewController) {

        _contentViewController =
            [[SleepModeModuleContentViewController alloc] init];
    }

    return _contentViewController;
}

#pragma mark - State

- (void)updateModuleState
{
    SleepControlCenter *controlCenter =
        [SleepControlCenter sharedInstance];

    BOOL enabled = controlCenter.enabled;

    if ([_contentViewController
            isKindOfClass:[SleepModeModuleContentViewController class]]) {

        SleepModeModuleContentViewController *vc =
            (SleepModeModuleContentViewController *)_contentViewController;

        [vc updateState:enabled];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if ([keyPath isEqualToString:@"enabled"]) {

        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateModuleState];
        });

        return;
    }

    [super observeValueForKeyPath:keyPath
                         ofObject:object
                           change:change
                          context:context];
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

    UIButton *button =
        [UIButton buttonWithType:UIButtonTypeSystem];

    button.translatesAutoresizingMaskIntoConstraints = NO;

    button.layer.cornerRadius = 14.0;

    button.titleLabel.font =
        [UIFont systemFontOfSize:20.0
                           weight:UIFontWeightSemibold];

    [button addTarget:self
               action:@selector(buttonPressed:)
     forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:button];

    self.button = button;

    [NSLayoutConstraint activateConstraints:@[

        [button.leadingAnchor
            constraintEqualToAnchor:self.view.leadingAnchor
                           constant:6.0],

        [button.trailingAnchor
            constraintEqualToAnchor:self.view.trailingAnchor
                           constant:-6.0],

        [button.topAnchor
            constraintEqualToAnchor:self.view.topAnchor
                           constant:6.0],

        [button.bottomAnchor
            constraintEqualToAnchor:self.view.bottomAnchor
                           constant:-6.0]
    ]];

    [self updateState:
        [SleepControlCenter sharedInstance].enabled];
}

#pragma mark - Button

- (void)buttonPressed:(UIButton *)sender
{
    SleepControlCenter *controlCenter =
        [SleepControlCenter sharedInstance];

    [controlCenter toggle];

    [self updateState:controlCenter.enabled];
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

    [self.button setTitle:title
                  forState:UIControlStateNormal];

    if (enabled) {

        self.button.backgroundColor =
            [UIColor colorWithWhite:1.0
                              alpha:0.25];

        [self.button setTitleColor:
            [UIColor whiteColor]
                          forState:UIControlStateNormal];

    } else {

        self.button.backgroundColor =
            [UIColor colorWithWhite:0.0
                              alpha:0.18];

        [self.button setTitleColor:
            [UIColor colorWithWhite:1.0
                              alpha:0.65]
                          forState:UIControlStateNormal];
    }
}

@end
