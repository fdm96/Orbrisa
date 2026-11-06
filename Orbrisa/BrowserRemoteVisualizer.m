//
//  BrowserRemoteVisualizer.m
//  Orbrisa
//
//  Orbrisa by Fabio Di Marco (di marcostudio.) with Claude (Anthropic) – next stage reached on 05/11/2026
//

#import "BrowserRemoteVisualizer.h"
#import "BrowserLocalization.h"
#import <objc/message.h>

static NSString * const kDemoModeKey = @"BrowserDemoMode";
static CGFloat const kPadSize = 132.0;     // clickpad with its ring
static CGFloat const kSurfaceSize = 74.0;  // the touch surface in the middle

typedef NS_ENUM(NSInteger, BrowserRemotePart) {
    BrowserRemotePartCenter = 0,
    BrowserRemotePartUp,
    BrowserRemotePartDown,
    BrowserRemotePartLeft,
    BrowserRemotePartRight,
    BrowserRemotePartBack,
    BrowserRemotePartPlayPause,
    BrowserRemotePartCount
};

#pragma mark - Remote drawing

@interface BrowserRemoteDrawingView : UIView
@property (nonatomic) NSArray<CAShapeLayer *> *parts;
@property (nonatomic) UIView *touchDot;
@property (nonatomic) UILabel *label;
@end

@implementation BrowserRemoteDrawingView

- (CAShapeLayer *)shapeWithPath:(UIBezierPath *)path {
    CAShapeLayer *shape = [CAShapeLayer layer];
    shape.path = path.CGPath;
    shape.fillColor = [UIColor colorWithWhite:1.0 alpha:0.14].CGColor;
    shape.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.25].CGColor;
    shape.lineWidth = 1.5;
    [self.layer addSublayer:shape];
    return shape;
}

- (UIImageView *)symbol:(NSString *)name center:(CGPoint)center size:(CGFloat)size {
    UIImageView *view = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:name withConfiguration:
        [UIImageSymbolConfiguration configurationWithPointSize:size weight:UIImageSymbolWeightSemibold]]];
    view.tintColor = [UIColor colorWithWhite:1.0 alpha:0.85];
    view.center = center;
    [self addSubview:view];
    return view;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
        CGFloat midX = CGRectGetWidth(frame) / 2.0;

        // Body of the remote
        UIView *body = [[UIView alloc] initWithFrame:CGRectMake(midX - 86.0, 20.0, 172.0, 360.0)];
        body.backgroundColor = [UIColor colorWithWhite:0.75 alpha:0.18];
        body.layer.cornerRadius = 40.0;
        body.layer.borderWidth = 1.5;
        body.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.22].CGColor;
        [self addSubview:body];

        NSMutableArray<CAShapeLayer *> *parts = [NSMutableArray array];
        CGPoint padCenter = CGPointMake(midX, 20.0 + 26.0 + kPadSize / 2.0);
        CGFloat outer = kPadSize / 2.0;
        CGFloat inner = kSurfaceSize / 2.0 + 4.0;

        // Center (touch surface)
        CAShapeLayer *center = [self shapeWithPath:[UIBezierPath bezierPathWithOvalInRect:
            CGRectMake(padCenter.x - kSurfaceSize / 2.0, padCenter.y - kSurfaceSize / 2.0, kSurfaceSize, kSurfaceSize)]];
        // Ring: four quarter segments – up, down, left, right
        CGFloat starts[4] = {-0.75 * M_PI, 0.25 * M_PI, 0.75 * M_PI, -0.25 * M_PI}; // up, down, left, right
        NSMutableArray<CAShapeLayer *> *ring = [NSMutableArray array];
        for (NSInteger i = 0; i < 4; i++) {
            UIBezierPath *segment = [UIBezierPath bezierPath];
            [segment addArcWithCenter:padCenter radius:outer startAngle:starts[i] + 0.04 endAngle:starts[i] + M_PI_2 - 0.04 clockwise:YES];
            [segment addArcWithCenter:padCenter radius:inner startAngle:starts[i] + M_PI_2 - 0.04 endAngle:starts[i] + 0.04 clockwise:NO];
            [segment closePath];
            [ring addObject:[self shapeWithPath:segment]];
        }
        [parts addObject:center];
        [parts addObjectsFromArray:ring];

        // Buttons: Back and TV, then Play/Pause and the volume rocker
        CGFloat rowY = padCenter.y + outer + 46.0;
        CGFloat button = 50.0;
        CAShapeLayer *back = [self shapeWithPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(midX - 40.0 - button / 2.0, rowY - button / 2.0, button, button)]];
        [self shapeWithPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(midX + 40.0 - button / 2.0, rowY - button / 2.0, button, button)]];
        CGFloat row2 = rowY + 66.0;
        CAShapeLayer *play = [self shapeWithPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(midX - 40.0 - button / 2.0, row2 - button / 2.0, button, button)]];
        [self shapeWithPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(midX + 40.0 - button / 2.0, row2 - button / 2.0, button, 116.0) cornerRadius:button / 2.0]];
        [parts addObject:back];
        [parts addObject:play];
        self.parts = parts;

        [self symbol:@"chevron.left" center:CGPointMake(midX - 40.0, rowY) size:20.0];
        [self symbol:@"tv" center:CGPointMake(midX + 40.0, rowY) size:18.0];
        [self symbol:@"playpause.fill" center:CGPointMake(midX - 40.0, row2) size:18.0];
        [self symbol:@"plus" center:CGPointMake(midX + 40.0, row2 + 4.0) size:14.0];
        [self symbol:@"minus" center:CGPointMake(midX + 40.0, row2 + 58.0) size:14.0];

        // The finger on the touch surface
        UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 26.0, 26.0)];
        dot.backgroundColor = [UIColor colorWithRed:0.25 green:0.6 blue:1.0 alpha:0.95];
        dot.layer.cornerRadius = 13.0;
        dot.layer.borderWidth = 2.0;
        dot.layer.borderColor = UIColor.whiteColor.CGColor;
        dot.center = padCenter;
        dot.alpha = 0.0;
        [self addSubview:dot];
        self.touchDot = dot;

        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0.0, 392.0, CGRectGetWidth(frame), 64.0)];
        label.font = [UIFont systemFontOfSize:24.0 weight:UIFontWeightSemibold];
        label.textColor = UIColor.whiteColor;
        label.textAlignment = NSTextAlignmentCenter;
        label.numberOfLines = 2;
        label.adjustsFontSizeToFitWidth = YES;
        label.minimumScaleFactor = 0.7;
        [self addSubview:label];
        self.label = label;
    }
    return self;
}

