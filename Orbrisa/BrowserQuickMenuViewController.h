//
//  BrowserQuickMenuViewController.h
//  Orbrisa
//
//  Orbrisa by Fabio Di Marco (di marco studio) with Claude (Anthropic) – next stage reached on 05/11/2026
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// The quick menu (Play/Pause): a Liquid Glass panel on the right, built like the Reader's "Appearance" panel –
/// font size, page appearance, the quick actions and a switch at the bottom.
@interface BrowserQuickMenuViewController : UIViewController

- (instancetype)initWithTitle:(NSString *)title NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

/// FONT SIZE: small A · dots · big A (50–200 % in 25 % steps). Changes apply right away.
- (void)setFontSize:(NSUInteger)size changed:(void (^)(NSUInteger size))changed;
/// APPEARANCE: round "Aa" swatches (Original, Automatic, Light, Dark). Changes apply right away.
- (void)setAppearanceSelected:(NSInteger)selected changed:(void (^)(NSInteger index))changed;
/// ACTIONS: capsule buttons, two per row; the action runs after the menu has closed.
- (void)addItemWithSymbol:(NSString *)symbolName title:(NSString *)title action:(void (^)(void))action;
/// The row with a switch at the bottom.
- (void)setToggleTitle:(NSString *)title value:(BOOL)value changed:(void (^)(BOOL on))changed;

@end

NS_ASSUME_NONNULL_END
