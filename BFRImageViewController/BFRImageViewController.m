//
//  BFRImageViewController.m
//  Buffer
//
//  Created by Jordan Morgan on 11/13/15.
//
//

#import "BFRImageViewController.h"
#import "BFRImageContainerViewController.h"
#import "BFRImageTransitionAnimator.h"
#import "BFRBackLoadedImageSource.h"

@interface BFRImageViewController () <UIPageViewControllerDataSource, UIPageViewControllerDelegate, BFRHighResImageLoadedDelegate>

/*! This view controller just acts as a container to hold a page view controller, which pages between the view controllers that hold an image. */
@property (strong, nonatomic, nonnull) UIPageViewController *pagerVC;

/*! Each image displayed is shown in its own instance of a BFRImageViewController. This array holds all of those view controllers, one per image. */
@property (strong, nonatomic, nonnull) NSMutableArray <BFRImageContainerViewController *> *imageViewControllers;

/*! This can contain a mix of @c NSURL, @c UIImage, @c PHAsset, @c BFRBackLoadedImageSource or @c NSStrings of URLS. This can be a mix of all these types, or just one. */
@property (strong, nonatomic, nonnull) NSArray *images;

/*! This will automatically hide the "Done" button after five seconds. */
@property (strong, nonatomic, nullable) NSTimer *timerHideUI;

/*! The button that sticks to the top left of the view that is responsible for dismissing this view controller. */
@property (strong, nonatomic, nullable) UIBarButtonItem *doneButtonItem;

/*! This will determine whether to change certain behaviors for 3D touch considerations based on its value. */
@property (nonatomic, getter=isBeingUsedFor3DTouch) BOOL usedFor3DTouch;

/*! This is used for nothing more than to defer the hiding of the status bar until the view appears to avoid any awkward jumps in the presenting view. */
@property (nonatomic, getter=shouldHideStatusBar) BOOL hideStatusBar;

/*! Navigation bar background */
@property (nonatomic, strong, nullable) UIView * topBarBackgroundView;
/*! Navigation bar */
@property (nonatomic, strong, nullable) UINavigationBar * topBar;

/*! Counter text field */
@property (nonatomic, strong, nullable) UILabel * counterLabel;

/*! Chrome visibility */
@property (nonatomic) BOOL chromeVisible;

@end

@implementation BFRImageViewController

#pragma mark - Initializers
- (instancetype)initWithImageSource:(NSArray *)images {
    self = [super init];
    
    if (self) {
        NSAssert(images.count > 0, @"You must supply at least one image source to use this class.");
        self.images = images;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        self.enableDoneButton = YES;
        self.showDoneButtonOnLeft = YES;
        self.chromeVisible = YES;
    }
    
    return self;
}

- (instancetype)initForPeekWithImageSource:(NSArray *)images {
    self = [super init];
    
    if (self) {
        NSAssert(images.count > 0, @"You must supply at least one image source to use this class.");
        self.images = images;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        self.enableDoneButton = YES;
        self.showDoneButtonOnLeft = YES;
        self.usedFor3DTouch = YES;
    }
    
    return self;
}