- (CGPoint)padCenter {
    return CGPointMake(CGRectGetWidth(self.bounds) / 2.0, 20.0 + 26.0 + kPadSize / 2.0);
}

- (void)setPart:(BrowserRemotePart)part lit:(BOOL)lit {
    if (part < 0 || part >= (NSInteger)self.parts.count) {
        return;
    }
    CAShapeLayer *shape = self.parts[(NSUInteger)part];
    [CATransaction begin];
    [CATransaction setAnimationDuration:lit ? 0.05 : 0.35];
    shape.fillColor = (lit ? [UIColor colorWithRed:0.25 green:0.6 blue:1.0 alpha:0.9] : [UIColor colorWithWhite:1.0 alpha:0.14]).CGColor;
    shape.strokeColor = (lit ? UIColor.whiteColor : [UIColor colorWithWhite:1.0 alpha:0.25]).CGColor;
    [CATransaction commit];
}

@end

#pragma mark - Visualizer

@interface BrowserRemoteVisualizer ()
@property (nonatomic) UIWindow *window;
@property (nonatomic) UIVisualEffectView *panel;
@property (nonatomic) BrowserRemoteDrawingView *remote;
@property (nonatomic) NSMutableDictionary<NSNumber *, NSNumber *> *pressStart; // press type → time it went down
@property (nonatomic) NSMutableSet<NSNumber *> *heldShown;
@property (nonatomic) CFTimeInterval lastSelectEnd;
@property (nonatomic) CGPoint touchStart;
@property (nonatomic) BOOL swipeShown;
@property (nonatomic) NSUInteger activity;
@end

@implementation BrowserRemoteVisualizer

+ (instancetype)shared {
    static BrowserRemoteVisualizer *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [BrowserRemoteVisualizer new];
        shared.pressStart = [NSMutableDictionary dictionary];
        shared.heldShown = [NSMutableSet set];
    });
    return shared;
}

