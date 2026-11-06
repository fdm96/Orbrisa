//
//  BrowserQuickMenuViewController.m
//  Orbrisa
//
//  Orbrisa by Fabio Di Marco (di marco studio) with Claude (Anthropic) – next stage reached on 05/11/2026
//

#import "BrowserQuickMenuViewController.h"
#import "BrowserLocalization.h"

static NSUInteger const kQuickSizes[] = {50, 75, 100, 125, 150, 175, 200};
static NSInteger const kQuickSizeCount = 7;

static UIColor *QuickDark(void) { return [UIColor colorWithWhite:0.11 alpha:1.0]; }

#pragma mark - Focusable control

/// Every control of the panel: the look is set by a block, so one class serves buttons, swatches and the switch row.
@interface BrowserQuickControl : UIButton
@property (nonatomic, copy) void (^style)(BrowserQuickControl *control, BOOL focused);
@property (nonatomic, copy) void (^action)(void);
@property (nonatomic) BOOL closesMenu;
@end

@implementation BrowserQuickControl

- (void)restyle {
    if (self.style != nil) {
        self.style(self, self.isFocused);
    }
}

- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator {
    [super didUpdateFocusInContext:context withAnimationCoordinator:coordinator];
    BOOL focused = (context.nextFocusedView == self);
    [coordinator addCoordinatedAnimations:^{
        if (self.style != nil) {
            self.style(self, focused);
        }
    } completion:nil];
}

@end

#pragma mark - Menu

@interface BrowserQuickMenuViewController ()
@property (nonatomic, copy) NSString *menuTitle;
@property (nonatomic) BOOL hasFontSize;
@property (nonatomic) NSInteger sizeIndex;
@property (nonatomic, copy) void (^sizeChanged)(NSUInteger size);
@property (nonatomic) BOOL hasAppearance;
@property (nonatomic) NSInteger appearance;
@property (nonatomic, copy) void (^appearanceChanged)(NSInteger index);
@property (nonatomic) NSMutableArray<NSArray *> *items; // [symbol, title, action]
@property (nonatomic, copy) NSString *toggleTitle;
@property (nonatomic) BOOL toggleValue;
@property (nonatomic, copy) void (^toggleChanged)(BOOL on);

@property (nonatomic) UIVisualEffectView *panel;
@property (nonatomic) UIView *dimView;
@property (nonatomic) NSArray<UIView *> *dots;
@property (nonatomic) NSArray<BrowserQuickControl *> *swatches;
@property (nonatomic) NSMutableArray<BrowserQuickControl *> *allControls;
@property (nonatomic, weak) UIView *firstFocus;
@property (nonatomic) BOOL closing;
@end

@implementation BrowserQuickMenuViewController

- (instancetype)initWithTitle:(NSString *)title {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _menuTitle = [title copy];
        _items = [NSMutableArray array];
        _allControls = [NSMutableArray array];
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    }
    return self;
}

- (void)setFontSize:(NSUInteger)size changed:(void (^)(NSUInteger))changed {
    self.hasFontSize = YES;
    NSInteger best = 0;
    for (NSInteger i = 0; i < kQuickSizeCount; i++) {
        if (labs((long)kQuickSizes[i] - (long)size) < labs((long)kQuickSizes[best] - (long)size)) {
            best = i;
        }
    }
    self.sizeIndex = best;
    self.sizeChanged = changed;
}

- (void)setAppearanceSelected:(NSInteger)selected changed:(void (^)(NSInteger))changed {
    self.hasAppearance = YES;
    self.appearance = selected;
    self.appearanceChanged = changed;
}

- (void)addItemWithSymbol:(NSString *)symbolName title:(NSString *)title action:(void (^)(void))action {
    void (^block)(void) = action ?: ^{};
    [self.items addObject:@[symbolName ?: @"circle", title ?: @"", [block copy]]];
}

