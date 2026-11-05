//
//  BrowserFeedsViewController.h
//  Orbrisa
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// All subscribed feeds: the feeds on the left, their newest articles as cards on the right.
/// Click opens the article, Play/Pause on a feed unsubscribes, Back closes.
@interface BrowserFeedsViewController : UIViewController

/// Called with the article's address after the screen closed.
@property (nonatomic, copy, nullable) void (^openArticle)(NSString *URLString);

@end

NS_ASSUME_NONNULL_END