+ (BOOL)enabled {
    return [NSUserDefaults.standardUserDefaults boolForKey:kDemoModeKey];
}

+ (void)setEnabled:(BOOL)enabled {
    [NSUserDefaults.standardUserDefaults setBool:enabled forKey:kDemoModeKey];
    BrowserRemoteVisualizer *visualizer = [self shared];
    if (enabled) {
        [visualizer show];
        [visualizer showLabel:BrowserLocalized(@"Demo Mode")];
    } else {
        [visualizer hide];
    }
}

#pragma mark Window

- (UIWindowScene *)scene {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState != UISceneActivationStateBackground) {
            return (UIWindowScene *)scene;
        }
    }
    return nil;
}

- (void)show {
    if (self.window != nil) {
        self.window.hidden = NO;
        return;
    }
    UIWindowScene *scene = [self scene];
    if (scene == nil) {
        return;
    }
    // Its own window above everything (menus, players, alerts), never key, never focusable, never touched.
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:scene];
    window.windowLevel = UIWindowLevelAlert + 10.0;
    window.userInteractionEnabled = NO;
    window.backgroundColor = UIColor.clearColor;
    window.frame = scene.coordinateSpace.bounds;

    CGSize size = CGSizeMake(232.0, 476.0);
    CGRect bounds = window.bounds;
    UIVisualEffectView *panel = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    panel.frame = CGRectMake(CGRectGetWidth(bounds) - size.width - 50.0, (CGRectGetHeight(bounds) - size.height) / 2.0, size.width, size.height);
    panel.layer.cornerRadius = 44.0;
    panel.clipsToBounds = YES;
    panel.alpha = 0.0;
    panel.contentView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.15];
    BrowserRemoteDrawingView *remote = [[BrowserRemoteDrawingView alloc] initWithFrame:panel.contentView.bounds];
    [panel.contentView addSubview:remote];
    [window addSubview:panel];
    window.hidden = NO;

    self.window = window;
    self.panel = panel;
    self.remote = remote;
    [self wake];
}

- (void)hide {
    UIWindow *window = self.window;
    [UIView animateWithDuration:0.25 animations:^{
        self.panel.alpha = 0.0;
    } completion:^(__unused BOOL finished) {
        window.hidden = YES;
    }];
    self.window = nil;
    self.panel = nil;
    self.remote = nil;
}

/// Fully visible while something happens, then fades to a faint outline so it doesn't get in the way.
- (void)wake {
    NSUInteger activity = ++self.activity;
    [UIView animateWithDuration:0.15 animations:^{ self.panel.alpha = 0.92; }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (activity != self.activity) {
            return;
        }
        [UIView animateWithDuration:0.8 animations:^{ self.panel.alpha = 0.35; }];
        self.remote.label.text = nil;
    });
}

- (void)showLabel:(NSString *)text {
    self.remote.label.text = text;
    [self wake];
}

#pragma mark Events

+ (void)handleEvent:(UIEvent *)event {
    if (![self enabled]) {
        return;
    }
    BrowserRemoteVisualizer *visualizer = [self shared];
    if (visualizer.window == nil) {
        [visualizer show];
    }
    if (event.type == UIEventTypePresses) {
        SEL allPresses = NSSelectorFromString(@"allPresses");
        if ([event respondsToSelector:allPresses]) {
            NSSet<UIPress *> *presses = ((id (*)(id, SEL))objc_msgSend)(event, allPresses);
            for (UIPress *press in presses) {
                [visualizer handlePress:press];
            }
        }
    } else if (event.type == UIEventTypeTouches) {
        for (UITouch *touch in event.allTouches) {
            if (touch.type == UITouchTypeIndirect) {
                [visualizer handleTouch:touch];
            }
        }
    }
}

- (BrowserRemotePart)partForPress:(UIPressType)type {
    switch (type) {
        case UIPressTypeSelect: return BrowserRemotePartCenter;
        case UIPressTypeUpArrow: return BrowserRemotePartUp;
        case UIPressTypeDownArrow: return BrowserRemotePartDown;
        case UIPressTypeLeftArrow: return BrowserRemotePartLeft;
        case UIPressTypeRightArrow: return BrowserRemotePartRight;
        case UIPressTypeMenu: return BrowserRemotePartBack;
        case UIPressTypePlayPause: return BrowserRemotePartPlayPause;
        default: return BrowserRemotePartCount;
    }
}

