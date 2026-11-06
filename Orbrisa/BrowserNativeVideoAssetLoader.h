//
//  BrowserNativeVideoAssetLoader.h
//  Orbrisa
//
//  Orbrisa by Fabio Di Marco (di marco studio) with Claude (Anthropic) – next stage reached on 05/11/2026
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BrowserNativeVideoAssetLoader : NSObject

- (instancetype)initWithRequestHeaders:(nullable NSDictionary<NSString *, NSString *> *)requestHeaders
                               cookies:(nullable NSArray<NSHTTPCookie *> *)cookies NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

- (NSURL *)assetURLForPlaybackURL:(NSURL *)playbackURL;
- (BOOL)attachToAsset:(id)asset;

@end

NS_ASSUME_NONNULL_END