#pragma mark - View Lifecycle
- (void)viewDidLoad {
    [super viewDidLoad];

    [self.navigationController setNavigationBarHidden:YES animated:NO];

    // View setup
    self.view.backgroundColor = self.isUsingTransparentBackground ? [UIColor clearColor] : [UIColor blackColor];

    // Ensure starting index won't trap
    if (self.startingIndex >= self.images.count || self.startingIndex < 0) {
        self.startingIndex = 0;
    }
    
    // Setup image view controllers
    self.imageViewControllers = [NSMutableArray new];
    for (id imgSrc in self.images) {
        BFRImageContainerViewController *imgVC = [BFRImageContainerViewController new];
        imgVC.imgSrc = imgSrc;
        imgVC.pageIndex = self.startingIndex;
        imgVC.usedFor3DTouch = self.isBeingUsedFor3DTouch;
        imgVC.useTransparentBackground = self.isUsingTransparentBackground;
        imgVC.disableHorizontalDrag = (self.images.count > 1);
        [self.imageViewControllers addObject:imgVC];
        imgVC.loadedDelegate = self;
    }
    
    // Set up pager
    self.pagerVC = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal options:nil];
    if (self.imageViewControllers.count > 1) {
        self.pagerVC.dataSource = self;
    }
    self.pagerVC.delegate = self;
    [self.pagerVC setViewControllers:@[self.imageViewControllers[self.startingIndex]] direction:UIPageViewControllerNavigationDirectionForward animated:NO completion:nil];
    
    // Add pager to view hierarchy
    [self addChildViewController:self.pagerVC];
    [[self view] addSubview:[self.pagerVC view]];
    [self.pagerVC didMoveToParentViewController:self];
    
    // Add chrome to UI now if we aren't waiting to be peeked into
    if (!self.isBeingUsedFor3DTouch) {
        [self addChromeToUI];
    }
    
    // Register for touch events on the images/scrollviews to hide UI chrome
    [self registerNotifcations];

    // Set up counter
    if (self.imageViewControllers.count > 1) {

        self.counterLabel = [UILabel new];
        self.counterLabel.translatesAutoresizingMaskIntoConstraints = false;
        self.counterLabel.font = [UIFont systemFontOfSize:17.0];
        self.counterLabel.textColor = [UIColor whiteColor];

        self.navigationItem.titleView = self.counterLabel;

        [self updateCounter];
    }
    
    [self updateVisibleImageChanged];

    [self setupTopBar];
    
    UIImage *icon = [[UIImage imageNamed:@"cross.png"] imageWithRenderingMode: UIImageRenderingModeAlwaysOriginal];
    self.doneButtonItem = [[UIBarButtonItem alloc] initWithImage:icon
                                                           style:UIBarButtonItemStylePlain
                                                          target:self
                                                          action:@selector(handleDoneAction)];
    self.navigationItem.leftBarButtonItem = self.doneButtonItem;

    // set up tap GR
//    if (self.imageViewControllers.count > 1) {
//        UITapGestureRecognizer * gr = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap)];
//        [self.view addGestureRecognizer:gr];
//    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setNavigationBarVisible:self.chromeVisible];
}

#pragma mark - Status bar
- (BOOL)prefersStatusBarHidden{
    return NO;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation {
    return UIStatusBarAnimationNone;
}

#pragma mark - Properties overrides

- (void)setCounterEnabled:(BOOL)counterEnabled {
    _counterEnabled = counterEnabled;
    if (self.isViewLoaded) {
        self.counterLabel.alpha = counterEnabled && self.chromeVisible ? 1 : 0;
    }
}

- (void)setEnableDoneButton:(BOOL)enableDoneButton {
    _enableDoneButton = enableDoneButton;
    UIBarButtonItem *item = enableDoneButton ? self.doneButtonItem : nil;
    if (self.isViewLoaded) {
        if (self.showDoneButtonOnLeft) {
            self.navigationItem.leftBarButtonItem = item;
        } else {
            self.navigationItem.rightBarButtonItem = item;
        }
    }
}

- (void)setShowDoneButtonOnLeft:(BOOL)showDoneButtonOnLeft {
    _showDoneButtonOnLeft = showDoneButtonOnLeft;
    if (self.showDoneButtonOnLeft) {
        self.navigationItem.leftBarButtonItem = self.doneButtonItem;
        self.navigationItem.rightBarButtonItem = nil;
    } else {
        self.navigationItem.leftBarButtonItem = nil;
        self.navigationItem.rightBarButtonItem = self.doneButtonItem;
    }
}

#pragma mark - Chrome

- (void)setupTopBar {

    UIView * bgView = [UIView new];
    bgView.translatesAutoresizingMaskIntoConstraints = NO;
    bgView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];

    [self.view addSubview:bgView];

    self.topBarBackgroundView = bgView;

    UINavigationBar * bar = [[UINavigationBar alloc] init];
    bar.translatesAutoresizingMaskIntoConstraints = NO;

    bar.barTintColor = [UIColor clearColor];
    [bar setBackgroundImage:[UIImage new]
                      forBarMetrics:UIBarMetricsDefault];
    bar.shadowImage = [UIImage new];
    bar.translucent = YES;

    bar.barStyle = UIBarStyleBlackOpaque;

    [self.view addSubview:bar];

    [bar pushNavigationItem:self.navigationItem animated:false];

    self.topBar = bar;

    if (@available(iOS 11.0, *)) {
        [bar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor].active = YES;
    } else {
        [bar.topAnchor constraintEqualToAnchor:self.topLayoutGuide.bottomAnchor].active = YES;
    }
    [bar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor].active = YES;
    [bar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor].active = YES;
    [bar.heightAnchor constraintEqualToConstant:44].active = YES;

    [bgView.topAnchor constraintEqualToAnchor:self.view.topAnchor].active = YES;
    [bgView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor].active = YES;
    [bgView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor].active = YES;
    [bgView.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor].active = YES;
}

