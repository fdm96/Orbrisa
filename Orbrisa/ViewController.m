//
//  ViewController.m
//  Orbrisa
//
//  Created by Steven Troughton-Smith on 20/09/2015.
//  Improved by Jip van Akker on 14/10/2015 through 10/01/2019
//

#import "BrowserMenuCoordinator.h"
#import "BrowserLocalization.h"
#import "BrowserDOMInteractionService.h"
#import "BrowserNavigationService.h"
#import "BrowserPageActionCoordinator.h"
#import "BrowserPreferencesStore.h"
#import "BrowserRemoteInputController.h"
#import "BrowserSessionStore.h"
#import "BrowserTabViewModel.h"
#import "BrowserLog.h"
#import "BrowserTabCoordinator.h"
#import "BrowserTabOverviewController.h"
#import "BrowserVideoPlaybackCoordinator.h"
#import "BrowserViewModel.h"
#import "BrowserReaderViewController.h"
#import "BrowserFeedStore.h"
#import "BrowserFeedsViewController.h"
#import "BrowserStartPageViewController.h"
#import "BrowserQuickMenuViewController.h"
#import "ViewController.h"
#import <objc/runtime.h>

static NSString * const kBrowserGlobalSelectPressEndedNotification = @"BrowserGlobalSelectPressEndedNotification";

#pragma mark - Usage guide (Siri Remote)

typedef NS_ENUM(NSInteger, BrowserRemoteIconKind) {
    BrowserRemoteIconKindSwipe = 0,     // finger on the clickpad surface
    BrowserRemoteIconKindCenter,        // clicking the middle of the clickpad
    BrowserRemoteIconKindRingUp,
    BrowserRemoteIconKindRingDown,
    BrowserRemoteIconKindRingAll,       // clicking the ring up/down/left/right
    BrowserRemoteIconKindBack,          // the "<" back button
    BrowserRemoteIconKindPlayPause,
    BrowserRemoteIconKindRedButton
};

static UIImage *BrowserGuideSymbol(NSArray<NSString *> *names, CGFloat pointSize) {
    if (@available(tvOS 13, *)) {
        UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:UIImageSymbolWeightSemibold];
        for (NSString *name in names) {
            UIImage *image = [UIImage systemImageNamed:name withConfiguration:configuration];
            if (image != nil) {
                return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            }
        }
    }
    return nil;
}

/// A small drawing of the part of the Siri Remote (silver, clickpad with ring) that is used.
@interface BrowserRemoteIconView : UIView
- (instancetype)initWithKind:(BrowserRemoteIconKind)kind badge:(nullable NSString *)badge;
@end

@implementation BrowserRemoteIconView {
    BrowserRemoteIconKind _kind;
}

- (instancetype)initWithKind:(BrowserRemoteIconKind)kind badge:(NSString *)badge {
    self = [super initWithFrame:CGRectMake(0.0, 0.0, 96.0, 96.0)];
    if (self) {
        _kind = kind;
        self.opaque = NO;
        self.backgroundColor = UIColor.clearColor;
        self.translatesAutoresizingMaskIntoConstraints = NO;
        [self.widthAnchor constraintEqualToConstant:96.0].active = YES;
        [self.heightAnchor constraintEqualToConstant:96.0].active = YES;

        UIImage *symbol = nil;
        UIColor *symbolColor = UIColor.whiteColor;
        switch (kind) {
            case BrowserRemoteIconKindSwipe:
                symbol = BrowserGuideSymbol(@[@"hand.draw.fill", @"hand.point.up.left.fill", @"arrow.up.and.down.and.arrow.left.and.right"], 30.0);
                symbolColor = [UIColor colorWithWhite:0.12 alpha:1.0];
                break;
            case BrowserRemoteIconKindBack:
                symbol = BrowserGuideSymbol(@[@"chevron.backward", @"chevron.left"], 30.0);
                break;
            case BrowserRemoteIconKindPlayPause:
                symbol = BrowserGuideSymbol(@[@"playpause.fill", @"playpause"], 28.0);
                break;
            case BrowserRemoteIconKindRedButton:
                symbol = BrowserGuideSymbol(@[@"chevron.down"], 26.0);
                break;
            default:
                break;
        }
        if (symbol != nil) {
            UIImageView *imageView = [[UIImageView alloc] initWithImage:symbol];
            imageView.tintColor = symbolColor;
            imageView.contentMode = UIViewContentModeCenter;
            imageView.frame = CGRectMake(0.0, 0.0, 96.0, 96.0);
            [self addSubview:imageView];
        }

        if (badge.length > 0) {
            UILabel *badgeLabel = [UILabel new];
            badgeLabel.text = badge;
            badgeLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightBold];
            badgeLabel.textColor = [UIColor colorWithWhite:0.1 alpha:1.0];
            badgeLabel.backgroundColor = [UIColor colorWithRed:1.0 green:0.8 blue:0.0 alpha:1.0];
            badgeLabel.textAlignment = NSTextAlignmentCenter;
            badgeLabel.layer.cornerRadius = 13.0;
            badgeLabel.layer.masksToBounds = YES;
            CGSize size = [badgeLabel sizeThatFits:CGSizeMake(200.0, 26.0)];
            CGFloat width = MAX(34.0, size.width + 16.0);
            badgeLabel.frame = CGRectMake(96.0 - width + 6.0, 96.0 - 26.0, width, 26.0);
            [self addSubview:badgeLabel];
        }
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    (void)rect;
    CGPoint center = CGPointMake(48.0, 48.0);
    UIColor *line = [UIColor colorWithWhite:1.0 alpha:0.85];
    UIColor *body = [UIColor colorWithWhite:1.0 alpha:0.14];
    UIColor *active = UIColor.whiteColor;

    if (_kind == BrowserRemoteIconKindBack || _kind == BrowserRemoteIconKindPlayPause) {
        // Round button of the remote.
        UIBezierPath *button = [UIBezierPath bezierPathWithArcCenter:center radius:30.0 startAngle:0.0 endAngle:M_PI * 2.0 clockwise:YES];
        [[UIColor colorWithWhite:0.18 alpha:1.0] setFill];
        [button fill];
        [line setStroke];
        button.lineWidth = 2.5;
        [button stroke];
        return;
    }
    if (_kind == BrowserRemoteIconKindRedButton) {
        UIBezierPath *button = [UIBezierPath bezierPathWithArcCenter:center radius:30.0 startAngle:0.0 endAngle:M_PI * 2.0 clockwise:YES];
        [[UIColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:1.0] setFill];
        [button fill];
        return;
    }

    // Clickpad: outer ring with the touch surface in the middle.
    CGFloat outer = 42.0;
    CGFloat inner = 19.0;
    UIBezierPath *pad = [UIBezierPath bezierPathWithArcCenter:center radius:outer startAngle:0.0 endAngle:M_PI * 2.0 clockwise:YES];
    [(_kind == BrowserRemoteIconKindSwipe ? [UIColor colorWithWhite:1.0 alpha:0.9] : body) setFill];
    [pad fill];
    [line setStroke];
    pad.lineWidth = 2.5;
    [pad stroke];

    if (_kind == BrowserRemoteIconKindSwipe) {
        return;
    }

    UIBezierPath *innerCircle = [UIBezierPath bezierPathWithArcCenter:center radius:inner startAngle:0.0 endAngle:M_PI * 2.0 clockwise:YES];
    innerCircle.lineWidth = 2.0;
    [line setStroke];
    [innerCircle stroke];

    if (_kind == BrowserRemoteIconKindCenter) {
        [active setFill];
        [innerCircle fill];
        return;
    }

    // Highlighted parts of the ring (up = -90°).
    NSArray<NSNumber *> *angles;
    switch (_kind) {
        case BrowserRemoteIconKindRingUp: angles = @[@(-M_PI_2)]; break;
        case BrowserRemoteIconKindRingDown: angles = @[@(M_PI_2)]; break;
        default: angles = @[@(-M_PI_2), @(0.0), @(M_PI_2), @(M_PI)]; break;
    }
    CGFloat half = (_kind == BrowserRemoteIconKindRingAll) ? 0.42 : 0.6;
    [active setFill];
    for (NSNumber *angleNumber in angles) {
        CGFloat angle = angleNumber.doubleValue;
        UIBezierPath *segment = [UIBezierPath bezierPath];
        [segment addArcWithCenter:center radius:outer - 3.0 startAngle:angle - half endAngle:angle + half clockwise:YES];
        [segment addArcWithCenter:center radius:inner + 4.0 startAngle:angle + half endAngle:angle - half clockwise:NO];
        [segment closePath];
        [segment fill];
    }
}

@end

#pragma mark - Page dots

/// The little dots under paged screens, like on Apple's onboarding: the current page is white, the others dim.
@interface BrowserPageDotsView : UIStackView
- (instancetype)initWithCount:(NSUInteger)count;
- (void)setCurrent:(NSUInteger)current;
@end

@implementation BrowserPageDotsView

- (instancetype)initWithCount:(NSUInteger)count {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.axis = UILayoutConstraintAxisHorizontal;
        self.alignment = UIStackViewAlignmentCenter;
        self.spacing = 16.0;
        self.translatesAutoresizingMaskIntoConstraints = NO;
        for (NSUInteger i = 0; i < count; i++) {
            UIView *dot = [UIView new];
            dot.translatesAutoresizingMaskIntoConstraints = NO;
            dot.layer.cornerRadius = 7.0;
            [dot.widthAnchor constraintEqualToConstant:14.0].active = YES;
            [dot.heightAnchor constraintEqualToConstant:14.0].active = YES;
            [self addArrangedSubview:dot];
        }
        self.hidden = count < 2;
        [self setCurrent:0];
    }
    return self;
}

- (void)setCurrent:(NSUInteger)current {
    [UIView animateWithDuration:0.25 animations:^{
        for (NSUInteger i = 0; i < self.arrangedSubviews.count; i++) {
            UIView *dot = self.arrangedSubviews[i];
            dot.backgroundColor = (i == current) ? UIColor.whiteColor : [UIColor colorWithWhite:1.0 alpha:0.3];
            dot.transform = (i == current) ? CGAffineTransformMakeScale(1.15, 1.15) : CGAffineTransformIdentity;
        }
    }];
}

@end

/// Full-screen guide with every remote gesture of the browser, drawn with the Siri Remote parts – on several pages.
@interface BrowserUsageGuideViewController : UIViewController
@property (nonatomic, copy) NSArray<UIView *> *pages;
@property (nonatomic) BrowserPageDotsView *dots;
@property (nonatomic) NSInteger pageIndex;
@end

@implementation BrowserUsageGuideViewController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    }
    return self;
}

- (UIView *)rowWithKind:(BrowserRemoteIconKind)kind badge:(NSString *)badge title:(NSString *)title text:(NSString *)text {
    BrowserRemoteIconView *icon = [[BrowserRemoteIconView alloc] initWithKind:kind badge:badge];

    UILabel *titleLabel = [UILabel new];
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:27.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = UIColor.whiteColor;

    UILabel *textLabel = [UILabel new];
    textLabel.text = text;
    textLabel.font = [UIFont systemFontOfSize:21.0 weight:UIFontWeightRegular];
    textLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.7];
    textLabel.numberOfLines = 4;

    UIStackView *texts = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, textLabel]];
    texts.axis = UILayoutConstraintAxisVertical;
    texts.spacing = 3.0;

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[icon, texts]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 24.0;
    return row;
}

- (UILabel *)sectionLabel:(NSString *)text {
    UILabel *label = [UILabel new];
    label.text = text.uppercaseString;
    label.font = [UIFont systemFontOfSize:20.0 weight:UIFontWeightBold];
    label.textColor = [UIColor colorWithWhite:1.0 alpha:0.5];
    return label;
}

- (UIStackView *)columnWithViews:(NSArray<UIView *> *)views {
    UIStackView *column = [[UIStackView alloc] initWithArrangedSubviews:views];
    column.axis = UILayoutConstraintAxisVertical;
    column.spacing = 16.0;
    column.alignment = UIStackViewAlignmentFill;
    return column;
}

- (UIView *)pageWithTitle:(NSString *)pageTitle columns:(NSArray<NSArray<UIView *> *> *)columnViews {
    NSMutableArray<UIView *> *columns = [NSMutableArray array];
    for (NSArray<UIView *> *views in columnViews) {
        [columns addObject:[self columnWithViews:views]];
    }
    while (columns.count < 2) {
        [columns addObject:[UIView new]]; // keep the columns the same width on pages with one column
    }
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:columns];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.distribution = UIStackViewDistributionFillEqually;
    row.alignment = UIStackViewAlignmentTop;
    row.spacing = 90.0;

    UILabel *heading = [UILabel new];
    heading.text = pageTitle;
    heading.font = [UIFont systemFontOfSize:34.0 weight:UIFontWeightSemibold];
    heading.textColor = UIColor.systemBlueColor;

    UIStackView *page = [[UIStackView alloc] initWithArrangedSubviews:@[heading, row]];
    page.axis = UILayoutConstraintAxisVertical;
    page.alignment = UIStackViewAlignmentFill;
    page.spacing = 34.0;
    page.translatesAutoresizingMaskIntoConstraints = NO;
    return page;
}

