//
//  BrowserQuickMenuViewController.m
//  Orbrisa
//

#import "BrowserQuickMenuViewController.h"

#pragma mark - Row

/// One row: soft glass capsule when idle, white with dark content when focused (like the Reader panel).
@interface BrowserQuickMenuRow : UIButton
@property (nonatomic) UIImageView *iconView;
@property (nonatomic) UILabel *nameLabel;
@property (nonatomic, copy) void (^action)(void);
@end

@implementation BrowserQuickMenuRow

- (instancetype)initWithSymbol:(NSString *)symbol title:(NSString *)title {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.layer.cornerRadius = 28.0;
        self.layer.shadowColor = UIColor.blackColor.CGColor;
        self.layer.shadowOffset = CGSizeMake(0.0, 10.0);
        self.layer.shadowRadius = 20.0;

        _iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol
                                                               withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:28.0 weight:UIImageSymbolWeightSemibold]]];
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        _iconView.contentMode = UIViewContentModeCenter;
        [self addSubview:_iconView];

        _nameLabel = [UILabel new];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _nameLabel.text = title;
        _nameLabel.font = [UIFont systemFontOfSize:27.0 weight:UIFontWeightSemibold];
        _nameLabel.adjustsFontSizeToFitWidth = YES;
        _nameLabel.minimumScaleFactor = 0.8;
        [self addSubview:_nameLabel];

        [NSLayoutConstraint activateConstraints:@[
            [self.heightAnchor constraintEqualToConstant:86.0],
            [_iconView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:28.0],
            [_iconView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_iconView.widthAnchor constraintEqualToConstant:40.0],
            [_nameLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:20.0],
            [_nameLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-24.0],
            [_nameLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        ]];
        [self applyFocused:NO];
    }
    return self;
}

- (void)applyFocused:(BOOL)focused {
    UIColor *content = focused ? [UIColor colorWithWhite:0.11 alpha:1.0] : UIColor.whiteColor;
    self.backgroundColor = focused ? UIColor.whiteColor : [UIColor colorWithWhite:1.0 alpha:0.10];
    self.nameLabel.textColor = content;
    self.iconView.tintColor = content;
    self.transform = focused ? CGAffineTransformMakeScale(1.04, 1.04) : CGAffineTransformIdentity;
    self.layer.shadowOpacity = focused ? 0.4 : 0.0;
}

- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator {
    [super didUpdateFocusInContext:context withAnimationCoordinator:coordinator];
    BOOL focused = (context.nextFocusedView == self);
    [coordinator addCoordinatedAnimations:^{ [self applyFocused:focused]; } completion:nil];
}

@end

#pragma mark - Menu

@interface BrowserQuickMenuViewController ()
@property (nonatomic, copy) NSString *menuTitle;
@property (nonatomic) NSMutableArray<BrowserQuickMenuRow *> *rows;
@property (nonatomic) UIVisualEffectView *panel;
@property (nonatomic) UIView *dimView;
@property (nonatomic) BOOL closing;
@end

@implementation BrowserQuickMenuViewController

- (instancetype)initWithTitle:(NSString *)title {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _menuTitle = [title copy];
        _rows = [NSMutableArray array];
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    }
    return self;
}

- (void)addItemWithSymbol:(NSString *)symbolName title:(NSString *)title action:(void (^)(void))action {
    BrowserQuickMenuRow *row = [[BrowserQuickMenuRow alloc] initWithSymbol:symbolName title:title];
    row.action = action;
    [row addTarget:self action:@selector(rowPressed:) forControlEvents:UIControlEventPrimaryActionTriggered];
    [self.rows addObject:row];
}

- (UIVisualEffect *)glassEffect {
    Class glassClass = NSClassFromString(@"UIGlassEffect");
    if (glassClass != Nil) {
        id effect = [[glassClass alloc] init];
        if ([effect isKindOfClass:[UIVisualEffect class]]) {
            return effect;
        }
    }
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;

    UIView *dim = [[UIView alloc] initWithFrame:self.view.bounds];
    dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    dim.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.35];
    dim.userInteractionEnabled = NO;
    [self.view addSubview:dim];
    self.dimView = dim;

    UIVisualEffectView *panel = [[UIVisualEffectView alloc] initWithEffect:[self glassEffect]];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    panel.layer.cornerRadius = 40.0;
    panel.clipsToBounds = YES;
    panel.contentView.backgroundColor = [UIColor colorWithRed:0.17 green:0.17 blue:0.20 alpha:0.55];
    [self.view addSubview:panel];
    self.panel = panel;

    UILabel *title = [UILabel new];
    title.text = self.menuTitle;
    title.font = [UIFont systemFontOfSize:40.0 weight:UIFontWeightBold];
    title.textColor = UIColor.whiteColor;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[title]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14.0;
    [stack setCustomSpacing:30.0 afterView:title];
    for (BrowserQuickMenuRow *row in self.rows) {
        [stack addArrangedSubview:row];
    }
    [panel.contentView addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [panel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-60.0],
        [panel.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:60.0],
        [panel.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-60.0],
        [panel.widthAnchor constraintEqualToConstant:600.0],
        [stack.topAnchor constraintEqualToAnchor:panel.contentView.topAnchor constant:44.0],
        [stack.leadingAnchor constraintEqualToAnchor:panel.contentView.leadingAnchor constant:40.0],
        [stack.trailingAnchor constraintEqualToAnchor:panel.contentView.trailingAnchor constant:-40.0],
    ]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // In from the right edge, like the Reader panel.
    self.panel.transform = CGAffineTransformMakeTranslation(700.0, 0.0);
    self.dimView.alpha = 0.0;
    [UIView animateWithDuration:0.45 delay:0.0 usingSpringWithDamping:0.86 initialSpringVelocity:0.3 options:0 animations:^{
        self.panel.transform = CGAffineTransformIdentity;
        self.dimView.alpha = 1.0;
    } completion:nil];
}

- (NSArray<id<UIFocusEnvironment>> *)preferredFocusEnvironments {
    return self.rows.count > 0 ? @[self.rows.firstObject] : @[];
}

- (void)closeThen:(void (^)(void))block {
    if (self.closing) {
        return;
    }
    self.closing = YES;
    [UIView animateWithDuration:0.25 animations:^{
        self.panel.transform = CGAffineTransformMakeTranslation(700.0, 0.0);
        self.dimView.alpha = 0.0;
    }];
    [self dismissViewControllerAnimated:YES completion:block];
}

- (void)rowPressed:(BrowserQuickMenuRow *)row {
    [self closeThen:row.action];
}

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    UIPressType type = presses.anyObject.type;
    if (type == UIPressTypeMenu || type == UIPressTypePlayPause) {
        return;
    }
    [super pressesBegan:presses withEvent:event];
}

- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    UIPressType type = presses.anyObject.type;
    if (type == UIPressTypeMenu || type == UIPressTypePlayPause) {
        [self closeThen:nil];
        return;
    }
    [super pressesEnded:presses withEvent:event];
}

@end
