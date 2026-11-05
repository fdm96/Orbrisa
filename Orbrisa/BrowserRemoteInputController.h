#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol BrowserRemoteInputControllerHost <NSObject>

- (nullable UIScrollView *)browserRemoteInputControllerActiveScrollView;
- (nullable UIViewController *)browserRemoteInputControllerPresentedViewController;
- (BOOL)browserRemoteInputControllerTopBarFocusActive;
- (BOOL)browserRemoteInputControllerCanActivateTopBarFocus;
- (void)browserRemoteInputControllerActivateTopBarFocus;
- (void)browserRemoteInputControllerDeactivateTopBarFocus;
- (BOOL)browserRemoteInputControllerTabOverviewVisible;
- (BOOL)browserRemoteInputControllerTabOverviewContainsPoint:(CGPoint)point;
- (BOOL)browserRemoteInputControllerHandleTabOverviewSelectionAtPoint:(CGPoint)point;
- (void)browserRemoteInputControllerDismissTabOverview;
- (void)browserRemoteInputControllerHandleTabOverviewAlternateAction;
- (void)browserRemoteInputControllerHandlePrimaryAction;
- (void)browserRemoteInputControllerHandleMenuPress;
- (void)browserRemoteInputControllerHandlePlayPausePress;
- (void)browserRemoteInputControllerHandleAdvancedMenuPress;
- (NSString *)browserRemoteInputControllerHoverStateAtCursorPoint:(CGPoint)point;
- (void)browserRemoteInputControllerSetWebInteractionEnabled:(BOOL)enabled;
- (void)browserRemoteInputControllerPersistSession;
/// Link navigation: jump between the links and buttons of a page with the remote's arrow clicks.
- (void)browserRemoteInputControllerLinkNavigationDidChangeActive:(BOOL)active;
@optional
/// Menu while link navigation is on. Return YES when handled (a web app goes back instead of switching to the mouse).
- (BOOL)browserRemoteInputControllerLinkNavigationHandleMenu;
/// The cursor (mouse) was switched on or off.
- (void)browserRemoteInputControllerCursorModeDidChange:(BOOL)enabled;
@required
/// direction is "up", "down", "left" or "right". Returns "ok", "scrolled", "edge", "top" or "none".
- (NSString *)browserRemoteInputControllerLinkNavigationMove:(NSString *)direction;
- (void)browserRemoteInputControllerLinkNavigationActivate;
/// Up at the top of the page while the bar is hidden: select the red show-bar button. NO if it isn't shown.
- (BOOL)browserRemoteInputControllerLinkNavigationSelectShowBarButton;

@end

@interface BrowserRemoteInputController : NSObject

@property (nonatomic, readonly) UIImageView *cursorView;
@property (nonatomic, readonly) UIPanGestureRecognizer *manualScrollPanRecognizer;
@property (nonatomic, readonly) UITapGestureRecognizer *playPauseDoubleTapRecognizer;
@property (nonatomic, readonly, getter=isCursorModeEnabled) BOOL cursorModeEnabled;
/// Turned on by clicking down twice quickly; the Menu button turns it off again.
@property (nonatomic, readonly, getter=isLinkNavigationActive) BOOL linkNavigationActive;

- (instancetype)initWithHost:(id<BrowserRemoteInputControllerHost>)host
                    rootView:(UIView *)rootView NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

- (void)handleGlobalSelectPressEndedNotification;
- (void)handlePressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event;
- (BOOL)handlePressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event;
- (BOOL)handleTouchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;
- (BOOL)handleTouchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;
- (void)handleTouchesEnded;
- (void)setCursorModeEnabled:(BOOL)cursorModeEnabled;
- (void)setLinkNavigationActive:(BOOL)linkNavigationActive;
/// After a long press of the clickpad was used for something else: the press ending is not a click.
- (void)ignoreSelectPressBriefly;
- (void)refreshInteractionState;

@end

NS_ASSUME_NONNULL_END
