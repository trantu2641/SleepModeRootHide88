#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <math.h>


#pragma mark - Runtime helpers

static Class SleepControlCenterClass(void)
{
    return NSClassFromString(@"SleepControlCenter");
}

static id SleepControlCenterInstance(void)
{
    Class cls = SleepControlCenterClass();

    if (!cls) {
        return nil;
    }

    SEL selector = NSSelectorFromString(@"sharedInstance");

    if (![cls respondsToSelector:selector]) {
        return nil;
    }

    return ((id (*)(id, SEL))objc_msgSend)(cls, selector);
}


static BOOL SleepIsEnabled(void)
{
    id manager = SleepControlCenterInstance();

    if (!manager) {
        return NO;
    }

    SEL selector = NSSelectorFromString(@"isEnabled");

    if (![manager respondsToSelector:selector]) {
        return NO;
    }

    return ((BOOL (*)(id, SEL))objc_msgSend)(manager, selector);
}


static NSTimeInterval SleepCurrentTimeout(void)
{
    id manager = SleepControlCenterInstance();

    if (!manager) {
        return 15.0;
    }

    SEL selector = NSSelectorFromString(@"currentTimeout");

    if (![manager respondsToSelector:selector]) {
        return 15.0;
    }

    return ((NSTimeInterval (*)(id, SEL))objc_msgSend)(manager, selector);
}


static void SleepToggle(void)
{
    id manager = SleepControlCenterInstance();

    if (!manager) {
        return;
    }

    SEL selector = NSSelectorFromString(@"toggle");

    if ([manager respondsToSelector:selector]) {
        ((void (*)(id, SEL))objc_msgSend)(manager, selector);
    }
}


static void SleepSetTimeout(NSTimeInterval timeout)
{
    id manager = SleepControlCenterInstance();

    if (!manager) {
        return;
    }

    SEL selector = NSSelectorFromString(@"setTimeout:");

    if ([manager respondsToSelector:selector]) {
        ((void (*)(id, SEL, NSTimeInterval))objc_msgSend)(
            manager,
            selector,
            timeout
        );
    }
}


#pragma mark - Notification

static NSString * const
SleepControlCenterStateChangedNotification =
@"com.trantu.sleepmode.stateChanged";


#pragma mark - Content View Controller

@interface SleepModeContentViewController : UIViewController
@end


@implementation SleepModeContentViewController

{
    UIButton *_toggleButton;
    UILabel *_timeoutLabel;
    UIView *_containerView;
    UILongPressGestureRecognizer *_longPressGesture;
}


#pragma mark - Helpers

- (NSString *)timeoutText:(NSTimeInterval)timeout
{
    if (timeout < 60.0) {

        NSInteger seconds = (NSInteger)round(timeout);

        return [NSString stringWithFormat:
                @"%ld giây",
                (long)seconds];
    }

    if (timeout < 3600.0) {

        NSInteger minutes = (NSInteger)round(timeout / 60.0);

        return [NSString stringWithFormat:
                @"%ld phút",
                (long)minutes];
    }

    NSInteger hours = (NSInteger)round(timeout / 3600.0);

    return [NSString stringWithFormat:
            @"%ld giờ",
            (long)hours];
}


- (void)updateUI
{
    BOOL enabled = SleepIsEnabled();
    NSTimeInterval timeout = SleepCurrentTimeout();

    NSString *buttonTitle =
        enabled ? @"Đang bật" : @"Đang tắt";

    NSString *timeoutTitle =
        [NSString stringWithFormat:
            @"Tự động khóa sau %@",
            [self timeoutText:timeout]];

    [_toggleButton setTitle:buttonTitle
                   forState:UIControlStateNormal];

    _timeoutLabel.text = timeoutTitle;

    if (enabled) {

        _toggleButton.alpha = 1.0;
        _timeoutLabel.alpha = 1.0;

    } else {

        _toggleButton.alpha = 0.55;
        _timeoutLabel.alpha = 0.55;
    }
}


#pragma mark - Actions

- (void)togglePressed
{
    SleepToggle();

    [self updateUI];
}


- (void)longPress:(UILongPressGestureRecognizer *)gesture
{
    if (gesture.state != UIGestureRecognizerStateBegan) {
        return;
    }

    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:@"Chế độ ngủ"
            message:@"Chọn thời gian tự động khóa"
            preferredStyle:UIAlertControllerStyleActionSheet];


    NSArray *timeouts = @[
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


    for (NSInteger i = 0;
         i < (NSInteger)timeouts.count;
         i++) {

        NSTimeInterval timeout =
            [timeouts[i] doubleValue];

        NSString *title =
            titles[i];

        UIAlertAction *action =
            [UIAlertAction
                actionWithTitle:title
                style:UIAlertActionStyleDefault
                handler:^(UIAlertAction *action) {

                    SleepSetTimeout(timeout);

                    [self updateUI];
                }];

        [alert addAction:action];
    }


    UIAlertAction *cancel =
        [UIAlertAction
            actionWithTitle:@"Hủy"
            style:UIAlertActionStyleCancel
            handler:nil];

    [alert addAction:cancel];


    UIPopoverPresentationController *popover =
        alert.popoverPresentationController;

    if (popover) {
        popover.sourceView = _toggleButton;
        popover.sourceRect = _toggleButton.bounds;
    }


    [self presentViewController:alert
                       animated:YES
                     completion:nil];
}