- (NSArray<UIView *> *)buildPages {
    UIView *browsing = [self pageWithTitle:BrowserLocalized(@"Browsing") columns:@[
        @[[self sectionLabel:BrowserLocalized(@"Cursor & Scrolling")],
          [self rowWithKind:BrowserRemoteIconKindSwipe badge:nil
                      title:BrowserLocalized(@"Swipe on the clickpad")
                       text:BrowserLocalized(@"Moves the cursor. In scroll mode the page scrolls – scrolling down hides the bar, scrolling up brings it back.")],
          [self rowWithKind:BrowserRemoteIconKindCenter badge:nil
                      title:BrowserLocalized(@"Press the center")
                       text:BrowserLocalized(@"Clicks at the cursor. Text fields open the keyboard right away, “Search” submits.")],
          [self rowWithKind:BrowserRemoteIconKindCenter badge:@"2×"
                      title:BrowserLocalized(@"Press the center twice")
                       text:BrowserLocalized(@"Switches between cursor mode and scroll mode.")]],
        @[[self sectionLabel:BrowserLocalized(@"Top Bar")],
          [self rowWithKind:BrowserRemoteIconKindRingUp badge:nil
                      title:BrowserLocalized(@"Press the top of the ring")
                       text:BrowserLocalized(@"Jumps into the bar: Back, Forward, Reload, Address, Home, Tabs, Full Screen, Menu. The bottom of the ring leaves it again.")],
          [self rowWithKind:BrowserRemoteIconKindCenter badge:nil
                      title:BrowserLocalized(@"Click the address")
                       text:BrowserLocalized(@"The keyboard opens right away. An address opens the page, anything else is searched on Google.")],
          [self rowWithKind:BrowserRemoteIconKindRedButton badge:nil
                      title:BrowserLocalized(@"Red button")
                       text:BrowserLocalized(@"When the bar is hidden (full screen), clicking the red button at the top brings it back.")]],
    ]];

    UIView *buttons = [self pageWithTitle:BrowserLocalized(@"Buttons & Menus") columns:@[
        @[[self sectionLabel:BrowserLocalized(@"Buttons")],
          [self rowWithKind:BrowserRemoteIconKindBack badge:nil
                      title:BrowserLocalized(@"Back button")
                       text:BrowserLocalized(@"Goes back one page. Closes menus, the keyboard and link navigation. On the first page: quits the app.")],
          [self rowWithKind:BrowserRemoteIconKindPlayPause badge:nil
                      title:@"Play/Pause"
                       text:BrowserLocalized(@"Quick menu: font size, page appearance, search, Reader, reload and the ad blocker.")],
          [self rowWithKind:BrowserRemoteIconKindPlayPause badge:@"2×"
                      title:BrowserLocalized(@"Press Play/Pause twice")
                       text:BrowserLocalized(@"Opens Settings with favorites, history, appearance, font size and more.")]],
        @[[self sectionLabel:BrowserLocalized(@"Link Navigation")],
          [self rowWithKind:BrowserRemoteIconKindRingDown badge:BrowserLocalized(@"hold")
                      title:BrowserLocalized(@"Hold the bottom of the ring")
                       text:BrowserLocalized(@"Turns link navigation on or off. A white frame shows the selected link.")],
          [self rowWithKind:BrowserRemoteIconKindRingAll badge:nil
                      title:BrowserLocalized(@"Ring up / down / left / right")
                       text:BrowserLocalized(@"Jumps to the next link. At the very top it continues into the bar (or to the red button).")],
          [self rowWithKind:BrowserRemoteIconKindCenter badge:nil
                      title:BrowserLocalized(@"Press the center")
                       text:BrowserLocalized(@"Opens the selected link.")]],
    ]];

    UIView *tabs = [self pageWithTitle:BrowserLocalized(@"Tabs & Start Page") columns:@[
        @[[self sectionLabel:@"Tabs"],
          [self rowWithKind:BrowserRemoteIconKindCenter badge:nil
                      title:BrowserLocalized(@"Tab icon in the bar")
                       text:BrowserLocalized(@"Shows all tabs with their logos. Ring left/right selects, click switches, Play/Pause closes the tab.")],
          [self rowWithKind:BrowserRemoteIconKindPlayPause badge:nil
                      title:BrowserLocalized(@"Close a tab")
                       text:BrowserLocalized(@"Play/Pause in the tab overview closes the selected tab – Orbrisa goes to the tab on its left.")]],
        @[[self sectionLabel:BrowserLocalized(@"Start Page")],
          [self rowWithKind:BrowserRemoteIconKindCenter badge:nil
                      title:BrowserLocalized(@"New tab or Home button")
                       text:BrowserLocalized(@"Shows your favorites and the recently visited sites. Ring left/right scrolls the favorites.")],
          [self rowWithKind:BrowserRemoteIconKindCenter badge:BrowserLocalized(@"hold")
                      title:BrowserLocalized(@"Hold a favorite")
                       text:BrowserLocalized(@"Options: open as web app, open when Orbrisa starts, rename, remove. Play/Pause works too.")],
          [self rowWithKind:BrowserRemoteIconKindCenter badge:BrowserLocalized(@"hold")
                      title:BrowserLocalized(@"Hold a recent site")
                       text:BrowserLocalized(@"Options: open, open as web app, add to favorites, remove from the list.")],
          [self rowWithKind:BrowserRemoteIconKindBack badge:nil
                      title:BrowserLocalized(@"Back on the start page")
                       text:BrowserLocalized(@"Closes it and shows the page – an empty tab shows Google.")]],
    ]];

    UIView *webApps = [self pageWithTitle:BrowserLocalized(@"Web Apps") columns:@[
        @[[self sectionLabel:BrowserLocalized(@"Using a Web App")],
          [self rowWithKind:BrowserRemoteIconKindSwipe badge:nil
                      title:BrowserLocalized(@"Swipe on the clickpad")
                       text:BrowserLocalized(@"Scrolls the page – anywhere, no cursor needed.")],
          [self rowWithKind:BrowserRemoteIconKindCenter badge:BrowserLocalized(@"hold")
                      title:BrowserLocalized(@"Hold the center")
                       text:BrowserLocalized(@"Shows the selection box. Swipe moves it, press the center to open what it marks.")],
          [self rowWithKind:BrowserRemoteIconKindRingAll badge:nil
                      title:BrowserLocalized(@"Ring left / right")
                       text:BrowserLocalized(@"Turns to the previous or next page on sites with several pages.")]],
        @[[self sectionLabel:BrowserLocalized(@"Switching & Leaving")],
          [self rowWithKind:BrowserRemoteIconKindRingDown badge:BrowserLocalized(@"hold")
                      title:BrowserLocalized(@"Hold the bottom of the ring")
                       text:BrowserLocalized(@"Your other web apps slide up – pick one, or go to the start page.")],
          [self rowWithKind:BrowserRemoteIconKindBack badge:nil
                      title:BrowserLocalized(@"Back button")
                       text:BrowserLocalized(@"Goes back inside the web app. On its first page: to the start page.")],
          [self rowWithKind:BrowserRemoteIconKindPlayPause badge:nil
                      title:@"Play/Pause"
                       text:BrowserLocalized(@"Quick menu with the text size for this web app and “Leave Web App”.")]],
    ]];

    UIView *reader = [self pageWithTitle:BrowserLocalized(@"Reader & Feeds") columns:@[
        @[[self sectionLabel:@"Reader"],
          [self rowWithKind:BrowserRemoteIconKindCenter badge:nil
                      title:BrowserLocalized(@"Reader button in the address bar")
                       text:BrowserLocalized(@"Appears when a page has an article and shows it as calm, large text.")],
          [self rowWithKind:BrowserRemoteIconKindSwipe badge:nil
                      title:BrowserLocalized(@"Swipe in the Reader")
                       text:BrowserLocalized(@"Scrolls the article.")],
          [self rowWithKind:BrowserRemoteIconKindPlayPause badge:nil
                      title:BrowserLocalized(@"Play/Pause in the Reader")
                       text:BrowserLocalized(@"Appearance: font size, background, font, “Always Open in Reader” and “Show Web Page”.")]],
        @[[self sectionLabel:BrowserLocalized(@"Feeds")],
          [self rowWithKind:BrowserRemoteIconKindCenter badge:nil
                      title:BrowserLocalized(@"RSS button next to the address")
                       text:BrowserLocalized(@"Orange: subscribe to the page's feed. Grey: opens your feeds.")],
          [self rowWithKind:BrowserRemoteIconKindCenter badge:nil
                      title:BrowserLocalized(@"Click an article")
                       text:BrowserLocalized(@"Opens it in the Reader. Back takes you to the feed list again.")],
          [self rowWithKind:BrowserRemoteIconKindPlayPause badge:nil
                      title:BrowserLocalized(@"Play/Pause on a feed")
                       text:BrowserLocalized(@"Unsubscribes from the feed.")]],
    ]];

    UIView *videos = [self pageWithTitle:@"Videos" columns:@[
        @[[self sectionLabel:BrowserLocalized(@"Starting a Video")],
          [self rowWithKind:BrowserRemoteIconKindCenter badge:nil
                      title:BrowserLocalized(@"Start a video")
                       text:BrowserLocalized(@"Orbrisa asks: Full Screen (Apple TV player, without ads), Choose Video or Stay on Page.")]],
        @[[self sectionLabel:BrowserLocalized(@"In the Player")],
          [self rowWithKind:BrowserRemoteIconKindSwipe badge:nil
                      title:BrowserLocalized(@"Swipe in the player")
                       text:BrowserLocalized(@"Scrubs forward and back. Press the center to confirm, ring left/right jumps 10 seconds.")],
          [self rowWithKind:BrowserRemoteIconKindBack badge:nil
                      title:BrowserLocalized(@"Back in the player")
                       text:BrowserLocalized(@"Closes the player and takes you back to the page.")]],
    ]];

    return @[browsing, buttons, tabs, webApps, reader, videos];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;

    UIVisualEffectView *backdrop = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    backdrop.frame = self.view.bounds;
    backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:backdrop];
    UIView *dim = [[UIView alloc] initWithFrame:self.view.bounds];
    dim.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.45];
    dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:dim];

    UILabel *title = [UILabel new];
    title.text = BrowserLocalized(@"Using the Siri Remote");
    title.font = [UIFont systemFontOfSize:46.0 weight:UIFontWeightBold];
    title.textColor = UIColor.whiteColor;
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:title];

    UIView *pageArea = [UIView new];
    pageArea.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:pageArea];
    self.pages = [self buildPages];
    for (UIView *page in self.pages) {
        [pageArea addSubview:page];
        [NSLayoutConstraint activateConstraints:@[
            [page.topAnchor constraintEqualToAnchor:pageArea.topAnchor],
            [page.leadingAnchor constraintEqualToAnchor:pageArea.leadingAnchor],
            [page.trailingAnchor constraintEqualToAnchor:pageArea.trailingAnchor],
        ]];
        page.alpha = 0.0;
    }

    self.dots = [[BrowserPageDotsView alloc] initWithCount:self.pages.count];
    [self.view addSubview:self.dots];

    UILabel *footer = [UILabel new];
    footer.text = BrowserLocalized(@"Swipe or press left / right for more  ·  Back to close");
    footer.font = [UIFont systemFontOfSize:20.0 weight:UIFontWeightMedium];
    footer.textColor = [UIColor colorWithWhite:1.0 alpha:0.45];
    footer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:footer];

    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:60.0],
        [title.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:120.0],
        [pageArea.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:36.0],
        [pageArea.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:120.0],
        [pageArea.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-120.0],
        [pageArea.bottomAnchor constraintEqualToAnchor:self.dots.topAnchor constant:-20.0],
        [self.dots.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.dots.bottomAnchor constraintEqualToAnchor:footer.topAnchor constant:-18.0],
        [footer.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-44.0],
        [footer.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
    ]];

    for (NSNumber *direction in @[@(UISwipeGestureRecognizerDirectionLeft), @(UISwipeGestureRecognizerDirectionRight)]) {
        UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swiped:)];
        swipe.direction = direction.unsignedIntegerValue;
        [self.view addGestureRecognizer:swipe];
    }
    self.pageIndex = -1;
    [self showPage:0];
}

- (void)swiped:(UISwipeGestureRecognizer *)swipe {
    [self showPage:self.pageIndex + (swipe.direction == UISwipeGestureRecognizerDirectionLeft ? 1 : -1)];
}

/// Pages slide sideways like the tvOS onboarding screens; the dots below show where you are.
- (void)showPage:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.pages.count || index == self.pageIndex) {
        return;
    }
    UIView *old = self.pageIndex >= 0 ? self.pages[(NSUInteger)self.pageIndex] : nil;
    UIView *next = self.pages[(NSUInteger)index];
    CGFloat shift = (index > self.pageIndex ? 1.0 : -1.0) * 120.0;
    self.pageIndex = index;
    [self.dots setCurrent:(NSUInteger)index];
    next.transform = old != nil ? CGAffineTransformMakeTranslation(shift, 0.0) : CGAffineTransformIdentity;
    [UIView animateWithDuration:(old != nil ? 0.35 : 0.0) delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        old.alpha = 0.0;
        old.transform = CGAffineTransformMakeTranslation(-shift, 0.0);
        next.alpha = 1.0;
        next.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self becomeFirstResponder];
}

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    // Handled on release; swallowing the start keeps the browser underneath from reacting.
    UIPressType type = presses.anyObject.type;
    if (type == UIPressTypeMenu || type == UIPressTypeSelect || type == UIPressTypePlayPause
        || type == UIPressTypeLeftArrow || type == UIPressTypeRightArrow) {
        return;
    }
    [super pressesBegan:presses withEvent:event];
}

- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    UIPressType type = presses.anyObject.type;
    if (type == UIPressTypeLeftArrow) {
        [self showPage:self.pageIndex - 1];
        return;
    }
    if (type == UIPressTypeRightArrow) {
        [self showPage:self.pageIndex + 1];
        return;
    }
    if (type == UIPressTypeSelect) {
        // Next page – on the last page the guide closes.
        if (self.pageIndex + 1 < (NSInteger)self.pages.count) {
            [self showPage:self.pageIndex + 1];
        } else {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
        return;
    }
    if (type == UIPressTypeMenu || type == UIPressTypePlayPause) {
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    [super pressesEnded:presses withEvent:event];
}

@end

#pragma mark - What's New

/// Shown once per version (first install or update), like Apple's "What's New" screens; "Weiter" leads to the usage guide.
@interface BrowserWhatsNewViewController : UIViewController
@property (nonatomic, copy) void (^continueHandler)(void);
@property (nonatomic) UIButton *continueButton;
@property (nonatomic) BOOL showsGuideHint; // NO when opened from Settings → Help
@property (nonatomic, copy) NSArray<UIView *> *pages;
@property (nonatomic) BrowserPageDotsView *dots;
@property (nonatomic) NSInteger pageIndex;
@end

@implementation BrowserWhatsNewViewController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _showsGuideHint = YES;
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    }
    return self;
}