- (void)addChromeToUI {
    if (self.enableDoneButton) {
        UIImage *icon = [[UIImage imageNamed:@"cross.png"] imageWithRenderingMode: UIImageRenderingModeAlwaysOriginal];
        self.doneButtonItem = [[UIBarButtonItem alloc] initWithImage:icon
                                                           style:UIBarButtonItemStylePlain
                                                          target:self
                                                          action:@selector(handleDoneAction)];

        if (self.showDoneButtonOnLeft) {
            self.navigationItem.leftBarButtonItem = self.doneButtonItem;
        } else {
            self.navigationItem.rightBarButtonItem = self.doneButtonItem;
        }
    }
}

- (void)updateCounter {
    BFRImageContainerViewController* vc = self.pagerVC.viewControllers.firstObject;
    NSInteger index = [self.imageViewControllers indexOfObject:vc];
    if (index >= 0 && index < self.imageViewControllers.count) {
        self.counterLabel.text = [NSString stringWithFormat:@"%ld%@%lu", (long)index + 1, NSLocalizedString(@" from ", nil), (unsigned long)self.imageViewControllers.count];
    }
}

- (void)updateVisibleImageChanged {
    BFRImageContainerViewController* vc = self.pagerVC.viewControllers.firstObject;
    if ([vc.imgSrc isKindOfClass:[BFRBackLoadedImageSource class]]) {
        BFRBackLoadedImageSource* source = vc.imgSrc;
        [self.imageChangedDelegate highResImageChanged:source.highResImage];
    }
}

- (void)setNavigationBarVisible:(BOOL)visible {

    if (self.chromeVisible == visible) { return; }

    self.chromeVisible = visible;
    self.hideStatusBar = !visible;

    self.topBarBackgroundView.alpha = self.chromeVisible ? 1 : 0;
    self.topBar.alpha = self.chromeVisible ? 1 : 0;
}

#pragma mark - Pager Datasource
- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController {
    NSUInteger index = ((BFRImageContainerViewController *)viewController).pageIndex;
    
    if (index == 0) {
        return nil;
    }
    
    // Update index
    index--;
    BFRImageContainerViewController *vc = self.imageViewControllers[index];
    vc.pageIndex = index;
    
    return vc;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController {
    NSUInteger index = ((BFRImageContainerViewController *)viewController).pageIndex;
    
    if (index == self.imageViewControllers.count - 1) {
        return nil;
    }
    
    //Update index
    index++;
    BFRImageContainerViewController *vc = self.imageViewControllers[index];
    vc.pageIndex = index;
    
    return vc;
}

#pragma mark - Pager delegate

- (void)pageViewController:(UIPageViewController *)pageViewController didFinishAnimating:(BOOL)finished previousViewControllers:(NSArray<UIViewController *> *)previousViewControllers transitionCompleted:(BOOL)completed {
    [self updateCounter];
    [self updateVisibleImageChanged];
}

#pragma mark - Utility methods
- (void)dismiss {
    // If we dismiss from a different image than what was animated in - don't do the custom dismiss transition animation
    if (self.startingIndex != ((BFRImageContainerViewController *)self.pagerVC.viewControllers.firstObject).pageIndex) {
        [self dismissWithoutCustomAnimation];
        return;
    }
    
    self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)dismissWithoutCustomAnimation {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"CancelCustomDismissalTransition" object:@(1)];

    self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)handlePop {
    self.view.backgroundColor = [UIColor blackColor];
    [self addChromeToUI];
}

- (void)handleDoneAction {
    [self dismiss];
}

- (void)handleTap {
    [self setNavigationBarVisible:!self.chromeVisible];
}

/*! The images and scrollview are not part of this view controller, so instances of @c BFRimageContainerViewController will post notifications when they are touched for things to happen. */
- (void)registerNotifcations {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dismiss) name:@"DismissUI" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleTap) name:@"ToggleUI" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dismiss) name:@"ImageLoadingError" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePop) name:@"ViewControllerPopped" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dismissWithoutCustomAnimation) name:@"DimissUIFromDraggingGesture" object:nil];
}

#pragma mark - BFRHighResImageLoadedDelegate
- (void)highResImageLoaded {
    [self updateVisibleImageChanged];
}

#pragma mark - Memory Considerations
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    NSLog(@"BFRImageViewer: Dismissing due to memory warning.");
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
