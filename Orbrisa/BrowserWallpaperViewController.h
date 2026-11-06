//
//  BrowserWallpaperViewController.h
//  Orbrisa
//
//  Orbrisa by Fabio Di Marco (di marcostudio.) with Claude (Anthropic) – next stage reached on 05/11/2026
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// The wallpaper picker for the start page: a glass window with photos from Unsplash (via Lorem Picsum, no account
/// needed). The chosen photo is saved on the Apple TV and shown blurred behind the start page.
@interface BrowserWallpaperViewController : UIViewController

/// Runs after a wallpaper was chosen or removed (the window has closed).
@property (nonatomic, copy, nullable) void (^wallpaperChanged)(void);

/// The saved wallpaper, or nil.
+ (nullable UIImage *)currentWallpaper;
/// The wallpaper – from the cache, or downloaded again when tvOS has emptied the cache. nil: no wallpaper chosen.
+ (void)loadWallpaperWithCompletion:(void (^)(UIImage * _Nullable image))completion;

@end

NS_ASSUME_NONNULL_END
