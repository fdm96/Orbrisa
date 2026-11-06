//
//  BrowserLog.h
//  Orbrisa
//
//  Orbrisa by Fabio Di Marco (di marco studio) with Claude (Anthropic) – next stage reached on 05/11/2026
//

#import <Foundation/Foundation.h>

/// Console logging for development. Debug builds print to the Xcode console;
/// Release builds stay silent (the arguments are still type-checked, so nothing goes stale).
#if DEBUG
#define BrowserLog(...) NSLog(__VA_ARGS__)
#else
#define BrowserLog(...) do { if (0) { NSLog(__VA_ARGS__); } } while (0)
#endif
