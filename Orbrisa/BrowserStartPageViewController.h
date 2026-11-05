//
//  BrowserStartPageViewController.h
//  Orbrisa
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// The start page (new tab / Home button): the search field at the top, the favorites as tiles and the recently visited sites.
/// Hold Select (or press Play/Pause) on a favorite for its options – among them the web app mode.
@interface BrowserStartPageViewController : UIViewController

- (instancetype)initWithTabCount:(NSUInteger)tabCount canGoBack:(BOOL)canGoBack NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

/// All of these run after the start page has closed.
@property (nonatomic, copy, nullable) void (^openURL)(NSString *URLString, BOOL asWebApp);
@property (nonatomic, copy, nullable) void (^search)(void);
@property (nonatomic, copy, nullable) void (^showTabs)(void);
@property (nonatomic, copy, nullable) void (^showSettings)(void);
@property (nonatomic, copy, nullable) void (^showFeeds)(void);
/// Back on a start page of an empty tab: closes that tab and returns to another one (only when other tabs exist).
@property (nonatomic, copy, nullable) void (^closeEmptyTab)(void);
/// Runs right away when favorites were added, renamed or removed (e.g. to refresh the Top Shelf).
@property (nonatomic, copy, nullable) void (^favoritesChanged)(void);

/// YES when this favorite always opens as a web app (full screen, no bar).
/// Back while the favorite panel is open (or was just closed): closes only the panel. YES when it was used.
- (BOOL)consumeMenuPress;

+ (BOOL)isWebAppURL:(nullable NSString *)URLString;
/// The web app Orbrisa opens when it starts, or nil.
+ (nullable NSString *)launchWebAppURL;
/// The name the user gave this favorite, or nil.
+ (nullable NSString *)nameForFavoriteURL:(nullable NSString *)URLString;
/// The site's logo (remembered from a visit, else its apple-touch-icon); nil when there is none. Completion on the main queue.
+ (void)loadLogoForURL:(NSString *)URLString completion:(void (^)(UIImage * _Nullable image))completion;

@end

/// Inside a web app: hold the bottom of the clickpad – the favorite web apps slide up from the bottom on Liquid Glass.
@interface BrowserWebAppDockViewController : UIViewController
- (instancetype)initWithCurrentURL:(nullable NSString *)currentURL NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
/// Run after the dock has closed.
@property (nonatomic, copy, nullable) void (^openWebApp)(NSString *URLString);
@property (nonatomic, copy, nullable) void (^showStartPage)(void);
@end

NS_ASSUME_NONNULL_END