- (void)setToggleTitle:(NSString *)title value:(BOOL)value changed:(void (^)(BOOL))changed {
    self.toggleTitle = title;
    self.toggleValue = value;
    self.toggleChanged = changed;
}

#pragma mark Building

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

- (UILabel *)sectionLabel:(NSString *)text {
    UILabel *label = [UILabel new];
    label.text = text.uppercaseString;
    label.font = [UIFont systemFontOfSize:20.0 weight:UIFontWeightSemibold];
    label.textColor = [UIColor colorWithWhite:1.0 alpha:0.55];
    return label;
}

- (BrowserQuickControl *)controlWithWidth:(CGFloat)width height:(CGFloat)height radius:(CGFloat)radius {
    BrowserQuickControl *control = [BrowserQuickControl buttonWithType:UIButtonTypeCustom];
    control.translatesAutoresizingMaskIntoConstraints = NO;
    control.layer.cornerRadius = radius;
    control.layer.shadowColor = UIColor.blackColor.CGColor;
    control.layer.shadowOffset = CGSizeMake(0.0, 8.0);
    control.layer.shadowRadius = 14.0;
    if (width > 0.0) {
        [control.widthAnchor constraintEqualToConstant:width].active = YES;
    }
    [control.heightAnchor constraintEqualToConstant:height].active = YES;
    [control addTarget:self action:@selector(controlPressed:) forControlEvents:UIControlEventPrimaryActionTriggered];
    [self.allControls addObject:control];
    return control;
}

/// White when focused, soft glass otherwise – the Reader panel's look.
- (void (^)(BrowserQuickControl *, BOOL))capsuleStyle {
    return ^(BrowserQuickControl *control, BOOL focused) {
        control.backgroundColor = focused ? UIColor.whiteColor : [UIColor colorWithWhite:1.0 alpha:0.12];
        UIColor *content = focused ? QuickDark() : UIColor.whiteColor;
        [control setTitleColor:content forState:UIControlStateNormal];
        control.tintColor = content;
        control.transform = focused ? CGAffineTransformMakeScale(1.05, 1.05) : CGAffineTransformIdentity;
        control.layer.shadowOpacity = focused ? 0.4 : 0.0;
    };
}

- (UIView *)fontSizeRow {
    __weak typeof(self) weakSelf = self;
    BrowserQuickControl *smaller = [self controlWithWidth:76.0 height:76.0 radius:22.0];
    [smaller setTitle:@"A" forState:UIControlStateNormal];
    smaller.titleLabel.font = [UIFont systemFontOfSize:24.0 weight:UIFontWeightSemibold];
    smaller.accessibilityLabel = BrowserLocalized(@"Smaller");
    smaller.style = [self capsuleStyle];
    smaller.action = ^{ [weakSelf stepSize:-1]; };
    BrowserQuickControl *bigger = [self controlWithWidth:76.0 height:76.0 radius:22.0];
    [bigger setTitle:@"A" forState:UIControlStateNormal];
    bigger.titleLabel.font = [UIFont systemFontOfSize:38.0 weight:UIFontWeightSemibold];
    bigger.accessibilityLabel = BrowserLocalized(@"Bigger");
    bigger.style = [self capsuleStyle];
    bigger.action = ^{ [weakSelf stepSize:1]; };

    NSMutableArray *dots = [NSMutableArray array];
    for (NSInteger i = 0; i < kQuickSizeCount; i++) {
        UIView *dot = [UIView new];
        dot.translatesAutoresizingMaskIntoConstraints = NO;
        CGFloat side = 12.0 + i * 2.5;
        dot.layer.cornerRadius = side / 2.0;
        [dot.widthAnchor constraintEqualToConstant:side].active = YES;
        [dot.heightAnchor constraintEqualToConstant:side].active = YES;
        [dots addObject:dot];
    }
    self.dots = dots;
    UIStackView *dotRow = [[UIStackView alloc] initWithArrangedSubviews:dots];
    dotRow.alignment = UIStackViewAlignmentCenter;
    dotRow.distribution = UIStackViewDistributionEqualSpacing;
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[smaller, dotRow, bigger]];
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 24.0;
    [self refreshDots];
    return row;
}

