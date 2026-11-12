#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <math.h>


#pragma mark - SleepControlCenter bridge

static id SleepControlCenterInstance(void)
{
    Class cls = NSClassFromString(@"SleepControlCenter");

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

    return ((NSTimeInterval (*)(id, SEL))objc_msgSend)(
        manager,
        selector
    );
}


static void SleepToggle(void)
{
    id manager = SleepControlCenterInstance();

    if (!manager) {
        return;
    }

    SEL selector = NSSelectorFromString(@"toggle");

    if ([manager respondsToSelector:selector]) {
        ((void (*)(id, SEL))objc_msgSend)(
            manager,
            selector
        );
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


static NSString * const SleepControlCenterStateChangedNotification =
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


#pragma mark - Timeout text

- (NSString *)timeoutText:(NSTimeInterval)timeout
{
    if (timeout < 60.0) {

        NSInteger seconds = (NSInteger)round(timeout);

        return [NSString stringWithFormat:@"%ld giây",
                (long)seconds];
    }

    if (timeout < 3600.0) {

        NSInteger minutes =
            (NSInteger)round(timeout / 60.0);

        return [NSString stringWithFormat:@"%ld phút",
                (long)minutes];
    }

    NSInteger hours =
        (NSInteger)round(timeout / 3600.0);

    return [NSString stringWithFormat:@"%ld giờ",
            (long)hours];
}


#pragma mark - Update UI

- (void)updateUI
{
    BOOL enabled = SleepIsEnabled();

    NSTimeInterval timeout =
        SleepCurrentTimeout();

    NSString *buttonTitle;

    if (enabled) {
        buttonTitle = @"Đang bật";
    } else {
        buttonTitle = @"Đang tắt";
    }

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


#pragma mark - Toggle

- (void)togglePressed
{
    SleepToggle();

    [self updateUI];
}


#pragma mark - Timeout selection

- (void)showTimeoutMenu
{
    UIAlertController *alert =
        [UIAlertController
            alertControllerWithTitle:@"Chế độ ngủ"
            message:@"Chọn thời gian tự động khóa"
            preferredStyle:UIAlertControllerStyleActionSheet];


    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"15 giây"
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *action) {

                SleepSetTimeout(15.0);
                [self updateUI];

            }]];


    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"1 phút"
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *action) {

                SleepSetTimeout(60.0);
                [self updateUI];

            }]];


    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"5 phút"
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *action) {

                SleepSetTimeout(300.0);
                [self updateUI];

            }]];


    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"15 phút"
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *action) {

                SleepSetTimeout(900.0);
                [self updateUI];

            }]];


    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"30 phút"
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *action) {

                SleepSetTimeout(1800.0);
                [self updateUI];

            }]];


    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"1 giờ"
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *action) {

                SleepSetTimeout(3600.0);
                [self updateUI];

            }]];


    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"2 giờ"
            style:UIAlertActionStyleDefault
            handler:^(UIAlertAction *action) {

                SleepSetTimeout(7200.0);
                [self updateUI];

            }]];


    [alert addAction:
        [UIAlertAction
            actionWithTitle:@"Hủy"
            style:UIAlertActionStyleCancel
            handler:nil]];


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


#pragma mark - Long press

- (void)longPress:(UILongPressGestureRecognizer *)gesture
{
    if (gesture.state ==
        UIGestureRecognizerStateBegan) {

        [self showTimeoutMenu];
    }
}


#pragma mark - Load view

- (void)loadView
{
    UIView *view =
        [[UIView alloc] initWithFrame:CGRectZero];

    view.backgroundColor =
        [UIColor clearColor];

    self.view = view;
}


#pragma mark - View did load