- (NSString *)nameForPress:(UIPressType)type {
    switch (type) {
        case UIPressTypeSelect: return BrowserLocalized(@"Center");
        case UIPressTypeUpArrow: return BrowserLocalized(@"Ring Up");
        case UIPressTypeDownArrow: return BrowserLocalized(@"Ring Down");
        case UIPressTypeLeftArrow: return BrowserLocalized(@"Ring Left");
        case UIPressTypeRightArrow: return BrowserLocalized(@"Ring Right");
        case UIPressTypeMenu: return BrowserLocalized(@"Back");
        case UIPressTypePlayPause: return @"Play/Pause";
        default: return nil;
    }
}

- (void)handlePress:(UIPress *)press {
    BrowserRemotePart part = [self partForPress:press.type];
    NSString *name = [self nameForPress:press.type];
    if (part == BrowserRemotePartCount || name == nil) {
        return;
    }
    NSNumber *key = @(press.type);
    if (press.phase == UIPressPhaseBegan) {
        self.pressStart[key] = @(CACurrentMediaTime());
        [self.heldShown removeObject:key];
        [self.remote setPart:part lit:YES];
        [self showLabel:name];
        CFTimeInterval started = CACurrentMediaTime();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSNumber *down = self.pressStart[key];
            if (down != nil && down.doubleValue == started) {
                [self.heldShown addObject:key];
                [self showLabel:[NSString stringWithFormat:BrowserLocalized(@"Hold %@"), name]];
            }
        });
    } else if (press.phase == UIPressPhaseEnded || press.phase == UIPressPhaseCancelled) {
        [self.pressStart removeObjectForKey:key];
        [self.remote setPart:part lit:NO];
        if (press.type == UIPressTypeSelect && ![self.heldShown containsObject:key]) {
            CFTimeInterval now = CACurrentMediaTime();
            if (now - self.lastSelectEnd < 0.45) {
                [self showLabel:[NSString stringWithFormat:BrowserLocalized(@"2× %@"), name]];
                self.lastSelectEnd = 0;
            } else {
                self.lastSelectEnd = now;
            }
        }
        [self wake];
    }
}

- (void)handleTouch:(UITouch *)touch {
    CGPoint location = [touch locationInView:nil];
    UIView *dot = self.remote.touchDot;
    CGPoint center = [self.remote padCenter];
    if (touch.phase == UITouchPhaseBegan) {
        self.touchStart = location;
        self.swipeShown = NO;
        dot.center = center;
        [UIView animateWithDuration:0.1 animations:^{ dot.alpha = 1.0; }];
        [self wake];
        return;
    }
    if (touch.phase == UITouchPhaseMoved) {
        CGFloat dx = location.x - self.touchStart.x;
        CGFloat dy = location.y - self.touchStart.y;
        // The finger moves on the drawn touch surface (scaled down, kept inside it).
        CGFloat scale = 0.05;
        CGPoint offset = CGPointMake(dx * scale, dy * scale);
        CGFloat limit = kSurfaceSize / 2.0 - 13.0;
        CGFloat length = hypot(offset.x, offset.y);
        if (length > limit) {
            offset = CGPointMake(offset.x / length * limit, offset.y / length * limit);
        }
        dot.center = CGPointMake(center.x + offset.x, center.y + offset.y);
        if (hypot(dx, dy) > 120.0) {
            NSString *direction = fabs(dx) > fabs(dy) ? (dx > 0 ? @"→" : @"←") : (dy > 0 ? @"↓" : @"↑");
            NSString *text = [NSString stringWithFormat:BrowserLocalized(@"Swipe %@"), direction];
            if (!self.swipeShown || ![self.remote.label.text isEqualToString:text]) {
                self.swipeShown = YES;
                [self showLabel:text];
            } else {
                [self wake];
            }
        }
        return;
    }
    if (touch.phase == UITouchPhaseEnded || touch.phase == UITouchPhaseCancelled) {
        [UIView animateWithDuration:0.3 animations:^{
            dot.alpha = 0.0;
            dot.center = center;
        }];
    }
}

@end