- (UIView *)appearanceRow {
    NSArray *names = @[BrowserLocalized(@"Original"), BrowserLocalized(@"Automatic"), BrowserLocalized(@"Light"), BrowserLocalized(@"Dark")];
    NSArray *backgrounds = @[[UIColor colorWithRed:0.42 green:0.44 blue:0.50 alpha:1.0], [UIColor colorWithWhite:0.55 alpha:1.0],
                             UIColor.whiteColor, [UIColor colorWithRed:0.11 green:0.11 blue:0.12 alpha:1.0]];
    NSArray *texts = @[UIColor.whiteColor, UIColor.whiteColor, QuickDark(), UIColor.whiteColor];
    UIFontDescriptor *serif = [[UIFont systemFontOfSize:32.0 weight:UIFontWeightSemibold].fontDescriptor fontDescriptorWithDesign:UIFontDescriptorSystemDesignSerif];
    UIFont *font = serif != nil ? [UIFont fontWithDescriptor:serif size:32.0] : [UIFont systemFontOfSize:32.0 weight:UIFontWeightSemibold];

    NSMutableArray *swatches = [NSMutableArray array];
    NSMutableArray *columns = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;
    for (NSInteger i = 0; i < 4; i++) {
        BrowserQuickControl *swatch = [self controlWithWidth:92.0 height:92.0 radius:46.0];
        swatch.backgroundColor = backgrounds[i];
        [swatch setTitle:(i == 1 ? @"A" : @"Aa") forState:UIControlStateNormal];
        if (i == 1) {
            [swatch setImage:[UIImage systemImageNamed:@"circle.lefthalf.filled" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:30.0 weight:UIImageSymbolWeightSemibold]] forState:UIControlStateNormal];
            [swatch setTitle:nil forState:UIControlStateNormal];
            swatch.tintColor = UIColor.whiteColor;
        }
        [swatch setTitleColor:texts[i] forState:UIControlStateNormal];
        swatch.titleLabel.font = font;
        swatch.accessibilityLabel = names[i];
        NSInteger index = i;
        swatch.style = ^(BrowserQuickControl *control, BOOL focused) {
            BOOL chosen = (weakSelf.appearance == index);
            control.layer.borderWidth = chosen ? 5.0 : 2.0;
            control.layer.borderColor = (chosen ? UIColor.systemBlueColor : [UIColor colorWithWhite:1.0 alpha:0.2]).CGColor;
            control.transform = focused ? CGAffineTransformMakeScale(1.12, 1.12) : CGAffineTransformIdentity;
            control.layer.shadowOpacity = focused ? 0.5 : 0.0;
        };
        swatch.action = ^{
            weakSelf.appearance = index;
            for (BrowserQuickControl *other in weakSelf.swatches) {
                [other restyle];
            }
            if (weakSelf.appearanceChanged != nil) {
                weakSelf.appearanceChanged(index);
            }
        };
        [swatches addObject:swatch];
        UILabel *name = [UILabel new];
        name.text = names[i];
        name.font = [UIFont systemFontOfSize:18.0 weight:UIFontWeightMedium];
        name.textColor = UIColor.whiteColor;
        UIStackView *column = [[UIStackView alloc] initWithArrangedSubviews:@[swatch, name]];
        column.axis = UILayoutConstraintAxisVertical;
        column.alignment = UIStackViewAlignmentCenter;
        column.spacing = 10.0;
        [columns addObject:column];
    }
    self.swatches = swatches;
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:columns];
    row.distribution = UIStackViewDistributionEqualSpacing;
    return row;
}