- (UIView *)featureWithSymbol:(NSString *)symbol color:(UIColor *)color title:(NSString *)title text:(NSString *)text {
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:46.0 weight:UIImageSymbolWeightSemibold];
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol withConfiguration:configuration]];
    icon.tintColor = color;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [icon.widthAnchor constraintEqualToConstant:76.0].active = YES;

    UILabel *titleLabel = [UILabel new];
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:31.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = UIColor.whiteColor;

    UILabel *textLabel = [UILabel new];
    textLabel.text = text;
    textLabel.font = [UIFont systemFontOfSize:24.0 weight:UIFontWeightRegular];
    textLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.65];
    textLabel.numberOfLines = 2;

    UIStackView *texts = [[UIStackView alloc] initWithArrangedSubviews:@[titleLabel, textLabel]];
    texts.axis = UILayoutConstraintAxisVertical;
    texts.spacing = 4.0;

    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[icon, texts]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 28.0;
    return row;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;

    UIVisualEffectView *backdrop = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    backdrop.frame = self.view.bounds;
    backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:backdrop];
    UIView *dim = [[UIView alloc] initWithFrame:self.view.bounds];
    dim.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:dim];

    NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"";

    UILabel *titleLabel = [UILabel new];
    titleLabel.text = BrowserLocalized(@"What's New in Orbrisa");
    titleLabel.font = [UIFont systemFontOfSize:64.0 weight:UIFontWeightBold];
    titleLabel.textColor = UIColor.whiteColor;
    titleLabel.textAlignment = NSTextAlignmentCenter;

    UILabel *versionLabel = [UILabel new];
    NSString *releaseLabel = [NSBundle.mainBundle objectForInfoDictionaryKey:@"OrbrisaReleaseLabel"];
    NSString *shownVersion = releaseLabel.length > 0 ? [NSString stringWithFormat:@"%@ %@", version, releaseLabel] : version;
    versionLabel.text = [NSString stringWithFormat:BrowserLocalized(@"Version %@"), shownVersion];
    versionLabel.font = [UIFont systemFontOfSize:28.0 weight:UIFontWeightMedium];
    versionLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.55];
    versionLabel.textAlignment = NSTextAlignmentCenter;

    // One page per release, newest first – the dots below show there is more (ring left / right or swipe).
    NSArray<NSArray *> *releases = @[
        @[BrowserLocalized(@"New in Beta 2"), @[
            [self featureWithSymbol:@"house.fill" color:UIColor.systemBlueColor
                              title:BrowserLocalized(@"New Start Page")
                               text:BrowserLocalized(@"Your favorites as large tiles and recently visited sites with real pictures. Hold a favorite for its options.")],
            [self featureWithSymbol:@"app.badge.fill" color:UIColor.systemIndigoColor
                              title:BrowserLocalized(@"Web Apps")
                               text:BrowserLocalized(@"Open a favorite as an app: full screen, no bar, simple remote controls – hold the bottom of the clickpad for your other web apps.")],
            [self featureWithSymbol:@"hand.raised.fill" color:UIColor.systemRedColor
                              title:BrowserLocalized(@"Ad Blocker")
                               text:BrowserLocalized(@"Blocks ad and tracking servers and hides ad boxes. Switch it off in the quick menu or in Settings.")],
            [self featureWithSymbol:@"slider.horizontal.3" color:UIColor.systemTealColor
                              title:BrowserLocalized(@"New Quick Menu")
                               text:BrowserLocalized(@"Play/Pause opens a glass panel with font size, page appearance, actions and the ad blocker.")],
        ]],
        @[BrowserLocalized(@"Beta 1 – Reader & RSS"), @[
            [self featureWithSymbol:@"text.alignleft" color:UIColor.systemOrangeColor
                              title:BrowserLocalized(@"Reader Mode")
                               text:BrowserLocalized(@"Only the article – large, calm text with your own size, background and font.")],
            [self featureWithSymbol:@"dot.radiowaves.up.forward" color:UIColor.systemBlueColor
                              title:BrowserLocalized(@"RSS Feeds")
                               text:BrowserLocalized(@"Subscribe to your favourite sites and see all new articles in one place – they open in the Reader.")],
        ]],
        @[BrowserLocalized(@"Version 1.0 – Orbrisa"), @[
            [self featureWithSymbol:@"play.tv.fill" color:UIColor.systemPurpleColor
                              title:BrowserLocalized(@"Videos in the Apple TV Player")
                               text:BrowserLocalized(@"“Full Screen” opens the actual video in the Apple TV player – ads before it are skipped.")],
            [self featureWithSymbol:@"square.on.square" color:UIColor.systemGreenColor
                              title:BrowserLocalized(@"New Tab Strip")
                               text:BrowserLocalized(@"All tabs with their logos right under the address bar – in each site's colour if you like.")],
            [self featureWithSymbol:@"gearshape.fill" color:UIColor.systemGrayColor
                              title:BrowserLocalized(@"New Settings")
                               text:BrowserLocalized(@"Switches and design like the tvOS Settings.")],
            [self featureWithSymbol:@"drop.fill" color:UIColor.systemCyanColor
                              title:@"Liquid Glass"
                               text:BrowserLocalized(@"Adjust the glass effect smoothly or turn it off completely.")],
        ]],
    ];

    UIView *pageArea = [UIView new];
    pageArea.translatesAutoresizingMaskIntoConstraints = NO;
    NSMutableArray<UIView *> *pages = [NSMutableArray array];
    for (NSArray *release in releases) {
        UILabel *heading = [UILabel new];
        heading.text = release[0];
        heading.font = [UIFont systemFontOfSize:30.0 weight:UIFontWeightSemibold];
        heading.textColor = UIColor.systemBlueColor;
        NSMutableArray<UIView *> *rows = [NSMutableArray arrayWithObject:heading];
        [rows addObjectsFromArray:release[1]];
        UIStackView *page = [[UIStackView alloc] initWithArrangedSubviews:rows];
        page.axis = UILayoutConstraintAxisVertical;
        page.alignment = UIStackViewAlignmentLeading;
        page.spacing = 30.0;
        page.translatesAutoresizingMaskIntoConstraints = NO;
        page.alpha = 0.0;
        [pageArea addSubview:page];
        [NSLayoutConstraint activateConstraints:@[
            [page.topAnchor constraintEqualToAnchor:pageArea.topAnchor],
            [page.leadingAnchor constraintEqualToAnchor:pageArea.leadingAnchor],
            [page.trailingAnchor constraintEqualToAnchor:pageArea.trailingAnchor],
        ]];
        [pages addObject:page];
    }
    self.pages = pages;
    self.dots = [[BrowserPageDotsView alloc] initWithCount:pages.count];

    UILabel *betaLabel = [UILabel new];
    betaLabel.text = BrowserLocalized(@"Found a bug or have an idea? Report it on GitHub – a photo of your TV helps a lot.");
    betaLabel.font = [UIFont systemFontOfSize:21.0 weight:UIFontWeightRegular];
    betaLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.45];

    for (NSNumber *direction in @[@(UISwipeGestureRecognizerDirectionLeft), @(UISwipeGestureRecognizerDirectionRight)]) {
        UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swiped:)];
        swipe.direction = direction.unsignedIntegerValue;
        [self.view addGestureRecognizer:swipe];
    }

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIButtonConfiguration *configuration = [UIButtonConfiguration filledButtonConfiguration];
    configuration.title = BrowserLocalized(@"Continue");
    configuration.baseBackgroundColor = UIColor.systemBlueColor;
    configuration.baseForegroundColor = UIColor.whiteColor;
    configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(18.0, 140.0, 18.0, 140.0);
    configuration.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey, id> *(NSDictionary<NSAttributedStringKey, id> *attributes) {
        NSMutableDictionary *updated = [attributes mutableCopy];
        updated[NSFontAttributeName] = [UIFont systemFontOfSize:30.0 weight:UIFontWeightSemibold];
        return updated;
    };
    button.configuration = configuration;
    [button addTarget:self action:@selector(continueTapped) forControlEvents:UIControlEventPrimaryActionTriggered];
    self.continueButton = button;

    UILabel *hintLabel = [UILabel new];
    hintLabel.text = BrowserLocalized(@"Afterwards, Orbrisa shows you how to use the Siri Remote.");
    hintLabel.font = [UIFont systemFontOfSize:21.0 weight:UIFontWeightRegular];
    hintLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.45];

    UIStackView *content = [[UIStackView alloc] initWithArrangedSubviews:(self.showsGuideHint ? @[titleLabel, versionLabel, pageArea, self.dots, betaLabel, button, hintLabel] : @[titleLabel, versionLabel, pageArea, self.dots, betaLabel, button])];
    content.axis = UILayoutConstraintAxisVertical;
    content.alignment = UIStackViewAlignmentCenter;
    content.spacing = 18.0;
    [content setCustomSpacing:50.0 afterView:versionLabel];
    [content setCustomSpacing:26.0 afterView:pageArea];
    [content setCustomSpacing:22.0 afterView:self.dots];
    [content setCustomSpacing:40.0 afterView:betaLabel];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:content];

    [NSLayoutConstraint activateConstraints:@[
        [content.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [content.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [pageArea.widthAnchor constraintEqualToConstant:1000.0],
        [pageArea.heightAnchor constraintEqualToConstant:540.0],
    ]];
    self.pageIndex = -1;
    [self showPage:0];
}

- (void)swiped:(UISwipeGestureRecognizer *)swipe {
    [self showPage:self.pageIndex + (swipe.direction == UISwipeGestureRecognizerDirectionLeft ? 1 : -1)];
}

- (void)showPage:(NSInteger)index {
    if (index < 0 || index >= (NSInteger)self.pages.count || index == self.pageIndex) {
        return;
    }
    UIView *old = self.pageIndex >= 0 ? self.pages[(NSUInteger)self.pageIndex] : nil;
    UIView *next = self.pages[(NSUInteger)index];
    CGFloat shift = (index > self.pageIndex ? 1.0 : -1.0) * 100.0;
    self.pageIndex = index;
    [self.dots setCurrent:(NSUInteger)index];
    next.transform = old != nil ? CGAffineTransformMakeTranslation(shift, 0.0) : CGAffineTransformIdentity;
    [UIView animateWithDuration:(old != nil ? 0.35 : 0.0) delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        old.alpha = 0.0;
        old.transform = CGAffineTransformMakeTranslation(-shift, 0.0);
        next.alpha = 1.0;
        next.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (NSArray<id<UIFocusEnvironment>> *)preferredFocusEnvironments {
    return self.continueButton != nil ? @[self.continueButton] : @[];
}

- (void)continueTapped {
    void (^handler)(void) = self.continueHandler;
    self.continueHandler = nil;
    [self dismissViewControllerAnimated:YES completion:^{
        if (handler != nil) {
            handler();
        }
    }];
}

- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    if (presses.anyObject.type == UIPressTypeMenu) {
        [self continueTapped];
        return;
    }
    if (presses.anyObject.type == UIPressTypeLeftArrow || presses.anyObject.type == UIPressTypeRightArrow) {
        [self showPage:self.pageIndex + (presses.anyObject.type == UIPressTypeRightArrow ? 1 : -1)];
        return;
    }
    [super pressesEnded:presses withEvent:event];
}

@end

@interface ViewController () <BrowserMenuCoordinatorHost, BrowserPageActionCoordinatorHost, BrowserRemoteInputControllerHost, BrowserTabCoordinatorHost, BrowserTabOverviewControllerHost, BrowserTopBarViewDelegate, BrowserVideoPlaybackCoordinatorHost>

@property (nonatomic) BrowserDOMInteractionService *domInteractionService;
@property (nonatomic) BrowserMenuCoordinator *menuCoordinator;
@property (nonatomic) BrowserNavigationService *navigationService;
@property (nonatomic, copy) NSDictionary *pageArticle;
@property (nonatomic, copy) NSString *pageArticleURL;
@property (nonatomic) BOOL pageHasFeed;
@property (nonatomic) NSUInteger pageProbeGeneration;
@property (nonatomic, copy) NSString *autoReaderURL;
@property (nonatomic) CFTimeInterval feedReaderPendingUntil; // an article opened from the feeds: show it in the Reader once it has loaded
@property (nonatomic) BOOL webAppMode;
@property (nonatomic) BOOL didHandleLaunchWebApp;
@property (nonatomic) BOOL didShowLaunchStartPage;
@property (nonatomic) UIView *webAppHintView;
@property (nonatomic) UIView *webAppSplashView;
@property (nonatomic, copy) NSString *webAppURLString;
@property (nonatomic) BOOL webAppAskedTextSize;
@property (nonatomic) BOOL leavingWebApp;
@property (nonatomic) NSMutableSet<UITouch *> *forwardedTouches;
@property (nonatomic) BOOL cursorModeBeforeWebApp;
@property (nonatomic) BrowserPageActionCoordinator *pageActionCoordinator;
@property (nonatomic) BrowserPreferencesStore *preferencesStore;
@property (nonatomic) BrowserRemoteInputController *remoteInputController;
@property (nonatomic) BrowserSessionStore *sessionStore;
@property (nonatomic) BrowserTabCoordinator *tabCoordinator;
@property (nonatomic) BrowserTabOverviewController *tabOverviewController;
@property (nonatomic) BrowserVideoPlaybackCoordinator *videoPlaybackCoordinator;
@property (nonatomic) BrowserViewModel *viewModel;
@property (nonatomic) BOOL displayedHintsOnLaunch;
@property (nonatomic) BOOL scrollViewAllowBounces;
@property (nonatomic, getter=isTopBarFocusActive) BOOL topBarFocusActive;
@property (nonatomic) UIView *showTopBarButton;
@property (nonatomic) UILabel *linkNavigationHintLabel;
@property (nonatomic) BOOL showTopBarButtonSelected;
/// The bar slides up out of view while scrolling down and comes back when scrolling up (like Safari).
@property (nonatomic) NSTimer *topBarScrollTimer;
@property (nonatomic) CGFloat lastScrollPosition;
@property (nonatomic, weak) UIScrollView *lastScrollView;
@property (nonatomic, getter=isTopBarScrolledAway) BOOL topBarScrolledAway;

@end

#pragma mark - Keep closed screens alive a moment

// A screen that closes while a finger still rests on the clickpad (a click IS a touch) was freed before UIKit had
// finished that touch. UIKit then sent the touch's end to the freed memory – by then reused by a "UIDropShadowView" –
// and crashed with "-[UIDropShadowView (null selector)]: unrecognized selector". Holding every closed screen for
// three seconds lets the touch finish first.
@implementation UIViewController (BrowserKeepAliveAfterDismiss)

+ (void)load {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Method original = class_getInstanceMethod(self, @selector(viewDidDisappear:));
        Method replacement = class_getInstanceMethod(self, @selector(browser_viewDidDisappear:));
        if (original != NULL && replacement != NULL) {
            method_exchangeImplementations(original, replacement);
        }
    });
}

- (void)browser_viewDidDisappear:(BOOL)animated {
    [self browser_viewDidDisappear:animated]; // the original implementation
    if (self.isBeingDismissed) {
        UIViewController *keep = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            (void)keep;
        });
    }
}

@end

@implementation ViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.definesPresentationContext = YES;
    self.scrollViewAllowBounces = YES;

    self.preferencesStore = [BrowserPreferencesStore new];
    [self.preferencesStore ensureUserAgentConsistency];

    self.viewModel = [BrowserViewModel new];
    self.viewModel.topNavigationBarVisible = self.preferencesStore.topNavigationBarVisible;
    self.viewModel.textFontSize = self.preferencesStore.textFontSize;
    self.viewModel.fullscreenVideoPlaybackEnabled = self.preferencesStore.fullscreenVideoPlaybackEnabled;

    self.domInteractionService = [BrowserDOMInteractionService new];
    self.navigationService = [[BrowserNavigationService alloc] initWithPreferencesStore:self.preferencesStore];
    self.sessionStore = [BrowserSessionStore new];
    self.menuCoordinator = [[BrowserMenuCoordinator alloc] initWithHost:self preferencesStore:self.preferencesStore];
    self.remoteInputController = [[BrowserRemoteInputController alloc] initWithHost:self rootView:self.view];
    [self.view addSubview:self.remoteInputController.cursorView];
    self.videoPlaybackCoordinator = [[BrowserVideoPlaybackCoordinator alloc] initWithHost:self
                                                                      domInteractionService:self.domInteractionService];
    self.tabCoordinator = [[BrowserTabCoordinator alloc] initWithHost:self
                                                             viewModel:self.viewModel
                                                      preferencesStore:self.preferencesStore
                                                     navigationService:self.navigationService
                                                          sessionStore:self.sessionStore
                                                    browserContainerView:self.browserContainerView
                                                              rootView:self.view
                                                            topMenuView:self.topMenuView
                                                            cursorView:self.remoteInputController.cursorView
                                               manualScrollPanRecognizer:self.remoteInputController.manualScrollPanRecognizer
                                                           webViewDelegate:self
                                                       scrollViewAllowBounces:self.scrollViewAllowBounces];
    self.tabOverviewController = [[BrowserTabOverviewController alloc] initWithHost:self
                                                                            viewModel:self.viewModel
                                                                             rootView:self.view
                                                                           topMenuView:self.topMenuView
                                                                           cursorView:self.remoteInputController.cursorView];
    self.pageActionCoordinator = [[BrowserPageActionCoordinator alloc] initWithHost:self
                                                               domInteractionService:self.domInteractionService
                                                                   navigationService:self.navigationService
                                                            videoPlaybackCoordinator:self.videoPlaybackCoordinator];

    self.topMenuView.delegate = self;
    self.topMenuView.loadingSpinner.hidesWhenStopped = YES;
    [self setUpShowTopBarButton];
    self.remoteInputController.cursorView.hidden = NO;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleApplicationWillResignActive:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleApplicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleApplicationWillTerminate:)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleGlobalSelectPressEndedNotification:)
                                                 name:kBrowserGlobalSelectPressEndedNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleOpenAppURLNotification:)
                                                 name:@"BrowserOpenAppURLNotification"
                                               object:nil];

    [self.tabCoordinator restoreInitialStateOrCreateFirstTab];

    // "Automatic" dark mode: when the Apple TV switches between light and dark, the pages follow right away.
    [self registerForTraitChanges:@[UITraitUserInterfaceStyle.class] withHandler:^(__unused id<UITraitEnvironment> environment, __unused UITraitCollection *previous) {
        if (BrowserWebView.forceDarkPages && BrowserWebView.appearanceMode == 0) {
            [[NSNotificationCenter defaultCenter] postNotificationName:BrowserForceDarkPagesDidChangeNotification object:nil];
        }
    }];

    __weak typeof(self) weakSelf = self;
    self.topBarScrollTimer = [NSTimer scheduledTimerWithTimeInterval:0.08 repeats:YES block:^(__unused NSTimer *timer) {
        [weakSelf updateTopBarForScrollPosition];
    }];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    NSString *launchWebApp = self.didHandleLaunchWebApp ? nil : [BrowserStartPageViewController launchWebAppURL];
    self.didHandleLaunchWebApp = YES;
    if (launchWebApp != nil) {
        self.webAppMode = YES; // no start page underneath
    }
    BOOL firstAppearance = !self.didShowLaunchStartPage;
    self.didShowLaunchStartPage = YES;
    [self.tabCoordinator webViewDidAppear];
    if (launchWebApp != nil) {
        [self browserOpenWebAppWithURLString:launchWebApp];
    } else if (firstAppearance && self.preferencesStore.homePageURLString.length == 0) {
        [self browserShowStartPage]; // the open tabs stay behind it – Back goes to them
    }
    [BrowserWebView applyAppearanceToWindows];
    [self openPendingAppURL];
    // The tips dialog used to pop up at every launch; it stays available in Settings → Help.
    self.displayedHintsOnLaunch = YES;
    [self showWhatsNewIfNeeded];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