#pragma mark - Lifecycle

- (void)loadView
{
    UIView *view =
        [[UIView alloc] initWithFrame:CGRectZero];

    view.backgroundColor = [UIColor clearColor];

    self.view = view;
}


- (void)viewDidLoad
{
    [super viewDidLoad];


    _containerView =
        [[UIView alloc] initWithFrame:CGRectZero];

    _containerView.backgroundColor =
        [UIColor colorWithWhite:0.18 alpha:1.0];

    _containerView.layer.cornerRadius = 18.0;
    _containerView.clipsToBounds = YES;

    _containerView.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:_containerView];


    _toggleButton =
        [UIButton buttonWithType:UIButtonTypeSystem];

    _toggleButton.translatesAutoresizingMaskIntoConstraints = NO;

    _toggleButton.titleLabel.font =
        [UIFont systemFontOfSize:16.0
                          weight:UIFontWeightSemibold];

    [_toggleButton setTitleColor:[UIColor whiteColor]
                         forState:UIControlStateNormal];

    [_toggleButton addTarget:self
                      action:@selector(togglePressed)
            forControlEvents:UIControlEventTouchUpInside];

    [_containerView addSubview:_toggleButton];


    _timeoutLabel =
        [[UILabel alloc] initWithFrame:CGRectZero];

    _timeoutLabel.translatesAutoresizingMaskIntoConstraints = NO;

    _timeoutLabel.textColor =
        [UIColor colorWithWhite:1.0 alpha:0.75];

    _timeoutLabel.font =
        [UIFont systemFontOfSize:11.0
                          weight:UIFontWeightRegular];

    _timeoutLabel.textAlignment =
        NSTextAlignmentCenter;

    _timeoutLabel.numberOfLines = 1;

    [_containerView addSubview:_timeoutLabel];


    _longPressGesture =
        [[UILongPressGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(longPress:)];

    _longPressGesture.minimumPressDuration = 0.5;

    [_toggleButton addGestureRecognizer:_longPressGesture];


    [NSLayoutConstraint activateConstraints:@[

        [_containerView.leadingAnchor
            constraintEqualToAnchor:self.view.leadingAnchor],

        [_containerView.trailingAnchor
            constraintEqualToAnchor:self.view.trailingAnchor],

        [_containerView.topAnchor
            constraintEqualToAnchor:self.view.topAnchor],

        [_containerView.bottomAnchor
            constraintEqualToAnchor:self.view.bottomAnchor],


        [_toggleButton.centerXAnchor
            constraintEqualToAnchor:_containerView.centerXAnchor],

        [_toggleButton.topAnchor
            constraintEqualToAnchor:_containerView.topAnchor
                           constant:14.0],


        [_timeoutLabel.topAnchor
            constraintEqualToAnchor:_toggleButton.bottomAnchor
                           constant:2.0],

        [_timeoutLabel.leadingAnchor
            constraintEqualToAnchor:_containerView.leadingAnchor
                           constant:5.0],

        [_timeoutLabel.trailingAnchor
            constraintEqualToAnchor:_containerView.trailingAnchor
                           constant:-5.0],

        [_timeoutLabel.bottomAnchor
            constraintEqualToAnchor:_containerView.bottomAnchor
                           constant:-12.0]
    ];


    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(stateChanged:)
               name:SleepControlCenterStateChangedNotification
             object:nil];


    [self updateUI];
}


- (void)stateChanged:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateUI];
    });
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter]
        removeObserver:self];
}

@end



#pragma mark - SleepModeModule

@interface SleepModeModule : NSObject
{
    SleepModeContentViewController *_contentViewController;
}
@end


@implementation SleepModeModule


#pragma mark - Register real system protocol

+ (void)load
{
    /*
     * The iOS Control Center runtime provides the real
     * CCUIContentModule protocol.
     *
     * We intentionally do not declare a fake local protocol.
     *
     * This allows CCSupport to see:
     *
     *     [module conformsToProtocol:@protocol(CCUIContentModule)]
     *
     * as YES.
     */

    Protocol *protocol =
        objc_getProtocol("CCUIContentModule");

    if (protocol != NULL) {

        class_addProtocol(self, protocol);
    }
}


#pragma mark - Init

- (instancetype)init
{
    self = [super init];

    if (self) {

        _contentViewController =
            [[SleepModeContentViewController alloc]
                initWithNibName:nil
                       bundle:nil];
    }

    return self;
}


#pragma mark - CCUIContentModule

- (UIViewController *)contentViewController
{
    return _contentViewController;
}


#pragma mark - Optional module methods

- (BOOL)providesOwnPlatter
{
    return YES;
}


- (void)setContentModuleContext:(id)context
{
    /*
     * CCSupport / ControlCenter can call this method.
     *
     * SleepMode currently does not need the context,
     * but implementing the selector makes the module
     * compatible with the Control Center lifecycle.
     */
}


@end