- (UIView *)actionGrid {
    UIStackView *grid = [UIStackView new];
    grid.axis = UILayoutConstraintAxisVertical;
    grid.spacing = 12.0;
    UIStackView *line = nil;
    for (NSArray *item in self.items) {
        BrowserQuickControl *button = [self controlWithWidth:0.0 height:70.0 radius:35.0];
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:22.0 weight:UIImageSymbolWeightSemibold];
        [button setImage:[UIImage systemImageNamed:item[0] withConfiguration:config] forState:UIControlStateNormal];
        [button setTitle:[@"  " stringByAppendingString:item[1]] forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:22.0 weight:UIFontWeightSemibold];
        button.titleLabel.adjustsFontSizeToFitWidth = YES;
        button.titleLabel.minimumScaleFactor = 0.7;
        button.style = [self capsuleStyle];
        button.action = item[2];
        button.closesMenu = YES;
        if (line == nil || line.arrangedSubviews.count == 2) {
            line = [UIStackView new];
            line.distribution = UIStackViewDistributionFillEqually;
            line.spacing = 12.0;
            [grid addArrangedSubview:line];
        }
        [line addArrangedSubview:button];
    }
    if (line.arrangedSubviews.count == 1) {
        [line addArrangedSubview:[UIView new]]; // keep the last button half wide
    }
    return grid;
}