- (void)dealloc {
    [self.topBarScrollTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Bar hides while scrolling

- (void)updateTopBarForScrollPosition {
    UIScrollView *scrollView = self.webview.scrollView;
    if (scrollView == nil || !self.viewModel.topNavigationBarVisible || self.topMenuView.hidden) {
        [self setTopBarScrolledAway:NO animated:NO];
        self.lastScrollView = scrollView;
        return;
    }
    // Position measured from the very top of the page (0 = start of the page, right under the bar).
    CGFloat position = scrollView.contentOffset.y + scrollView.adjustedContentInset.top;
    if (scrollView != self.lastScrollView) {
        // Another tab or a new web view: start again with the bar visible.
        self.lastScrollView = scrollView;
        self.lastScrollPosition = position;
        [self setTopBarScrolledAway:NO animated:YES];
        return;
    }
    CGFloat delta = position - self.lastScrollPosition;
    BOOL busy = self.topBarFocusActive || self.presentedViewController != nil || self.tabOverviewController.visible;

    if (busy || position < 60.0) {
        [self setTopBarScrolledAway:NO animated:YES];
        self.lastScrollPosition = position;
    } else if (delta > 14.0) {
        [self setTopBarScrolledAway:YES animated:YES];
        self.lastScrollPosition = position;
    } else if (delta < -14.0) {
        [self setTopBarScrolledAway:NO animated:YES];
        self.lastScrollPosition = position;
    } else if (fabs(delta) > 200.0) {
        self.lastScrollPosition = position;
    }
}

- (void)setTopBarScrolledAway:(BOOL)scrolledAway animated:(BOOL)animated {
    if (self.topBarScrolledAway == scrolledAway) {
        return;
    }
    self.topBarScrolledAway = scrolledAway;
    UIView *bar = self.topMenuView;
    CGFloat distance = bar.center.y + (CGRectGetHeight(bar.bounds) / 2.0) + 30.0;
    void (^changes)(void) = ^{
        bar.transform = scrolledAway ? CGAffineTransformMakeTranslation(0.0, -distance) : CGAffineTransformIdentity;
        bar.alpha = scrolledAway ? 0.0 : 1.0;
    };
    bar.userInteractionEnabled = !scrolledAway;
    if (animated) {
        [UIView animateWithDuration:0.3
                              delay:0.0
             usingSpringWithDamping:1.0
              initialSpringVelocity:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }
}

#pragma mark - Notifications

- (void)handleApplicationWillResignActive:(NSNotification *)notification {
    (void)notification;
    [self.tabCoordinator persistSession];
    [self.tabCoordinator updateTopShelf];
}

- (void)handleApplicationDidEnterBackground:(NSNotification *)notification {
    (void)notification;
    [self.tabCoordinator persistSession];
    [self.tabCoordinator updateTopShelf];
}

/// A link from the Top Shelf (the app was already running, or it just started with one).
- (void)handleOpenAppURLNotification:(NSNotification *)notification {
    (void)notification;
    [self openPendingAppURL];
}

- (void)openPendingAppURL {
    NSString *pending = [[NSUserDefaults standardUserDefaults] stringForKey:@"BrowserPendingAppURL"];
    if (pending.length == 0 || self.tabCoordinator == nil) {
        return;
    }
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"BrowserPendingAppURL"];
    [self.tabCoordinator openAppURL:[NSURL URLWithString:pending]];
}

- (void)handleApplicationWillTerminate:(NSNotification *)notification {
    (void)notification;
    [self.tabCoordinator persistSession];
}

- (void)handleGlobalSelectPressEndedNotification:(NSNotification *)notification {
    (void)notification;
    [self.remoteInputController handleGlobalSelectPressEndedNotification];
}

#pragma mark - Helpers

- (BrowserWebView *)webview {
    return self.tabCoordinator.activeWebView;
}

- (CGPoint)browserDOMPointForCursor {
    return [self.domInteractionService DOMPointForCursorOrigin:self.remoteInputController.cursorView.frame.origin
                                                        inView:self.view
                                                       webView:self.webview];
}

- (void)loadHomePage {
    [self.tabCoordinator loadHomePage];
}

- (void)showAdvancedMenu {
    [self deactivateTopBarFocusMode];
    [self.menuCoordinator showAdvancedMenu];
}

- (BOOL)canActivateTopBarFocusMode {
    return self.presentedViewController == nil &&
        !self.tabOverviewController.visible &&
        self.viewModel.topNavigationBarVisible &&
        !self.topMenuView.hidden;
}

- (void)activateTopBarFocusMode {
    if (![self canActivateTopBarFocusMode]) {
        return;
    }
    [self refreshPageFeatures];
    if (self.topBarFocusActive) {
        return;
    }
    // Going up to the bar always brings it back, even when it slid away while scrolling.
    [self setTopBarScrolledAway:NO animated:YES];

    self.topBarFocusActive = YES;
    [self.topMenuView setFocusModeActive:YES];
    [self.remoteInputController refreshInteractionState];
    [self setNeedsFocusUpdate];
    [self updateFocusIfNeeded];
}

- (void)deactivateTopBarFocusMode {
    if (!self.topBarFocusActive) {
        return;
    }

    self.topBarFocusActive = NO;
    [self.topMenuView setFocusModeActive:NO];
    [self.remoteInputController refreshInteractionState];
    [self setNeedsFocusUpdate];
    [self updateFocusIfNeeded];
}

- (void)performTopBarAction:(BrowserTopBarAction)action {
    [self deactivateTopBarFocusMode];

    switch (action) {
        case BrowserTopBarActionBack:
            if (self.webview.canGoBack) {
                [self.webview goBack];
            }
            break;
        case BrowserTopBarActionRefresh:
            [self.webview reload];
            break;
        case BrowserTopBarActionForward:
            if (self.webview.canGoForward) {
                [self.webview goForward];
            }
            break;
        case BrowserTopBarActionHome:
            [self loadHomePage];
            break;
        case BrowserTopBarActionTabs:
            [self browserShowTabOverview];
            break;
        case BrowserTopBarActionURL:
            [self showInputURLorSearchGoogle];
            break;
        case BrowserTopBarActionFullscreen:
            if (self.viewModel.topNavigationBarVisible) {
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:BrowserLocalized(@"Hide Top Navigation Bar?")
                                                                                         message:BrowserLocalized(@"You can still open Settings by double-tapping the Play/Pause button.")
                                                                                  preferredStyle:UIAlertControllerStyleAlert];
                [alertController addAction:[UIAlertAction actionWithTitle:BrowserLocalized(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
                [alertController addAction:[UIAlertAction actionWithTitle:BrowserLocalized(@"Hide Bar")
                                                                    style:UIAlertActionStyleDestructive
                                                                  handler:^(__unused UIAlertAction *action) {
                    [self browserHideTopNav];
                }]];
                [self browserPresentViewController:alertController];
            } else {
                [self browserShowTopNav];
            }
            break;
        case BrowserTopBarActionReader:
            [self deactivateTopBarFocusMode];
            [self browserShowReader];
            break;
        case BrowserTopBarActionFeed:
            [self deactivateTopBarFocusMode];
            if (self.pageHasFeed && ![self browserPageFeedIsSubscribed]) {
                [self browserSubscribeToPageFeed];
            } else {
                [self browserShowFeeds];
            }
            break;
        case BrowserTopBarActionMenu:
            [self showAdvancedMenu];
            break;
    }
}

- (NSUInteger)effectiveTextFontSize {
    // A web app keeps its own text size (asked the first time it opens).
    NSNumber *size = self.webAppMode && self.webAppURLString.length > 0
        ? [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"BrowserWebAppTextSizes"][self.webAppURLString] : nil;
    return size != nil ? size.unsignedIntegerValue : self.viewModel.textFontSize;
}

- (void)askWebAppTextSize {
    // The same font size slider as in Settings – but only for this web app.
    NSString *URLString = self.webAppURLString;
    if (URLString.length == 0) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    [self.menuCoordinator presentTextSizeSliderWithValue:[self effectiveTextFontSize] changed:^(NSUInteger size) {
        NSMutableDictionary *sizes = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"BrowserWebAppTextSizes"] mutableCopy] ?: [NSMutableDictionary dictionary];
        sizes[URLString] = @(size);
        [[NSUserDefaults standardUserDefaults] setObject:sizes forKey:@"BrowserWebAppTextSizes"];
        [weakSelf updateTextFontSize];
    }];
    // Asked once: even when the slider is closed without a change, the current size counts as chosen.
    NSMutableDictionary *sizes = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"BrowserWebAppTextSizes"] mutableCopy] ?: [NSMutableDictionary dictionary];
    if (sizes[URLString] == nil) {
        sizes[URLString] = @([self effectiveTextFontSize]);
        [[NSUserDefaults standardUserDefaults] setObject:sizes forKey:@"BrowserWebAppTextSizes"];
    }
}

- (void)updateTextFontSize {
    if (self.webview == nil) {
        return;
    }

    // Three passes, so sizes never stack up: undo our own sizes, read every element's page size, then write the new ones.
    // (Reading and writing in one pass made em-based text grow twice – the page "went crazy" and never found its way back.)
    NSString *jsString = [[NSString alloc] initWithFormat:
                          @"(function(){"
                           "var m=%lu/100;"
                           "var roots=[document.documentElement, document.body];"
                           "roots.forEach(function(r){ if (r && r.style) { r.style.removeProperty('-webkit-text-size-adjust'); r.style.removeProperty('text-size-adjust'); } });"
                           "if (!document.body || !window.getComputedStyle) { return ''; }"
                           "var els=document.querySelectorAll('body, body *');"
                           "for (var i=0;i<els.length;i++){ var e=els[i];"
                               "if (!e.hasAttribute('data-orb-fs')) { continue; }"
                               "var prev=e.getAttribute('data-orb-inline')||'';"
                               "e.style.removeProperty('font-size');"
                               "if (prev) { var parts=prev.split('|'); e.style.setProperty('font-size', parts[0], parts[1]||''); }"
                               "e.removeAttribute('data-orb-fs'); e.removeAttribute('data-orb-inline');"
                           "}"
                           "if (Math.abs(m-1)<0.001) { return 'reset'; }"
                           "var sizes=[];"
                           "for (var j=0;j<els.length;j++){ var t=els[j].tagName ? els[j].tagName.toLowerCase() : '';"
                               "if (t==='script'||t==='style'||t==='noscript'||t==='svg') { sizes.push(0); continue; }"
                               "var px=parseFloat(window.getComputedStyle(els[j]).fontSize||'');"
                               "sizes.push(isFinite(px)&&px>0 ? px : 0);"
                           "}"
                           "for (var k=0;k<els.length;k++){ if (!sizes[k]) { continue; } var el=els[k];"
                               "var inline=el.style.getPropertyValue('font-size');"
                               "el.setAttribute('data-orb-inline', inline ? inline+'|'+el.style.getPropertyPriority('font-size') : '');"
                               "el.setAttribute('data-orb-fs','1');"
                               "el.style.setProperty('font-size', (sizes[k]*m)+'px', 'important');"
                           "}"
                           "return 'ok';"
                          "})()",
                          (unsigned long)[self effectiveTextFontSize]];
    [self.webview stringByEvaluatingJavaScriptFromString:jsString];
}

- (void)showInputURLorSearchGoogle {
    // Straight to the Apple TV keyboard, without the "Enter URL or Search Terms" window in between.
    // An almost invisible text field: becoming first responder brings up the full-screen tvOS keyboard.
    UIView *hostView = self.view;
    if (hostView.window == nil) {
        return;
    }
    UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(0.0, 0.0, 2.0, 2.0)];
    textField.alpha = 0.02;
    textField.keyboardType = UIKeyboardTypeDefault;
    textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    textField.autocorrectionType = UITextAutocorrectionTypeNo;
    // The keyboard's main key reads "Search": a web address opens the site, anything else is searched on Google.
    textField.returnKeyType = UIReturnKeySearch;

    __weak typeof(self) weakSelf = self;
    __weak UITextField *weakField = textField;
    __block BOOL finished = NO;
    [textField addAction:[UIAction actionWithHandler:^(__unused UIAction *action) {
        UITextField *field = weakField;
        if (field == nil || finished) {
            return;
        }
        finished = YES;
        NSString *text = [field.text ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        [field removeFromSuperview];
        if (text.length > 0) {
            [weakSelf openAddressOrSearch:text];
        }
    }] forControlEvents:UIControlEventEditingDidEndOnExit];
    // Leaving the keyboard with the Menu button: nothing happens.
    [textField addAction:[UIAction actionWithHandler:^(__unused UIAction *action) {
        UITextField *field = weakField;
        if (field == nil || finished) {
            return;
        }
        finished = YES;
        [field removeFromSuperview];
    }] forControlEvents:UIControlEventEditingDidEnd];

    [hostView addSubview:textField];
    if (![textField becomeFirstResponder]) {
        [textField removeFromSuperview];
    }
}

- (BOOL)textLooksLikeWebAddress:(NSString *)text {
    if ([text rangeOfCharacterFromSet:NSCharacterSet.whitespaceCharacterSet].location != NSNotFound) {
        return NO;
    }
    NSString *lowercase = text.lowercaseString;
    if ([lowercase hasPrefix:@"http://"] || [lowercase hasPrefix:@"https://"] || [lowercase hasPrefix:@"localhost"]) {
        return YES;
    }
    // Something like "apple.com" or "srf.ch/news": a dot with letters on both sides.
    NSRange dot = [text rangeOfString:@"."];
    return dot.location != NSNotFound && dot.location > 0 && dot.location < text.length - 1;
}

- (void)openAddressOrSearch:(NSString *)text {
    NSURLRequest *request = nil;
    if ([self textLooksLikeWebAddress:text]) {
        request = [self.navigationService requestForEnteredAddressString:text];
    }
    if (request == nil) {
        request = [self.navigationService googleSearchRequestForQuery:text];
    }
    if (request != nil) {
        [self.webview loadRequest:request];
    }
}

- (void)requestURLorSearchInput {
    // The quick menu, built like the Reader's "Appearance" panel: font size, page appearance, actions, ad blocker.
    BrowserQuickMenuViewController *menu = [[BrowserQuickMenuViewController alloc] initWithTitle:BrowserLocalized(@"Quick Menu")];
    __weak typeof(self) weakSelf = self;

    [menu setFontSize:[self effectiveTextFontSize] changed:^(NSUInteger size) {
        if (weakSelf.webAppMode && weakSelf.webAppURLString.length > 0) {
            NSMutableDictionary *sizes = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"BrowserWebAppTextSizes"] mutableCopy] ?: [NSMutableDictionary dictionary];
            sizes[weakSelf.webAppURLString] = @(size);
            [[NSUserDefaults standardUserDefaults] setObject:sizes forKey:@"BrowserWebAppTextSizes"];
        } else {
            weakSelf.browserTextFontSize = size;
        }
        [weakSelf updateTextFontSize];
    }];

    // Original (the site's own look) · Automatic (follows the Apple TV) · Light · Dark
    NSInteger appearance = BrowserWebView.forceDarkPages ? (BrowserWebView.appearanceMode == 1 ? 2 : (BrowserWebView.appearanceMode == 2 ? 3 : 1)) : 0;
    [menu setAppearanceSelected:appearance changed:^(NSInteger index) {
        if (index == 0) {
            BrowserWebView.forceDarkPages = NO;
            return;
        }
        BrowserWebView.appearanceMode = (index == 1) ? 0 : (index == 2 ? 1 : 2);
        BrowserWebView.forceDarkPages = YES;
    }];

    if (self.webAppMode) {
        [menu addItemWithSymbol:@"xmark.circle" title:BrowserLocalized(@"Leave Web App") action:^{
            [weakSelf browserLeaveWebApp];
            [weakSelf browserShowStartPage];
        }];
    } else {
        [menu addItemWithSymbol:@"house" title:BrowserLocalized(@"Start Page") action:^{
            [weakSelf browserShowStartPage];
        }];
    }
    [menu addItemWithSymbol:@"magnifyingglass" title:BrowserLocalized(@"Search") action:^{
        [weakSelf showInputURLorSearchGoogle];
    }];
    BOOL hasPage = self.webview.request != nil && self.webview.request.URL.absoluteString.length > 0;
    if (hasPage) {
        [menu addItemWithSymbol:@"text.alignleft" title:BrowserLocalized(@"Reader") action:^{
            [weakSelf browserShowReader];
        }];
        [menu addItemWithSymbol:@"arrow.clockwise" title:BrowserLocalized(@"Reload") action:^{
            weakSelf.tabCoordinator.previousURL = @"";
            [weakSelf.webview reload];
        }];
    }
    if (self.webview.canGoForward) {
        [menu addItemWithSymbol:@"chevron.forward" title:BrowserLocalized(@"Forward") action:^{
            [weakSelf.webview goForward];
        }];
    }
    [menu addItemWithSymbol:@"gearshape" title:BrowserLocalized(@"Settings") action:^{
        [weakSelf showAdvancedMenu];
    }];

    [menu setToggleTitle:BrowserLocalized(@"Block Ads") value:BrowserWebView.adBlockEnabled changed:^(BOOL on) {
        BrowserWebView.adBlockEnabled = on;
        [weakSelf.webview reload];
    }];

    [self deactivateTopBarFocusMode];
    [self presentViewController:menu animated:NO completion:nil];
}

