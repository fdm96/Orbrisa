//
//  ViewController.h
//  Orbrisa
//
//  Created by Steven Troughton-Smith on 20/09/2015.
//  Improved by Jip van Akker on 14/10/2015 through 10/01/2019
//  Orbrisa by Fabio Di Marco (di marcostudio.) with Claude (Anthropic) – next stage reached on 05/11/2026
//

#import <UIKit/UIKit.h>
#import <GameKit/GameKit.h>

#import "BrowserWebView.h"
#import "BrowserTopBarView.h"

@interface ViewController : GCEventViewController <UIScrollViewDelegate, BrowserWebViewDelegate>

@property (nonatomic, retain) IBOutlet BrowserTopBarView *topMenuView;
@property (nonatomic, retain) IBOutlet UIView *browserContainerView;

@end