- (UIView *)toggleRow {
    __weak typeof(self) weakSelf = self;
    BrowserQuickControl *row = [self controlWithWidth:0.0 height:80.0 radius:40.0];
    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = self.toggleTitle;
    label.font = [UIFont systemFontOfSize:23.0 weight:UIFontWeightMedium];
    UIView *track = [UIView new];
    track.translatesAutoresizingMaskIntoConstraints = NO;
    track.layer.cornerRadius = 23.0;
    track.userInteractionEnabled = NO;
    UIView *knob = [[UIView alloc] initWithFrame:CGRectMake(4.0, 4.0, 38.0, 38.0)];
    knob.backgroundColor = UIColor.whiteColor;
    knob.layer.cornerRadius = 19.0;
    [track addSubview:knob];
    [row addSubview:label];
    [row addSubview:track];
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:26.0],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [track.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-20.0],
        [track.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [track.widthAnchor constraintEqualToConstant:84.0],
        [track.heightAnchor constraintEqualToConstant:46.0],
    ]];
    row.style = ^(BrowserQuickControl *control, BOOL focused) {
        BOOL on = weakSelf.toggleValue;
        control.backgroundColor = focused ? UIColor.whiteColor : [UIColor colorWithWhite:1.0 alpha:0.10];
        control.transform = focused ? CGAffineTransformMakeScale(1.04, 1.04) : CGAffineTransformIdentity;
        control.layer.shadowOpacity = focused ? 0.4 : 0.0;
        label.textColor = focused ? QuickDark() : UIColor.whiteColor;
        track.backgroundColor = on ? UIColor.systemBlueColor : (focused ? [UIColor colorWithWhite:0.0 alpha:0.16] : [UIColor colorWithWhite:0.47 alpha:0.5]);
        knob.frame = CGRectMake(on ? 42.0 : 4.0, 4.0, 38.0, 38.0);
    };
    __weak BrowserQuickControl *weakRow = row;
    row.action = ^{
        weakSelf.toggleValue = !weakSelf.toggleValue;
        [UIView animateWithDuration:0.2 animations:^{ [weakRow restyle]; }];
        if (weakSelf.toggleChanged != nil) {
            weakSelf.toggleChanged(weakSelf.toggleValue);
        }
    };
    return row;
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
    panel.contentView.backgroundColor = [UIColor colorWithRed:0.17 green:0.17 blue:0.20 alpha:0.6];
    [self.view addSubview:panel];
    self.panel = panel;

    UILabel *title = [UILabel new];
    title.text = self.menuTitle;
    title.font = [UIFont systemFontOfSize:40.0 weight:UIFontWeightBold];
    title.textColor = UIColor.whiteColor;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[title]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16.0;
    [stack setCustomSpacing:30.0 afterView:title];
    UIView *last = title;
    if (self.hasFontSize) {
        [stack addArrangedSubview:[self sectionLabel:BrowserLocalized(@"Font Size")]];
        UIView *row = [self fontSizeRow];
        [stack addArrangedSubview:row];
        [stack setCustomSpacing:30.0 afterView:row];
        last = row;
    }
    if (self.hasAppearance) {
        [stack addArrangedSubview:[self sectionLabel:BrowserLocalized(@"Appearance")]];
        UIView *row = [self appearanceRow];
        [stack addArrangedSubview:row];
        [stack setCustomSpacing:30.0 afterView:row];
        last = row;
    }
    if (self.items.count > 0) {
        [stack addArrangedSubview:[self sectionLabel:BrowserLocalized(@"Actions")]];
        UIView *grid = [self actionGrid];
        [stack addArrangedSubview:grid];
        last = grid;
    }
    (void)last;
    [panel.contentView addSubview:stack];

    NSMutableArray *constraints = [@[
        [panel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-60.0],
        [panel.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:60.0],
        [panel.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-60.0],
        [panel.widthAnchor constraintEqualToConstant:600.0],
        [stack.topAnchor constraintEqualToAnchor:panel.contentView.topAnchor constant:44.0],
        [stack.leadingAnchor constraintEqualToAnchor:panel.contentView.leadingAnchor constant:40.0],
        [stack.trailingAnchor constraintEqualToAnchor:panel.contentView.trailingAnchor constant:-40.0],
    ] mutableCopy];
    if (self.toggleTitle.length > 0) {
        UIView *toggle = [self toggleRow];
        [panel.contentView addSubview:toggle];
        [constraints addObjectsFromArray:@[
            [toggle.leadingAnchor constraintEqualToAnchor:panel.contentView.leadingAnchor constant:40.0],
            [toggle.trailingAnchor constraintEqualToAnchor:panel.contentView.trailingAnchor constant:-40.0],
            [toggle.bottomAnchor constraintEqualToAnchor:panel.contentView.bottomAnchor constant:-40.0],
        ]];
    }
    [NSLayoutConstraint activateConstraints:constraints];
    for (BrowserQuickControl *control in self.allControls) {
        [control restyle];
    }
    self.firstFocus = self.allControls.firstObject;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.panel.transform = CGAffineTransformMakeTranslation(700.0, 0.0);
    self.dimView.alpha = 0.0;
    [UIView animateWithDuration:0.45 delay:0.0 usingSpringWithDamping:0.86 initialSpringVelocity:0.3 options:0 animations:^{
        self.panel.transform = CGAffineTransformIdentity;
        self.dimView.alpha = 1.0;
    } completion:nil];
}

- (NSArray<id<UIFocusEnvironment>> *)preferredFocusEnvironments {
    return self.firstFocus != nil ? @[self.firstFocus] : @[];
}

#pragma mark Actions

- (void)refreshDots {
    for (NSInteger i = 0; i < (NSInteger)self.dots.count; i++) {
        self.dots[(NSUInteger)i].backgroundColor = i <= self.sizeIndex ? UIColor.systemBlueColor : [UIColor colorWithWhite:1.0 alpha:0.22];
    }
}

- (void)stepSize:(NSInteger)delta {
    NSInteger next = MIN(MAX(self.sizeIndex + delta, 0), kQuickSizeCount - 1);
    if (next == self.sizeIndex) {
        return;
    }
    self.sizeIndex = next;
    [UIView animateWithDuration:0.15 animations:^{ [self refreshDots]; }];
    if (self.sizeChanged != nil) {
        self.sizeChanged(kQuickSizes[next]);
    }
}

- (void)controlPressed:(BrowserQuickControl *)control {
    if (control.closesMenu) {
        [self closeThen:control.action];
    } else if (control.action != nil) {
        control.action();
    }
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