/// First start of a new version: "What's New", then the usage guide.
- (void)showWhatsNewIfNeeded {
    // Version and build: a new beta of the same version (1.1.0 Beta 1 → Beta 2) shows What's New again.
    NSString *shortVersion = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"";
    NSString *build = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"";
    NSString *version = shortVersion.length > 0 ? [NSString stringWithFormat:@"%@ (%@)", shortVersion, build] : @"";
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (version.length == 0 || [[defaults stringForKey:@"BrowserWhatsNewShownVersion"] isEqualToString:version]) {
        return;
    }
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        ViewController *strongSelf = weakSelf;
        UIViewController *presenter = strongSelf;
        if ([strongSelf.presentedViewController isKindOfClass:[BrowserStartPageViewController class]] &&
            strongSelf.presentedViewController.presentedViewController == nil) {
            presenter = strongSelf.presentedViewController; // over the start page
        }
        if (strongSelf == nil || (presenter == strongSelf && strongSelf.presentedViewController != nil) || strongSelf.view.window == nil) {
            return; // try again at the next start
        }
        [defaults setObject:version forKey:@"BrowserWhatsNewShownVersion"];
        BrowserWhatsNewViewController *whatsNew = [BrowserWhatsNewViewController new];
        whatsNew.continueHandler = ^{
            [weakSelf showHintsAlert];
        };
        [presenter presentViewController:whatsNew animated:YES completion:nil];
    });
}

- (void)showHintsAlert {
    BrowserUsageGuideViewController *guide = [BrowserUsageGuideViewController new];
    if (self.presentedViewController != nil) {
        __weak typeof(self) weakSelf = self;
        [self.presentedViewController dismissViewControllerAnimated:NO completion:^{
            [weakSelf presentViewController:guide animated:YES completion:nil];
        }];
        return;
    }
    [self presentViewController:guide animated:YES completion:nil];
}

- (void)browserHandlePrimaryAction {
    if (!self.remoteInputController.cursorModeEnabled || self.webview == nil) {
        return;
    }

    if ([self cursorIsOverShowTopBarButton]) {
        [self browserShowTopNav];
        return;
    }

    // The page now runs underneath the floating bar, so check the bar's own area instead of the web view's top edge.
    CGPoint cursorTip = self.remoteInputController.cursorView.frame.origin;
    if (self.viewModel.topNavigationBarVisible &&
        !self.topMenuView.hidden &&
        !self.topBarScrolledAway &&
        cursorTip.y < CGRectGetMaxY(self.topMenuView.frame)) {
        [self activateTopBarFocusMode];
        return;
    }

    CGPoint domPoint = [self browserDOMPointForCursor];
    [self.pageActionCoordinator handlePageSelectionAtDOMPoint:domPoint webView:self.webview];
}

- (NSArray<id<UIFocusEnvironment>> *)preferredFocusEnvironments {
    if (self.topBarFocusActive) {
        UIView *preferredFocusItem = [self.topMenuView preferredFocusItem];
        if (preferredFocusItem != nil) {
            return @[preferredFocusItem];
        }
    }
    return [super preferredFocusEnvironments];
}

#pragma mark - BrowserTopBarViewDelegate

- (void)browserTopBarView:(__unused BrowserTopBarView *)topBarView didTriggerAction:(BrowserTopBarAction)action {
    [self performTopBarAction:action];
}

#pragma mark - BrowserMenuCoordinatorHost

- (BrowserWebView *)browserWebView {
    return self.webview;
}

- (NSString *)browserPreviousURL {
    return self.tabCoordinator.previousURL;
}

- (void)setBrowserPreviousURL:(NSString *)browserPreviousURL {
    self.tabCoordinator.previousURL = browserPreviousURL ?: @"";
}

- (NSUInteger)browserTextFontSize {
    return self.viewModel.textFontSize;
}

- (void)setBrowserTextFontSize:(NSUInteger)browserTextFontSize {
    self.viewModel.textFontSize = browserTextFontSize;
    self.preferencesStore.textFontSize = self.viewModel.textFontSize;
}

- (BOOL)browserTopMenuShowing {
    return self.viewModel.topNavigationBarVisible;
}

- (BOOL)browserFullscreenVideoPlaybackEnabled {
    return self.viewModel.fullscreenVideoPlaybackEnabled;
}

- (void)setBrowserFullscreenVideoPlaybackEnabled:(BOOL)browserFullscreenVideoPlaybackEnabled {
    self.viewModel.fullscreenVideoPlaybackEnabled = browserFullscreenVideoPlaybackEnabled;
    self.preferencesStore.fullscreenVideoPlaybackEnabled = browserFullscreenVideoPlaybackEnabled;
}

- (void)browserPresentViewController:(UIViewController *)viewController {
    [self deactivateTopBarFocusMode];
    [self presentViewController:viewController animated:YES completion:nil];
}

- (void)browserLoadHomePage {
    [self loadHomePage];
}

- (void)browserSetSettingsTitleShown:(BOOL)shown {
    // While Settings are open the address field reads "Einstellungen", like in the prototype.
    [self.topMenuView setOverrideTitle:(shown ? BrowserLocalized(@"Settings") : nil) subtitle:(shown ? @"Orbrisa" : nil)];
}

#pragma mark - Reader & feeds

- (void)showSimpleAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:BrowserLocalized(@"OK") style:UIAlertActionStyleCancel handler:nil]];
    [self browserPresentViewController:alert];
}

- (void)refreshPageFeatures {
    // A quick look at the page (a few paragraphs of text? a feed link in the head?) – fast enough to run while it loads.
    if (self.webview == nil || [BrowserWebView isWaitingForPage]) {
        return;
    }
    static NSString * const probe =
        @"(function(){try{var n=0,c=0,ps=document.querySelectorAll('p');"
        @"for(var i=0;i<ps.length&&i<500;i++){var t=(ps[i].textContent||'').trim().length;if(t>=60){n++;c+=t;}}"
        @"var f=document.querySelector('link[rel~=\"alternate\"][type*=\"rss\"],link[rel~=\"alternate\"][type*=\"atom\"],link[rel~=\"alternate\"][type*=\"feed\"]');"
        @"return (n>=3&&c>=600?'1':'0')+(f?'1':'0');}catch(e){return '00';}})()";
    NSString *result = [self.webview stringByEvaluatingJavaScriptFromString:probe] ?: @"";
    BOOL reader = [result hasPrefix:@"1"];
    BOOL feed = result.length >= 2 && [result characterAtIndex:1] == '1';
    self.pageHasFeed = feed;
    [self.topMenuView setReaderAvailable:reader feedAvailable:feed];
    [self openReaderAutomaticallyIfWanted:reader];
}

- (void)openReaderAutomaticallyIfWanted:(BOOL)readerAvailable {
    // "Always Open in Reader" for this site: open each article once, as soon as its text is there.
    NSURL *URL = self.webview.request.URL;
    NSString *page = URL.absoluteString ?: @"";
    BOOL fromFeeds = CACurrentMediaTime() < self.feedReaderPendingUntil;
    if (!readerAvailable || page.length == 0 || [self.autoReaderURL isEqualToString:page] || self.presentedViewController != nil
        || !(fromFeeds || [BrowserReaderViewController opensAutomaticallyForURL:URL])) {
        return;
    }
    NSString *script = [BrowserReaderViewController extractionScript];
    NSDictionary *article = script.length > 0
        ? [BrowserReaderViewController articleFromJavaScriptResult:[self.webview stringByEvaluatingJavaScriptFromString:script]] : nil;
    if (article == nil) {
        return; // not enough text yet – the next check tries again
    }
    self.autoReaderURL = page;
    self.pageArticle = article;
    self.pageArticleURL = page;
    BrowserReaderViewController *reader = [[BrowserReaderViewController alloc] initWithArticle:article];
    if (fromFeeds) {
        // Read from the feeds: Back from the Reader returns to the feed list.
        self.feedReaderPendingUntil = 0;
        __weak typeof(self) weakSelf = self;
        reader.didClose = ^{
            dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf browserShowFeeds]; });
        };
    }
    [self browserPresentViewController:reader];
}

- (void)schedulePageFeatureChecksForWebView:(id)webView delays:(NSArray<NSNumber *> *)delays {
    NSUInteger generation = ++self.pageProbeGeneration;
    __weak typeof(self) weakSelf = self;
    for (NSNumber *delay in delays) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            ViewController *strongSelf = weakSelf;
            if (strongSelf == nil || generation != strongSelf.pageProbeGeneration || webView != strongSelf.webview) {
                return; // a newer page took over
            }
            [strongSelf refreshPageFeatures];
        });
    }
}

- (void)browserShowReader {
    NSString *page = self.webview.request.URL.absoluteString ?: @"";
    NSDictionary *article = (self.pageArticle != nil && [self.pageArticleURL isEqualToString:page]) ? self.pageArticle : nil;
    if (article == nil) {
        NSString *script = [BrowserReaderViewController extractionScript];
        NSString *result = (script.length > 0 && self.webview != nil) ? [self.webview stringByEvaluatingJavaScriptFromString:script] : nil;
        article = [BrowserReaderViewController articleFromJavaScriptResult:result];
    }
    if (article == nil) {
        [self showSimpleAlertWithTitle:BrowserLocalized(@"Reader Not Available")
                               message:BrowserLocalized(@"This page has no article that Orbrisa can show in the Reader.")];
        return;
    }
    [self browserPresentViewController:[[BrowserReaderViewController alloc] initWithArticle:article]];
}

- (void)browserTabCoordinatorShowStartPage {
    [self browserShowStartPage];
}

/// YES when the open tab shows no real web page (no address, about:blank, an empty data page ...).
- (BOOL)browserActiveTabIsEmpty {
    if (self.webview.request.URL.host.length > 0) {
        return NO;
    }
    BrowserTabViewModel *tab = self.tabCoordinator.activeTab;
    NSString *stored = tab.URLString.length > 0 ? tab.URLString : tab.requestURL;
    return [NSURL URLWithString:stored ?: @""].host.length == 0;
}

- (void)browserShowStartPage {
    [self showStartPageAttempt:0];
}

- (void)showStartPageAttempt:(NSUInteger)attempt {
    if (self.webAppMode || self.view.window == nil) {
        return;
    }
    if (self.presentedViewController != nil) {
        // New tabs come from the tab overview or Settings – wait until they have closed.
        if (![self.presentedViewController isKindOfClass:[BrowserStartPageViewController class]] && attempt < 12) {
            __weak typeof(self) weakSelf = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakSelf showStartPageAttempt:attempt + 1];
            });
        }
        return;
    }
    [self deactivateTopBarFocusMode];
    BOOL hasPage = ![self browserActiveTabIsEmpty];
    if (!hasPage) {
        // An empty tab: Google loads behind the start page right away, so Back simply shows it – never a blank page.
        NSURLRequest *google = [self.navigationService requestForURLString:@"https://www.google.com"];
        if (google != nil) {
            [self.webview loadRequest:google];
        }
    }
    BrowserStartPageViewController *start = [[BrowserStartPageViewController alloc] initWithTabCount:self.viewModel.tabs.count canGoBack:YES];
    __weak typeof(self) weakSelf = self;
    start.openURL = ^(NSString *URLString, BOOL asWebApp) {
        if (asWebApp) {
            [weakSelf browserOpenWebAppWithURLString:URLString];
            return;
        }
        NSURLRequest *request = [weakSelf.navigationService requestForURLString:URLString];
        if (request != nil) {
            [weakSelf.webview loadRequest:request];
        }
    };
    start.search = ^{ [weakSelf showInputURLorSearchGoogle]; };
    start.showTabs = ^{ [weakSelf browserShowTabOverview]; };
    start.showSettings = ^{ [weakSelf showAdvancedMenu]; };
    start.showFeeds = ^{ [weakSelf browserShowFeeds]; };
    start.favoritesChanged = ^{ [weakSelf.tabCoordinator updateTopShelf]; };
    [self presentViewController:start animated:YES completion:nil];
}

#pragma mark - Web app mode

- (void)browserOpenWebAppWithURLString:(NSString *)URLString {
    // A favorite as an app: full screen, no bar. Play/Pause → "Leave Web App" brings the bar back.
    NSURLRequest *request = [self.navigationService requestForURLString:URLString];
    if (request == nil) {
        return;
    }
    if (!self.webAppMode) {
        self.cursorModeBeforeWebApp = self.remoteInputController.cursorModeEnabled;
    }
    self.webAppMode = YES;
    self.webAppURLString = URLString;
    // Simple controls: swipe scrolls the page anywhere, hold the clickpad to pick something (the white box).
    [self.remoteInputController setLinkNavigationActive:NO];
    [self.remoteInputController setCursorModeEnabled:NO];

    self.webAppAskedTextSize = NO;
    [self deactivateTopBarFocusMode];
    self.viewModel.topNavigationBarVisible = NO; // only for now – the saved setting stays as it is
    [self.tabCoordinator setTopNavigationVisible:NO];
    [self updateShowTopBarButtonAnimated:YES];
    [self.webview loadRequest:request];
    [self showWebAppSplashForURLString:URLString];
    [self showWebAppHint];
}

- (void)showWebAppSplashForURLString:(NSString *)URLString {
    // Like a real app starting: its colour, logo and name instead of a white page while it loads.
    [self.webAppSplashView removeFromSuperview];
    NSString *host = [NSURL URLWithString:URLString].host.lowercaseString ?: @"";
    if ([host hasPrefix:@"www."]) {
        host = [host substringFromIndex:4];
    }
    NSString *name = [BrowserStartPageViewController nameForFavoriteURL:URLString] ?: host;
    UIColor *color = [BrowserFeedStore colorForFeedURL:host];

    UIView *splash = [[UIView alloc] initWithFrame:self.view.bounds];
    splash.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    splash.backgroundColor = [UIColor colorWithRed:0.067 green:0.071 blue:0.086 alpha:1.0];
    UIView *tile = [UIView new];
    tile.translatesAutoresizingMaskIntoConstraints = NO;
    tile.backgroundColor = color;
    tile.layer.cornerRadius = 56.0;
    tile.clipsToBounds = YES;
    UILabel *letter = [UILabel new];
    letter.translatesAutoresizingMaskIntoConstraints = NO;
    letter.text = name.length > 0 ? [[name substringToIndex:[name rangeOfComposedCharacterSequenceAtIndex:0].length] uppercaseString] : @"";
    letter.font = [UIFont systemFontOfSize:110.0 weight:UIFontWeightBold];
    letter.textColor = UIColor.whiteColor;
    [tile addSubview:letter];
    UIImageView *logo = [UIImageView new];
    logo.translatesAutoresizingMaskIntoConstraints = NO;
    logo.contentMode = UIViewContentModeScaleAspectFill;
    logo.hidden = YES;
    [tile addSubview:logo];
    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = name;
    title.font = [UIFont systemFontOfSize:44.0 weight:UIFontWeightBold];
    title.textColor = UIColor.whiteColor;
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    spinner.translatesAutoresizingMaskIntoConstraints = NO;
    spinner.color = [UIColor colorWithWhite:1.0 alpha:0.6];
    [spinner startAnimating];
    [splash addSubview:tile];
    [splash addSubview:title];
    [splash addSubview:spinner];
    [NSLayoutConstraint activateConstraints:@[
        [tile.centerXAnchor constraintEqualToAnchor:splash.centerXAnchor],
        [tile.centerYAnchor constraintEqualToAnchor:splash.centerYAnchor constant:-80.0],
        [tile.widthAnchor constraintEqualToConstant:240.0],
        [tile.heightAnchor constraintEqualToConstant:240.0],
        [letter.centerXAnchor constraintEqualToAnchor:tile.centerXAnchor],
        [letter.centerYAnchor constraintEqualToAnchor:tile.centerYAnchor],
        [logo.topAnchor constraintEqualToAnchor:tile.topAnchor],
        [logo.bottomAnchor constraintEqualToAnchor:tile.bottomAnchor],
        [logo.leadingAnchor constraintEqualToAnchor:tile.leadingAnchor],
        [logo.trailingAnchor constraintEqualToAnchor:tile.trailingAnchor],
        [title.topAnchor constraintEqualToAnchor:tile.bottomAnchor constant:40.0],
        [title.centerXAnchor constraintEqualToAnchor:splash.centerXAnchor],
        [spinner.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:40.0],
        [spinner.centerXAnchor constraintEqualToAnchor:splash.centerXAnchor],
    ]];
    [BrowserStartPageViewController loadLogoForURL:URLString completion:^(UIImage *image) {
        if (image != nil) {
            logo.image = image;
            logo.hidden = NO;
            letter.hidden = YES;
            tile.backgroundColor = UIColor.whiteColor;
        }
    }];
    [self.view addSubview:splash];
    if (self.webAppHintView.superview != nil) {
        [self.view bringSubviewToFront:self.webAppHintView];
    }
    self.webAppSplashView = splash;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf hideWebAppSplash]; // slow page: don't keep the splash forever
    });
}

