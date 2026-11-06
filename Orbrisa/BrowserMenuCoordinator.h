//
//  BrowserMenuCoordinator.h
//  Orbrisa
//
//  Orbrisa by Fabio Di Marco (di marcostudio.) with Claude (Anthropic) – next stage reached on 05/11/2026
//

#import <UIKit/UIKit.h>
#import "BrowserWebView.h"

@class BrowserPreferencesStore;

@protocol BrowserMenuCoordinatorHost <NSObject>

@property (nonatomic, readonly) BrowserWebView *browserWebView;
@property (nonatomic, copy) NSString *browserPreviousURL;
@property (nonatomic) NSUInteger browserTextFontSize;
@property (nonatomic) BOOL browserFullscreenVideoPlaybackEnabled;
@property (nonatomic, readonly) BOOL browserTopMenuShowing;

- (void)browserPresentViewController:(UIViewController *)viewController;
- (void)browserLoadHomePage;
- (void)browserShowHints;
- (void)browserShowWhatsNew;
- (void)browserShowReader;
- (void)browserShowFeeds;
- (void)browserSubscribeToPageFeed;
- (void)browserSetSettingsTitleShown:(BOOL)shown;
- (void)browserShowTabOverview;
- (void)browserCreateNewTabLoadingHomePage:(BOOL)loadHomePage;
- (void)browserHideTopNav;
- (void)browserShowTopNav;
- (void)browserUpdateTextFontSize;
- (void)browserCaptureSnapshotForCurrentTab;
- (void)browserRecreateActiveWebViewPreservingCurrentURL;
- (void)browserBringCursorToFront;

@end

@interface BrowserMenuCoordinator : NSObject

- (instancetype)initWithHost:(id<BrowserMenuCoordinatorHost>)host
            preferencesStore:(BrowserPreferencesStore *)preferencesStore;
- (void)showAdvancedMenu;
/// The font size slider from Settings (50–200 %), for one value of its own – e.g. a web app's text size.
- (void)presentTextSizeSliderWithValue:(NSUInteger)value changed:(void (^)(NSUInteger size))changed;

@end