- (void)viewDidLoad
{
    [super viewDidLoad];


    /*
     * Container
     */

    _containerView =
        [[UIView alloc] initWithFrame:CGRectZero];

    _containerView.translatesAutoresizingMaskIntoConstraints =
        NO;

    _containerView.backgroundColor =
        [UIColor colorWithWhite:0.18 alpha:1.0];

    _containerView.layer.cornerRadius = 18.0;

    _containerView.clipsToBounds = YES;

    [self.view addSubview:_containerView];


    /*
     * Toggle button
     */

    _toggleButton =
        [UIButton buttonWithType:UIButtonTypeSystem];

    _toggleButton.translatesAutoresizingMaskIntoConstraints =
        NO;

    _toggleButton.titleLabel.font =
        [UIFont systemFontOfSize:16.0
                          weight:UIFontWeightSemibold];

    [_toggleButton setTitleColor:[UIColor whiteColor]
                        forState:UIControlStateNormal];

    [_toggleButton addTarget:self
                      action:@selector(togglePressed)
            forControlEvents:UIControlEventTouchUpInside];

    [_containerView addSubview:_toggleButton];


    /*
     * Timeout label
     */

    _timeoutLabel =
        [[UILabel alloc] initWithFrame:CGRectZero];

    _timeoutLabel.translatesAutoresizingMaskIntoConstraints =
        NO;

    _timeoutLabel.textColor =
        [UIColor colorWithWhite:1.0 alpha:0.75];

    _timeoutLabel.font =
        [UIFont systemFontOfSize:11.0
                          weight:UIFontWeightRegular];

    _timeoutLabel.textAlignment =
        NSTextAlignmentCenter;

    _timeoutLabel.numberOfLines = 1;

    [_containerView addSubview:_timeoutLabel];


    /*
     * Long press gesture
     */

    _longPressGesture =
        [[UILongPressGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(longPress:)];

    _longPressGesture.minimumPressDuration = 0.5;

    [_toggleButton addGestureRecognizer:_longPressGesture];


    /*
     * Constraints
     */

    [_containerView.leadingAnchor
        constraintEqualToAnchor:self.view.leadingAnchor].active = YES;

    [_containerView.trailingAnchor
        constraintEqualToAnchor:self.view.trailingAnchor].active = YES;

    [_containerView.topAnchor
        constraintEqualToAnchor:self.view.topAnchor].active = YES;

    [_containerView.bottomAnchor
        constraintEqualToAnchor:self.view.bottomAnchor].active = YES;


    [_toggleButton.centerXAnchor
        constraintEqualToAnchor:_containerView.centerXAnchor].active = YES;

    [_toggleButton.topAnchor
        constraintEqualToAnchor:_containerView.topAnchor
                     constant:14.0].active = YES;


    [_timeoutLabel.topAnchor
        constraintEqualToAnchor:_toggleButton.bottomAnchor
                     constant:2.0].active = YES;

    [_timeoutLabel.leadingAnchor
        constraintEqualToAnchor:_containerView.leadingAnchor
                     constant:5.0].active = YES;

    [_timeoutLabel.trailingAnchor
        constraintEqualToAnchor:_containerView.trailingAnchor
                     constant:-5.0].active = YES;

    [_timeoutLabel.bottomAnchor
        constraintEqualToAnchor:_containerView.bottomAnchor
                     constant:-12.0].active = YES;


    /*
     * Notification
     */

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(stateChanged:)
               name:SleepControlCenterStateChangedNotification
             object:nil];


    [self updateUI];
}


#pragma mark - State changed

- (void)stateChanged:(NSNotification *)notification
{
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            [self updateUI];
        }
    );
}


#pragma mark - Dealloc

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter]
        removeObserver:self];
}

@end


#pragma mark - Control Center module

@interface SleepModeModule : NSObject
{
    SleepModeContentViewController *_contentViewController;
}
@end


@implementation SleepModeModule


#pragma mark - Runtime protocol

+ (void)load
{
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


#pragma mark - Content View Controller

- (UIViewController *)contentViewController
{
    return _contentViewController;
}


#pragma mark - Own platter

- (BOOL)providesOwnPlatter
{
    return YES;
}


#pragma mark - Module context

- (void)setContentModuleContext:(id)context
{
}

@end