- (void)hideWebAppSplash {
    UIView *splash = self.webAppSplashView;
    if (splash == nil) {
        return;
    }
    self.webAppSplashView = nil;
    [UIView animateWithDuration:0.4 animations:^{ splash.alpha = 0.0; } completion:^(__unused BOOL finished) {
        [splash removeFromSuperview];
    }];
}

- (BOOL)browserRemoteInputControllerHandleDownHold {
    if (!self.webAppMode || self.presentedViewController != nil) {
        return NO;
    }
    // In a web app: the favorite web apps come up from the bottom to switch between them.
    BrowserWebAppDockViewController *dock = [[BrowserWebAppDockViewController alloc] initWithCurrentURL:self.webAppURLString];
    __weak typeof(self) weakSelf = self;
    dock.openWebApp = ^(NSString *URLString) {
        if (![URLString isEqualToString:weakSelf.webAppURLString]) {
            [weakSelf browserOpenWebAppWithURLString:URLString];
        }
    };
    dock.showStartPage = ^{
        [weakSelf browserLeaveWebApp];
        [weakSelf browserShowStartPage];
    };
    [self.remoteInputController setLinkNavigationActive:NO];
    [self presentViewController:dock animated:NO completion:nil];
    return YES;
}

- (BOOL)browserRemoteInputControllerHandleSelectHold {
    if (!self.webAppMode || self.presentedViewController != nil) {
        return NO;
    }
    // Hold the middle of the clickpad: the selection box appears to pick a link or button; hold again (or Back) to scroll freely.
    [self.remoteInputController setLinkNavigationActive:!self.remoteInputController.linkNavigationActive];
    return YES;
}

- (void)browserRemoteInputControllerCursorModeDidChange:(BOOL)enabled {
    // Taking the mouse (double click) in a web app means leaving it: back to the start page.
    if (enabled && self.webAppMode && !self.leavingWebApp) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self browserLeaveWebApp];
            [self browserShowStartPage];
        });
    }
}

static NSString *BrowserWebAppPagingScript(void) {
    // Right / left in a web app: the page's own "next" / "previous" (rel=next, "Weiter", "»", or the next page number).
    return
    @"(function(dir){try{"
    @"function vis(e){var r=e.getBoundingClientRect();return r.width>0&&r.height>0;}"
    @"function label(e){return ((e.textContent||'')+' '+(e.getAttribute('aria-label')||'')+' '+(e.getAttribute('title')||'')).replace(/\\s+/g,' ').trim();}"
    @"var rel=document.querySelector(dir==='next'?'a[rel~=next][href],link[rel~=next][href]':'a[rel~=prev][href],link[rel~=prev][href]');"
    @"if(rel&&rel.href){location.href=rel.href;return 'ok';}"
    @"var words=dir==='next'?/^(next|weiter|nächste|older|ältere|mehr laden|load more|›|»|→)/i:/^(prev|previous|zurück|vorherige|newer|neuere|‹|«|←)/i;"
    @"var links=Array.prototype.filter.call(document.querySelectorAll('a[href],button,[role=button]'),vis);"
    @"var hit=null;"
    @"for(var i=0;i<links.length&&!hit;i++){var t=label(links[i]);if(t.length&&t.length<30&&words.test(t)){hit=links[i];}}"
    @"if(!hit){var cur=document.querySelector('[aria-current=page],.page-numbers.current,.pagination .active,.pagination .current,.pager .active');"
    @"var n=cur?parseInt((cur.textContent||'').trim(),10):NaN;"
    @"if(!isNaN(n)){var want=String(n+(dir==='next'?1:-1));for(var j=0;j<links.length&&!hit;j++){if((links[j].textContent||'').trim()===want){hit=links[j];}}}}"
    @"if(!hit){return 'none';}"
    @"if(hit.href&&hit.href.indexOf('javascript:')!==0){location.href=hit.href;}else{hit.click();}"
    @"return 'ok';}catch(e){return 'none';}})";
}

- (BOOL)browserRemoteInputControllerPresentedViewControllerHandlesMenu {
    if ([self.presentedViewController isKindOfClass:[BrowserStartPageViewController class]]) {
        [(BrowserStartPageViewController *)self.presentedViewController handleBackPress];
        return YES;
    }
    return NO;
}

- (BOOL)browserRemoteInputControllerHandleSideArrow:(NSString *)direction {
    if (!self.webAppMode || self.webview == nil) {
        return NO;
    }
    NSString *script = [NSString stringWithFormat:@"%@('%@')", BrowserWebAppPagingScript(), direction];
    NSString *result = [self.webview stringByEvaluatingJavaScriptFromString:script] ?: @"none";
    if ([result isEqualToString:@"ok"]) {
        [self showLinkNavigationHint:[direction isEqualToString:@"next"] ? BrowserLocalized(@"Next page →") : BrowserLocalized(@"← Previous page")];
        return YES;
    }
    return NO;
}

- (BOOL)browserRemoteInputControllerLinkNavigationHandleMenu {
    if (!self.webAppMode) {
        return NO;
    }
    if (self.remoteInputController.linkNavigationActive) {
        [self.remoteInputController setLinkNavigationActive:NO]; // Back: the box goes away, scrolling again
        return YES;
    }
    // In a web app, Back goes back inside the app; on its first page it leaves to the start page.
    if (self.webview.canGoBack) {
        [self.webview goBack];
    } else {
        [self browserLeaveWebApp];
        [self browserShowStartPage];
    }
    return YES;
}

- (void)browserLeaveWebApp {
    if (self.leavingWebApp) {
        return;
    }
    self.leavingWebApp = YES;
    [self hideWebAppSplash];
    [self.remoteInputController setLinkNavigationActive:NO]; // while still in the web app: no "mouse on" hint
    self.webAppMode = NO;
    [self.remoteInputController setCursorModeEnabled:self.cursorModeBeforeWebApp];
    self.leavingWebApp = NO;
    [self updateTextFontSize]; // back to the normal text size
    BOOL visible = self.preferencesStore.topNavigationBarVisible;
    self.viewModel.topNavigationBarVisible = visible;
    [self.tabCoordinator setTopNavigationVisible:visible];
    [self updateShowTopBarButtonAnimated:YES];
}

- (void)showWebAppHint {
    [self.webAppHintView removeFromSuperview];
    UIVisualEffectView *pill = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    pill.layer.cornerRadius = 32.0;
    pill.clipsToBounds = YES;
    pill.contentView.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.5];
    UILabel *label = [UILabel new];
    label.text = BrowserLocalized(@"Web App · Hold the middle: pick · Play/Pause: menu");
    label.font = [UIFont systemFontOfSize:23.0 weight:UIFontWeightSemibold];
    label.textColor = UIColor.whiteColor;
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"arrow.up.left.and.arrow.down.right"
                                                                    withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:22.0 weight:UIImageSymbolWeightSemibold]]];
    icon.tintColor = UIColor.whiteColor;
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[icon, label]];
    row.spacing = 14.0;
    row.alignment = UIStackViewAlignmentCenter;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [pill.contentView addSubview:row];
    pill.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:pill];
    [NSLayoutConstraint activateConstraints:@[
        [row.leadingAnchor constraintEqualToAnchor:pill.contentView.leadingAnchor constant:30.0],
        [row.trailingAnchor constraintEqualToAnchor:pill.contentView.trailingAnchor constant:-30.0],
        [row.centerYAnchor constraintEqualToAnchor:pill.contentView.centerYAnchor],
        [pill.heightAnchor constraintEqualToConstant:64.0],
        [pill.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:40.0],
        [pill.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
    ]];
    self.webAppHintView = pill;
    pill.alpha = 0.0;
    [UIView animateWithDuration:0.3 animations:^{ pill.alpha = 1.0; }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.5 animations:^{ pill.alpha = 0.0; } completion:^(__unused BOOL finished) {
            [pill removeFromSuperview];
        }];
    });
}

- (void)browserShowFeeds {
    BrowserFeedsViewController *feeds = [BrowserFeedsViewController new];
    __weak typeof(self) weakSelf = self;
    // Like the tab overview: the top bar stays, its address field reads "Feeds · 4 new articles".
    feeds.headerChanged = ^(NSString *subtitle) {
        [weakSelf.topMenuView setOverrideTitle:(subtitle != nil ? BrowserLocalized(@"Feeds") : nil)
                                      subtitle:subtitle
                                    symbolName:@"dot.radiowaves.up.forward"];
    };
    feeds.addFeed = ^{
        [weakSelf browserSubscribeToPageFeed];
    };
    feeds.openArticle = ^(NSString *URLString) {
        NSURLRequest *request = [weakSelf.navigationService requestForURLString:URLString];
        if (request != nil) {
            weakSelf.feedReaderPendingUntil = CACurrentMediaTime() + 25.0;
            [weakSelf.webview loadRequest:request];
        }
    };
    [self browserPresentViewController:feeds];
}

/// YES when the feed this page offers is already in the subscriptions (the feed button then just opens the feeds).
- (BOOL)browserPageFeedIsSubscribed {
    NSString *script = [BrowserFeedStore detectionScript];
    NSString *result = (script.length > 0 && self.webview != nil) ? [self.webview stringByEvaluatingJavaScriptFromString:script] : nil;
    id json = result.length > 0 ? [NSJSONSerialization JSONObjectWithData:[result dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil] : nil;
    NSArray *feeds = ([json isKindOfClass:[NSDictionary class]] && [json[@"feeds"] isKindOfClass:[NSArray class]]) ? json[@"feeds"] : @[];
    for (id feed in feeds) {
        NSString *URLString = [feed isKindOfClass:[NSDictionary class]] && [feed[@"url"] isKindOfClass:[NSString class]] ? feed[@"url"] : nil;
        if (URLString.length > 0 && [[BrowserFeedStore sharedStore] isSubscribedToURL:URLString]) {
            return YES;
        }
    }
    return NO;
}

- (void)browserSubscribeToPageFeed {
    NSString *script = [BrowserFeedStore detectionScript];
    NSString *result = (script.length > 0 && self.webview != nil) ? [self.webview stringByEvaluatingJavaScriptFromString:script] : nil;
    id json = result.length > 0 ? [NSJSONSerialization JSONObjectWithData:[result dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil] : nil;
    NSArray *feeds = ([json isKindOfClass:[NSDictionary class]] && [json[@"feeds"] isKindOfClass:[NSArray class]]) ? json[@"feeds"] : @[];
    NSString *site = ([json isKindOfClass:[NSDictionary class]] && [json[@"site"] isKindOfClass:[NSString class]]) ? json[@"site"] : @"";
    NSDictionary *feed = [feeds.firstObject isKindOfClass:[NSDictionary class]] ? feeds.firstObject : nil;
    NSString *feedURL = [feed[@"url"] isKindOfClass:[NSString class]] ? feed[@"url"] : @"";
    if (feedURL.length == 0) {
        [self showSimpleAlertWithTitle:BrowserLocalized(@"No Feed Found")
                               message:BrowserLocalized(@"This page doesn't offer an RSS feed.")];
        return;
    }

    BrowserFeedStore *store = [BrowserFeedStore sharedStore];
    __weak typeof(self) weakSelf = self;
    if ([store isSubscribedToURL:feedURL]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:BrowserLocalized(@"Already Subscribed") message:site
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:BrowserLocalized(@"Open Feeds") style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [weakSelf browserShowFeeds];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:BrowserLocalized(@"OK") style:UIAlertActionStyleCancel handler:nil]];
        [self browserPresentViewController:alert];
        return;
    }

    NSString *announcedTitle = [feed[@"title"] isKindOfClass:[NSString class]] ? feed[@"title"] : @"";
    [store fetchFeedAtURL:feedURL completion:^(NSString *title, NSArray<BrowserFeedItem *> *items, __unused NSError *error) {
        ViewController *strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        if (items.count == 0) {
            [strongSelf showSimpleAlertWithTitle:BrowserLocalized(@"Feed Not Readable")
                                         message:BrowserLocalized(@"Orbrisa found a feed on this page, but couldn't load it.")];
            return;
        }
        NSString *name = title.length > 0 ? title : (announcedTitle.length > 0 ? announcedTitle : site);
        NSMutableString *latest = [NSMutableString string];
        for (NSUInteger i = 0; i < MIN((NSUInteger)3, items.count); i++) {
            [latest appendFormat:@"%@• %@", i > 0 ? @"\n" : @"", items[i].title];
        }
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:BrowserLocalized(@"Feed Found: %@"), name]
                                                                       message:latest
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:BrowserLocalized(@"Subscribe") style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [[BrowserFeedStore sharedStore] subscribeToURL:feedURL title:name];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:BrowserLocalized(@"Not Now") style:UIAlertActionStyleCancel handler:nil]];
        [strongSelf browserPresentViewController:alert];
    }];
}

- (void)browserShowWhatsNew {
    // From the menu: the same screen as after an update; "Weiter" closes it (no usage guide afterwards).
    BrowserWhatsNewViewController *whatsNew = [BrowserWhatsNewViewController new];
    whatsNew.showsGuideHint = NO;
    if (self.presentedViewController != nil) {
        __weak typeof(self) weakSelf = self;
        [self.presentedViewController dismissViewControllerAnimated:NO completion:^{
            [weakSelf presentViewController:whatsNew animated:YES completion:nil];
        }];
        return;
    }
    [self presentViewController:whatsNew animated:YES completion:nil];
}

- (void)browserShowHints {
    [self showHintsAlert];
}

- (void)browserShowTabOverview {
    [self deactivateTopBarFocusMode];
    [self.tabCoordinator prepareTabOverviewThumbnails];
    [self.tabOverviewController show];
}

- (void)browserCreateNewTabLoadingHomePage:(BOOL)loadHomePage {
    [self.tabCoordinator createNewTabLoadingHomePage:loadHomePage];
}

- (void)browserHideTopNav {
    [self deactivateTopBarFocusMode];
    self.viewModel.topNavigationBarVisible = NO;
    self.preferencesStore.topNavigationBarVisible = NO;
    [self.tabCoordinator setTopNavigationVisible:NO];
    [self updateShowTopBarButtonAnimated:YES];
}

- (void)browserShowTopNav {
    [self setShowTopBarButtonSelected:NO animated:NO];
    self.viewModel.topNavigationBarVisible = YES;
    self.preferencesStore.topNavigationBarVisible = YES;
    [self.tabCoordinator setTopNavigationVisible:YES];
    [self updateShowTopBarButtonAnimated:YES];
}

