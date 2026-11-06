//
//  BrowserRemoteVisualizer.h
//  Orbrisa
//
//  Orbrisa by Fabio Di Marco (di marcostudio.) with Claude (Anthropic) – next stage reached on 05/11/2026
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Demo mode: a see-through Siri Remote on the right edge of the screen that lights up whatever is pressed or
/// touched – for screen recordings and showing Orbrisa to others. It never takes focus or touches.
@interface BrowserRemoteVisualizer : NSObject

/// Settings → Help → Demo Mode. Turning it on shows the remote right away.
@property (class, nonatomic) BOOL enabled;

/// Called for every event the app receives (presses and clickpad touches); does nothing while demo mode is off.
+ (void)handleEvent:(UIEvent *)event;

@end

NS_ASSUME_NONNULL_END
