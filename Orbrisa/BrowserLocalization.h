//
//  BrowserLocalization.h
//  Orbrisa
//
//  Orbrisa by Fabio Di Marco (di marcostudio.) with Claude (Anthropic) – next stage reached on 05/11/2026
//

#import <Foundation/Foundation.h>

/// Texts in the code are English. German translations live in de.lproj/Localizable.strings;
/// every other system language falls back to English.
#define BrowserLocalized(englishText) NSLocalizedString(englishText, nil)