#pragma mark - Link navigation (arrow clicks jump between links)

static NSString *BrowserLinkNavigationScript(void) {
    static NSString *script = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        script =
    @"(function(cmd, topInset, feed){\n"
    @"var N = window.__tvLinkNav;\n"
    @"if (!N) {\n"
    @"  N = window.__tvLinkNav = {cur: null};\n"
    @"}\n"
    @"if (!document.getElementById('__tvLinkNavStyle')) {\n"
    @"  var st = document.createElement('style');\n"
    @"  st.id = '__tvLinkNavStyle';\n"
    @"  st.textContent = '.__tvLinkNavFocus{outline:4px solid #FFFFFF !important;outline-offset:3px !important;border-radius:12px !important;box-shadow:0 0 0 7px rgba(0,0,0,0.55),0 18px 40px rgba(0,0,0,0.45) !important;background-color:rgba(255,255,255,0.14) !important;transition:outline-offset .15s ease, box-shadow .15s ease !important;}';\n"
    @"  (document.head || document.documentElement).appendChild(st);\n"
    @"}\n"
    @"if (feed && !document.getElementById('__tvFeedStyle')) {\n"
    @"  var fs = document.createElement('style');\n"
    @"  fs.id = '__tvFeedStyle';\n"
    @"  var lum = 1; [document.body, document.documentElement].some(function(e){ if (!e) { return false; } var m = (getComputedStyle(e).backgroundColor || '').match(/[\\d.]+/g); if (m && (m.length < 4 || +m[3] > 0.1)) { lum = (0.299 * m[0] + 0.587 * m[1] + 0.114 * m[2]) / 255; return true; } return false; });\n"
    @"  var forcedDark = !!document.getElementById('__tvForceDarkStyle');\n"
    @"  var C = (forcedDark || lum < 0.5) ? '10,132,255' : '52,199,89'; window.__orbDropTone = C;\n"
    @"  fs.textContent = 'html{scroll-behavior:smooth !important;} .__tvLinkNavFocus{outline:none !important;border-radius:18px !important;position:relative !important;z-index:2147483000 !important;transform:scale(1.03) !important;background-color:rgba(' + C + ',0.06) !important;box-shadow:0 0 0 2px rgba(' + C + ',0.55),0 0 26px 6px rgba(' + C + ',0.26),inset 0 1px 0 rgba(255,255,255,0.55),inset 0 -10px 22px rgba(' + C + ',0.12),0 18px 40px rgba(0,0,0,0.28) !important;transition:transform .32s cubic-bezier(.2,1.35,.4,1), box-shadow .32s ease !important;} .__tvLinkNavFocus::after{content:\"\";position:absolute;inset:0;border-radius:inherit;pointer-events:none;background:linear-gradient(180deg,rgba(255,255,255,0.28) 0%,rgba(255,255,255,0.06) 38%,rgba(255,255,255,0) 60%,rgba(' + C + ',0.10) 100%);}';\n"
    @"  (document.head || document.documentElement).appendChild(fs);\n"
    @"}\n"
    @"var SELECTOR = 'a[href],button,input:not([type=hidden]),select,textarea,summary,[role=button],[role=link],[role=tab],[role=menuitem],[role=option],[onclick],[tabindex]:not([tabindex=\"-1\"])';\n"
    @"function shown(el){\n"
    @"  var r = el.getBoundingClientRect();\n"
    @"  if (r.width < 4 || r.height < 4) { return false; }\n"
    @"  if (r.bottom <= 0 || r.right <= 0 || r.top >= innerHeight || r.left >= innerWidth) { return false; }\n"
    @"  var s = getComputedStyle(el);\n"
    @"  return s.visibility !== 'hidden' && s.display !== 'none' && parseFloat(s.opacity || '1') > 0.05;\n"
    @"}\n"
    @"function candidates(){ return Array.prototype.filter.call(document.querySelectorAll(SELECTOR), shown); }\n"
    @"function setCur(el){\n"
    @"  if (N.cur && N.cur.classList) { N.cur.classList.remove('__tvLinkNavFocus'); }\n"
    @"  N.cur = el;\n"
    @"  if (!el) { return; }\n"
    @"  el.classList.add('__tvLinkNavFocus');\n"
    @"  var r = el.getBoundingClientRect();\n"
    @"  var hidden = scrollY > 0 ? topInset : 0;\n"
    @"  if (feed) { el.scrollIntoView({block: 'center', inline: 'nearest', behavior: 'smooth'}); return; }\n"
    @"  if (r.top < hidden || r.bottom > innerHeight) { el.scrollIntoView({block: 'center', inline: 'nearest'}); }\n"
    @"}\n"
    @"function mid(r){ return {x: r.left + r.width / 2, y: r.top + r.height / 2}; }\n"
    @"if (cmd === 'clear') { setCur(null); return 'ok'; }\n"
    @"if (cmd === 'activate') {\n"
    @"  var el = N.cur;\n"
    @"  if (!el || !document.contains(el)) { return 'none'; }\n"
    @"  var r = el.getBoundingClientRect();\n"
    @"  var p = mid(r);\n"
    @"  return 'point:' + Math.round(p.x) + ',' + Math.round(p.y);\n"
    @"}\n"
    @"var list = candidates();\n"
    @"if (cmd === 'center') {\n"
    @"  var cx = innerWidth / 2, cy = innerHeight / 2, nearest = null, nd = Infinity;\n"
    @"  list.forEach(function(el){ var q = mid(el.getBoundingClientRect()), d = Math.abs(q.x - cx) * 0.6 + Math.abs(q.y - cy); if (d < nd) { nd = d; nearest = el; } });\n"
    @"  if (nearest) { setCur(nearest); return 'ok'; }\n"
    @"  return 'none';\n"
    @"}\n"
    @"if (!N.cur || !document.contains(N.cur) || !shown(N.cur)) {\n"
    @"  if (!list.length) {\n"
    @"    if (cmd === 'down') { scrollBy(0, innerHeight * 0.6); return 'scrolled'; }\n"
    @"    if (cmd === 'up') { if (scrollY <= 0) { return 'top'; } scrollBy(0, -innerHeight * 0.6); return 'scrolled'; }\n"
    @"    return 'none';\n"
    @"  }\n"
    @"  list.sort(function(a, b){\n"
    @"    var ra = a.getBoundingClientRect(), rb = b.getBoundingClientRect();\n"
    @"    return cmd === 'up' ? ((rb.bottom - ra.bottom) || (ra.left - rb.left)) : ((ra.top - rb.top) || (ra.left - rb.left));\n"
    @"  });\n"
    @"  setCur(list[0]);\n"
    @"  return 'ok';\n"
    @"}\n"
    @"var cr = N.cur.getBoundingClientRect(), c = mid(cr), best = null, bestScore = Infinity;\n"
    @"list.forEach(function(el){\n"
    @"  if (el === N.cur || el.contains(N.cur) || N.cur.contains(el)) { return; }\n"
    @"  var r = el.getBoundingClientRect(), p = mid(r), dx = p.x - c.x, dy = p.y - c.y, along, across;\n"
    @"  if (cmd === 'down') { if (r.top < cr.bottom - 2) { return; } along = dy; across = Math.abs(dx); }\n"
    @"  else if (cmd === 'up') { if (r.bottom > cr.top + 2) { return; } along = -dy; across = Math.abs(dx); }\n"
    @"  else if (cmd === 'right') { if (r.left < cr.right - 2) { return; } along = dx; across = Math.abs(dy); }\n"
    @"  else { if (r.right > cr.left + 2) { return; } along = -dx; across = Math.abs(dy); }\n"
    @"  var score = along + across * 2.5;\n"
    @"  if (score < bestScore) { bestScore = score; best = el; }\n"
    @"});\n"
    @"if (best) { setCur(best); return 'ok'; }\n"
    @"if (cmd === 'down') {\n"
    @"  if (innerHeight + scrollY >= document.documentElement.scrollHeight - 2) { return 'edge'; }\n"
    @"  scrollBy(0, innerHeight * 0.6); return 'scrolled';\n"
    @"}\n"
    @"if (cmd === 'up') {\n"
    @"  if (scrollY <= 0) { return 'top'; }\n"
    @"  scrollBy(0, -innerHeight * 0.6); return 'scrolled';\n"
    @"}\n"
    @"return 'edge';\n"
    @"})\n";
    });
    return script;
}

- (NSString *)runLinkNavigationCommand:(NSString *)command {
    if (self.webview == nil || self.webview.request == nil) {
        return @"none";
    }
    // Part of the page sits under the floating top bar; the script keeps the highlighted link out of that strip.
    NSInteger innerWidth = [[self.webview stringByEvaluatingJavaScriptFromString:@"window.innerWidth"] integerValue];
    CGFloat scale = innerWidth > 0 ? CGRectGetWidth(self.webview.frame) / (CGFloat)innerWidth : 1.0;
    CGFloat barHeight = (self.viewModel.topNavigationBarVisible && !self.topMenuView.hidden) ? CGRectGetMaxY(self.topMenuView.frame) : 0.0;
    CGFloat topInsetCSS = scale > 0.0 ? barHeight / scale : barHeight;
    NSString *script = [NSString stringWithFormat:@"%@('%@', %.1f, %@)", BrowserLinkNavigationScript(), command, topInsetCSS, self.webAppMode ? @"true" : @"false"];
    return [self.webview stringByEvaluatingJavaScriptFromString:script] ?: @"none";
}

- (void)browserRemoteInputControllerLinkNavigationDidChangeActive:(BOOL)active {
    UIImageView *cursorView = self.remoteInputController.cursorView;
    [UIView animateWithDuration:0.2 animations:^{
        cursorView.alpha = active ? 0.0 : 1.0;
    }];
    if (!active) {
        [self setShowTopBarButtonSelected:NO animated:YES];
    }
    if (active) {
        [self runLinkNavigationCommand:(self.webAppMode ? @"center" : @"down")]; // in a web app: the item in the middle of the screen
        if (!self.webAppMode) {
            [self showLinkNavigationHint:BrowserLocalized(@"Link navigation on · Arrows: switch · Click: open · Hold bottom: mouse")];
        }
    } else if (self.webAppMode) {
        [self runLinkNavigationCommand:@"clear"];
    } else {
        [self runLinkNavigationCommand:@"clear"];
        [self showLinkNavigationHint:BrowserLocalized(@"Mouse on · Hold bottom: link navigation")];
    }
}

- (NSString *)browserRemoteInputControllerLinkNavigationMove:(NSString *)direction {
    if (self.showTopBarButtonSelected) {
        if ([direction isEqualToString:@"down"]) {
            [self setShowTopBarButtonSelected:NO animated:YES];
            return [self runLinkNavigationCommand:@"down"];
        }
        return @"ok"; // nothing above or beside the red button
    }
    return [self runLinkNavigationCommand:direction];
}

- (BOOL)browserRemoteInputControllerLinkNavigationSelectShowBarButton {
    UIView *button = self.showTopBarButton;
    if (button == nil || button.hidden || button.alpha < 0.5) {
        return NO;
    }
    [self runLinkNavigationCommand:@"clear"];
    [self setShowTopBarButtonSelected:YES animated:YES];
    return YES;
}

- (void)setShowTopBarButtonSelected:(BOOL)selected animated:(BOOL)animated {
    if (_showTopBarButtonSelected == selected) {
        return;
    }
    _showTopBarButtonSelected = selected;
    UIView *button = self.showTopBarButton;
    // Same focus language as the rest: a white ring, lifted and a little larger.
    void (^changes)(void) = ^{
        button.transform = selected ? CGAffineTransformMakeScale(1.25, 1.25) : CGAffineTransformIdentity;
        button.layer.borderWidth = selected ? 4.0 : 2.0;
        button.layer.borderColor = (selected ? UIColor.whiteColor : [UIColor colorWithWhite:1.0 alpha:0.85]).CGColor;
        button.layer.shadowOpacity = selected ? 0.6 : 0.35;
        button.layer.shadowRadius = selected ? 18.0 : 10.0;
    };
    if (animated) {
        [UIView animateWithDuration:0.2 animations:changes];
    } else {
        changes();
    }
}

- (void)browserRemoteInputControllerLinkNavigationActivate {
    if (self.showTopBarButtonSelected) {
        [self setShowTopBarButtonSelected:NO animated:NO];
        [self browserShowTopNav];
        return;
    }
    NSString *result = [self runLinkNavigationCommand:@"activate"];
    if (![result hasPrefix:@"point:"]) {
        [self runLinkNavigationCommand:@"down"];
        return;
    }
    NSArray<NSString *> *parts = [[result substringFromIndex:6] componentsSeparatedByString:@","];
    if (parts.count != 2) {
        return;
    }
    CGPoint domPoint = CGPointMake(parts[0].doubleValue, parts[1].doubleValue);
    [self runLinkNavigationCommand:@"clear"];
    if (self.webAppMode) {
        [self.remoteInputController setLinkNavigationActive:NO]; // picked something: back to scrolling freely
    }
    // Same path as a cursor click, so links, text fields and videos behave exactly as before.
    [self.pageActionCoordinator handlePageSelectionAtDOMPoint:domPoint webView:self.webview];
}

- (void)showLinkNavigationHint:(NSString *)text {
    UILabel *label = self.linkNavigationHintLabel;
    if (label == nil) {
        label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.font = [UIFont systemFontOfSize:26.0 weight:UIFontWeightSemibold];
        label.textColor = UIColor.whiteColor;
        label.textAlignment = NSTextAlignmentCenter;
        label.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.82];
        label.layer.cornerRadius = 30.0;
        label.layer.masksToBounds = YES;
        label.alpha = 0.0;
        label.userInteractionEnabled = NO;
        [self.view addSubview:label];
        self.linkNavigationHintLabel = label;
    }

    label.text = text;
    CGSize textSize = [label sizeThatFits:CGSizeMake(CGRectGetWidth(self.view.bounds) - 160.0, 60.0)];
    CGFloat width = ceil(textSize.width) + 72.0;
    label.frame = CGRectMake(floor((CGRectGetWidth(self.view.bounds) - width) / 2.0),
                             CGRectGetHeight(self.view.bounds) - 140.0,
                             width,
                             60.0);
    [self.view bringSubviewToFront:label];

    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideLinkNavigationHint) object:nil];
    [UIView animateWithDuration:0.2 animations:^{
        label.alpha = 1.0;
    }];
    [self performSelector:@selector(hideLinkNavigationHint) withObject:nil afterDelay:3.0];
}

- (void)hideLinkNavigationHint {
    [UIView animateWithDuration:0.4 animations:^{
        self.linkNavigationHintLabel.alpha = 0.0;
    }];
}

#pragma mark - Red button that brings the hidden top bar back

static CGFloat const kShowTopBarButtonSize = 56.0;
static CGFloat const kShowTopBarButtonTopInset = 60.0; // tvOS top safe area, same line as the bar
static CGFloat const kShowTopBarButtonHitSlop = 24.0;

