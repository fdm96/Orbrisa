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
/// Runs right away when favorites were added, renamed or removed (e.g. to refresh the Top Shelf).
@property (nonatomic, copy, nullable) void (^favoritesChanged)(void);

/// YES when this favorite always opens as a web app (full screen, no bar).
+ (BOOL)isWebAppURL:(nullable NSString *)URLString;
/// The web app Orbrisa opens when it starts, or nil.
+ (nullable NSString *)launchWebAppURL;

@end

NS_ASSUME_NONNULL_END
