//
//  BrowserQuickMenuViewController.h
//  Orbrisa
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// The quick menu (Play/Pause): a Liquid Glass panel on the right, like the Reader's "Appearance" panel.
@interface BrowserQuickMenuViewController : UIViewController

- (instancetype)initWithTitle:(NSString *)title NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

/// Adds a row; the action runs after the menu has closed.
- (void)addItemWithSymbol:(NSString *)symbolName title:(NSString *)title action:(void (^)(void))action;

@end

NS_ASSUME_NONNULL_END