- (void)setUpShowTopBarButton {
    UIView *button = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, kShowTopBarButtonSize, kShowTopBarButtonSize)];
    button.backgroundColor = UIColor.systemRedColor;
    button.layer.cornerRadius = kShowTopBarButtonSize / 2.0;
    button.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.85].CGColor;
    button.layer.borderWidth = 2.0;
    button.layer.shadowColor = UIColor.blackColor.CGColor;
    button.layer.shadowOpacity = 0.35;
    button.layer.shadowRadius = 10.0;
    button.layer.shadowOffset = CGSizeMake(0.0, 4.0);
    button.userInteractionEnabled = NO; // clicks come from the remote's cursor, see -browserHandlePrimaryAction
    button.isAccessibilityElement = YES;
    button.accessibilityLabel = BrowserLocalized(@"Show Top Navigation Bar");
    button.accessibilityTraits = UIAccessibilityTraitButton;

    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:24.0
                                                                                                weight:UIImageSymbolWeightBold];
    UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.down" withConfiguration:configuration]];
    iconView.tintColor = UIColor.whiteColor;
    iconView.contentMode = UIViewContentModeCenter;
    iconView.frame = button.bounds;
    iconView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [button addSubview:iconView];

    UIView *cursorView = self.remoteInputController.cursorView;
    if (cursorView.superview == self.view) {
        [self.view insertSubview:button belowSubview:cursorView];
    } else {
        [self.view addSubview:button];
    }
    self.showTopBarButton = button;
    [self updateShowTopBarButtonAnimated:NO];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (self.showTopBarButton == nil) {
        return;
    }
    CGFloat width = CGRectGetWidth(self.view.bounds);
    // bounds + center (not frame): the button is scaled while it fades out.
    self.showTopBarButton.bounds = CGRectMake(0.0, 0.0, kShowTopBarButtonSize, kShowTopBarButtonSize);
    self.showTopBarButton.center = CGPointMake(width / 2.0, kShowTopBarButtonTopInset + (kShowTopBarButtonSize / 2.0));
    UIView *cursorView = self.remoteInputController.cursorView;
    if (cursorView.superview == self.view) {
        [self.view bringSubviewToFront:cursorView];
    }
    [self updateShowTopBarButtonAnimated:NO];
}

- (void)updateShowTopBarButtonAnimated:(BOOL)animated {
    UIView *button = self.showTopBarButton;
    if (button == nil) {
        return;
    }
    BOOL shouldShow = !self.viewModel.topNavigationBarVisible && !self.webAppMode;
    CGFloat targetAlpha = shouldShow ? 1.0 : 0.0;
    if (button.alpha == targetAlpha && button.hidden == !shouldShow) {
        return;
    }

    if (shouldShow) {
        button.hidden = NO;
    }
    void (^changes)(void) = ^{
        button.alpha = targetAlpha;
        button.transform = shouldShow ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.6, 0.6);
    };
    void (^completion)(BOOL) = ^(__unused BOOL finished) {
        button.hidden = self.viewModel.topNavigationBarVisible || self.webAppMode;
    };
    if (animated) {
        [UIView animateWithDuration:0.25 animations:changes completion:completion];
    } else {
        changes();
        completion(YES);
    }
}

- (BOOL)cursorIsOverShowTopBarButton {
    UIView *button = self.showTopBarButton;
    if (button == nil || button.hidden || button.alpha < 0.5) {
        return NO;
    }
    UIView *cursorView = self.remoteInputController.cursorView;
    // The cursor image's tip is its top-left corner.
    CGPoint cursorTip = [cursorView.superview convertPoint:cursorView.frame.origin toView:self.view];
    CGPoint center = button.center;
    CGFloat half = (kShowTopBarButtonSize / 2.0) + kShowTopBarButtonHitSlop;
    CGRect hitFrame = CGRectMake(center.x - half, center.y - half, half * 2.0, half * 2.0);
    return CGRectContainsPoint(hitFrame, cursorTip);
}

- (void)browserUpdateTextFontSize {
    [self updateTextFontSize];
}

- (void)browserCaptureSnapshotForCurrentTab {
    [self.tabCoordinator captureSnapshotForCurrentTab];
}

- (void)browserRecreateActiveWebViewPreservingCurrentURL {
    [self.tabCoordinator recreateActiveWebViewPreservingCurrentURL];
}

- (void)browserBringCursorToFront {
    [self.view bringSubviewToFront:self.remoteInputController.cursorView];
}

#pragma mark - BrowserVideoPlaybackCoordinatorHost

- (BOOL)browserIsCursorModeEnabled {
    return self.remoteInputController.cursorModeEnabled;
}

- (CGPoint)browserDOMCursorPoint {
    return [self browserDOMPointForCursor];
}

- (UIViewController *)browserPresentedViewController {
    return self.presentedViewController;
}

- (NSString *)browserCurrentPageTitle {
    return self.webview.title;
}

#pragma mark - BrowserTabCoordinatorHost

- (void)browserTabCoordinatorPresentViewController:(UIViewController *)viewController {
    [self browserPresentViewController:viewController];
}

- (void)browserTabCoordinatorUpdateTextFontSize {
    [self updateTextFontSize];
}

- (BOOL)browserTabCoordinatorIsCursorModeEnabled {
    return self.remoteInputController.cursorModeEnabled;
}

- (BOOL)browserTabCoordinatorIsTabOverviewVisible {
    return self.tabOverviewController.visible;
}

#pragma mark - BrowserTabOverviewControllerHost

- (BOOL)browserTabOverviewControllerCursorModeEnabled {
    return self.remoteInputController.cursorModeEnabled;
}

- (void)browserTabOverviewControllerSetCursorModeEnabled:(BOOL)enabled {
    [self.remoteInputController setCursorModeEnabled:enabled];
}

- (void)browserTabOverviewControllerPresentViewController:(UIViewController *)viewController {
    [self presentViewController:viewController animated:YES completion:nil];
}

- (void)browserTabOverviewControllerCreateNewTabLoadingHomePage:(BOOL)loadHomePage {
    [self.tabCoordinator createNewTabLoadingHomePage:loadHomePage];
}

- (void)browserTabOverviewControllerSwitchToTabAtIndex:(NSInteger)tabIndex {
    [self.tabCoordinator switchToTabAtIndex:tabIndex];
}

- (void)browserTabOverviewControllerCloseTabAtIndex:(NSInteger)tabIndex {
    [self.tabCoordinator closeTabAtIndex:tabIndex];
}

#pragma mark - BrowserPageActionCoordinatorHost

- (void)browserPageActionCoordinatorPresentViewController:(UIViewController *)viewController {
    [self browserPresentViewController:viewController];
}

- (BOOL)browserPageActionCoordinatorCreateNewTabWithRequest:(NSURLRequest *)request {
    return [self.tabCoordinator createNewTabWithRequest:request];
}

#pragma mark - BrowserRemoteInputControllerHost

- (UIScrollView *)browserRemoteInputControllerActiveScrollView {
    return self.webview.scrollView;
}

- (UIViewController *)browserRemoteInputControllerPresentedViewController {
    // A screen that is closing or no longer visible (e.g. a full-screen video that was left) must not
    // keep swallowing the remote's presses, otherwise nothing reacts any more.
    UIViewController *presented = self.presentedViewController;
    if ([presented isKindOfClass:[UIAlertController class]]) {
        // A closing question window still counts, so the press that answered it doesn't also click the page.
        return presented;
    }
    if (presented == nil || presented.isBeingDismissed || presented.view.window == nil ||
        presented.view.hidden || presented.view.alpha < 0.01) {
        return nil;
    }
    return presented;
}

- (BOOL)browserRemoteInputControllerTopBarFocusActive {
    return self.topBarFocusActive;
}

- (BOOL)browserRemoteInputControllerCanActivateTopBarFocus {
    return [self canActivateTopBarFocusMode];
}

- (void)browserRemoteInputControllerActivateTopBarFocus {
    [self activateTopBarFocusMode];
}

- (void)browserRemoteInputControllerDeactivateTopBarFocus {
    [self deactivateTopBarFocusMode];
}

- (BOOL)browserRemoteInputControllerTabOverviewVisible {
    return self.tabOverviewController.visible;
}

- (BOOL)browserRemoteInputControllerTabOverviewContainsPoint:(CGPoint)point {
    return [self.tabOverviewController containsPoint:point];
}

- (BOOL)browserRemoteInputControllerHandleTabOverviewSelectionAtPoint:(CGPoint)point {
    return [self.tabOverviewController handleSelectionAtPoint:point];
}

- (void)browserRemoteInputControllerDismissTabOverview {
    [self.tabOverviewController dismiss];
}

- (void)browserRemoteInputControllerHandleTabOverviewAlternateAction {
    [self.tabOverviewController handleAlternateAction];
}

- (void)browserRemoteInputControllerHandlePrimaryAction {
    [self browserHandlePrimaryAction];
}

- (void)browserRemoteInputControllerHandleMenuPress {
    UIAlertController *alertController = (UIAlertController *)self.presentedViewController;
    if (alertController != nil) {
        [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
    } else if (self.webAppMode) {
        [self browserRemoteInputControllerLinkNavigationHandleMenu]; // back inside the app, or out to the start page
    } else if (self.webview.canGoBack) {
        [self.webview goBack];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:BrowserLocalized(@"Exit App?")
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:BrowserLocalized(@"Exit")
                                                  style:UIAlertActionStyleDestructive
                                                handler:^(__unused UIAlertAction *action) {
            exit(EXIT_SUCCESS);
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:BrowserLocalized(@"Dismiss") style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)browserRemoteInputControllerHandlePlayPausePress {
    UIAlertController *alertController = (UIAlertController *)self.presentedViewController;
    if (alertController != nil) {
        [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self requestURLorSearchInput];
    }
}

- (void)browserRemoteInputControllerHandleAdvancedMenuPress {
    [self showAdvancedMenu];
}

- (NSString *)browserRemoteInputControllerHoverStateAtCursorPoint:(CGPoint)point {
    if (self.webview.request == nil) {
        return @"false";
    }
    CGPoint webPoint = [self.view convertPoint:point toView:self.webview];
    if (webPoint.y < 0) {
        return @"false";
    }
    CGPoint domPoint = [self browserDOMPointForCursor];
    return [self.pageActionCoordinator hoverStateAtDOMPoint:domPoint webView:self.webview];
}

- (void)browserRemoteInputControllerSetWebInteractionEnabled:(BOOL)enabled {
    self.webview.userInteractionEnabled = enabled;
}

- (void)browserRemoteInputControllerPersistSession {
    [self.tabCoordinator persistSession];
}

#pragma mark - BrowserWebViewDelegate

- (BOOL)webView:(id)webView shouldCreateNewTabWithRequest:(NSURLRequest *)request navigationType:(NSInteger)navigationType {
    (void)webView;
    (void)navigationType;
    return [self.tabCoordinator createNewTabWithRequest:request];
}

- (BOOL)webView:(id)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(NSInteger)navigationType {
    (void)navigationType;
    [self.tabCoordinator prepareTabForRequest:request webView:webView];
    return YES;
}

- (void)webViewDidStartLoad:(id)webView {
    if (webView == self.webview) {
        self.pageArticle = nil;
        self.pageHasFeed = NO;
        [self.topMenuView setReaderAvailable:NO feedAvailable:NO];
        // Check while the page is still loading – articles usually have their text long before the ads and images are done.
        [self schedulePageFeatureChecksForWebView:webView delays:@[@0.9, @1.8, @3.0, @4.5, @6.5]];
    }
    [self.tabCoordinator webViewDidStartLoad:webView];
}

- (void)webViewDidCommitNavigation:(id)webView {
    [self.tabCoordinator webViewDidCommitNavigation:webView];
}

- (void)webViewDidFinishLoad:(id)webView {
    [self.tabCoordinator webViewDidFinishLoad:webView];
    if (webView == self.webview && self.webAppMode) {
        // A web app is used like a feed: arrows jump from item to item, no mouse.
        [self hideWebAppSplash];
        BOOL known = self.webAppURLString.length > 0 && [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"BrowserWebAppTextSizes"][self.webAppURLString] != nil;
        if (!known && !self.webAppAskedTextSize && self.presentedViewController == nil) {
            self.webAppAskedTextSize = YES;
            [self askWebAppTextSize];
        }
    }
    if (webView == self.webview) {
        [self schedulePageFeatureChecksForWebView:webView delays:@[@0.15, @1.5]];
    }
    if (self.tabOverviewController.visible) {
        BrowserTabViewModel *tab = [self.tabCoordinator tabForWebView:webView];
        NSInteger tabIndex = tab != nil ? [self.viewModel.tabs indexOfObject:tab] : NSNotFound;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self.tabOverviewController.visible) {
                return;
            }
            if (tabIndex != NSNotFound) {
                [self.tabOverviewController updateCardAtIndex:tabIndex];
            } else {
                [self.tabOverviewController reload];
            }
        });
    }
}

- (void)webView:(id)webView didFailLoadWithError:(NSError *)error {
    BrowserTabViewModel *tab = [self.tabCoordinator tabForWebView:webView];
    if (tab == nil) {
        return;
    }

    NSURL *failingURL = error.userInfo[NSURLErrorFailingURLErrorKey];
    NSURLRequest *currentRequest = [webView request];
    NSString *currentRequestURLString = currentRequest.URL.absoluteString ?: @"";
    if (failingURL != nil &&
        currentRequestURLString.length > 0 &&
        ![failingURL.absoluteString isEqualToString:currentRequestURLString]) {
        return;
    }

    if (tab == self.tabCoordinator.activeTab) {
        [self.topMenuView.loadingSpinner stopAnimating];
    }
    if (tab != self.tabCoordinator.activeTab) {
        return;
    }
    if ([self.navigationService shouldIgnoreLoadError:error]) {
        return;
    }

    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:BrowserLocalized(@"Could Not Load Webpage")
                                                                             message:error.localizedDescription
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    if (tab.requestURL.length > 1) {
        [alertController addAction:[UIAlertAction actionWithTitle:BrowserLocalized(@"Google This Page")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(__unused UIAlertAction *action) {
            NSURLRequest *searchRequest = [weakSelf.navigationService googleSearchRequestForFailedRequestURLString:tab.requestURL];
            if (searchRequest != nil) {
                [weakSelf.webview loadRequest:searchRequest];
            }
        }]];
    }
    if (self.webview.request != nil && self.webview.request.URL.absoluteString.length > 0) {
        [alertController addAction:[UIAlertAction actionWithTitle:BrowserLocalized(@"Reload Page")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(__unused UIAlertAction *action) {
            weakSelf.tabCoordinator.previousURL = @"";
            [weakSelf.webview reload];
        }]];
    } else {
        [alertController addAction:[UIAlertAction actionWithTitle:BrowserLocalized(@"Enter an Address or Search")
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(__unused UIAlertAction *action) {
            [weakSelf requestURLorSearchInput];
        }]];
    }
    [alertController addAction:[UIAlertAction actionWithTitle:nil style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - Presses / Touches

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    [self.remoteInputController handlePressesBegan:presses withEvent:event];
    [super pressesBegan:presses withEvent:event];
}

- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    if ([self.remoteInputController handlePressesEnded:presses withEvent:event]) {
        return;
    }
    [super pressesEnded:presses withEvent:event];
}

// Touches go to UIKit only when UIKit also saw them begin. Forwarding a "moved" or "ended" of a touch whose
// "began" Orbrisa kept for itself (e.g. after switching between cursor, scrolling and the web app box mid-touch)
// made UIKit crash with "-[UIDropShadowView (null selector)]: unrecognized selector".
- (NSSet<UITouch *> *)forwardableTouches:(NSSet<UITouch *> *)touches {
    NSMutableSet<UITouch *> *result = [NSMutableSet set];
    for (UITouch *touch in touches) {
        if ([self.forwardedTouches containsObject:touch]) {
            [result addObject:touch];
        }
    }
    return result;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if ([self.remoteInputController handleTouchesBegan:touches withEvent:event]) {
        return;
    }
    if (self.presentedViewController != nil) {
        return; // another screen is on top (dock, menu, start page …): UIKit must not track this touch through it
    }
    if (self.forwardedTouches == nil) {
        self.forwardedTouches = [NSMutableSet set];
    }
    [self.forwardedTouches unionSet:touches];
    [super touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if ([self.remoteInputController handleTouchesMoved:touches withEvent:event]) {
        return;
    }
    NSSet<UITouch *> *forwardable = [self forwardableTouches:touches];
    if (forwardable.count > 0) {
        [super touchesMoved:forwardable withEvent:event];
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.remoteInputController handleTouchesEnded];
    NSSet<UITouch *> *forwardable = [self forwardableTouches:touches];
    [self.forwardedTouches minusSet:touches];
    if (forwardable.count > 0) {
        [super touchesEnded:forwardable withEvent:event];
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.remoteInputController handleTouchesEnded];
    NSSet<UITouch *> *forwardable = [self forwardableTouches:touches];
    [self.forwardedTouches minusSet:touches];
    if (forwardable.count > 0) {
        [super touchesCancelled:forwardable withEvent:event];
    }
}

@end
