# Changelog

All notable changes to Orbrisa. The format follows [Keep a Changelog](https://keepachangelog.com), versions follow [Semantic Versioning](https://semver.org).

## [1.1.0-beta.2] – 2026-11-06

**Beta 2** – a new start page, web apps and an ad blocker. Please report anything odd – a photo of your TV helps a lot.

### Added
- **Start page** for new tabs and the Home button – the Liquid Glass top bar, your favorites as large tiles and *Recently Visited* with real page pictures
  - Favorites stay in one row and scroll sideways, only *Recently Visited* scrolls up and down
  - Hold a favorite (or press Play/Pause on it) for its options: *Open as Web App*, *Open When Orbrisa Starts*, *Always Open as Web App*, *Rename*, *Remove*
  - Settings → *Home Page*: the Orbrisa start page or a website of your choice
  - An empty tab loads Google behind the start page – Back simply shows it, never a blank page
- **Web apps** – open a favorite like a native app
  - Full screen, no bar, a splash screen with the site's logo
  - Swipe scrolls anywhere; hold the clickpad for a selection box (a soft glass droplet – blue on dark pages, green on light pages); left / right turns pages
  - Hold the bottom of the clickpad: your other web apps slide up on Liquid Glass
  - Own text size per web app; Back goes back inside the app and, on its first page, to the start page; taking the cursor leaves the web app
- **Ad blocker** – WebKit content rules for ad and tracking servers, ad frames are blocked while loading, typical ad boxes are hidden. Switch in Settings → Compatibility and in the quick menu
- **New quick menu** (Play/Pause), designed like the Reader's appearance panel: font size, page appearance (*Original*, *Automatic*, *Light*, *Dark*), action buttons and the ad blocker switch
- **Feeds open in the Reader** – pick an article and it opens in the Reader; Back returns to the feed list
- **Reader:** *Show Web Page* in the appearance panel
- **Usage guide on six pages** with page dots like Apple's – browsing, buttons & menus, tabs & start page, web apps, Reader & feeds, videos. Swipe or press left / right to turn the page
- **What's New** has one page per release: Beta 2, Beta 1 (Reader & RSS) and 1.0 – swipe to see what came before; the version in Settings reads "1.1.0 Beta 2"

### Changed
- Unread counts in the feeds are red badges like on Apple devices
- The feed button opens your feeds directly when you already follow the page (the *Already Subscribed* message only appears when you subscribe again)
- Cookie banners: many more consent tools are recognised (also inside shadow DOM and frames), more button texts, retries for 30 seconds
- Closing a tab switches to the tab on its left; the tab overview keeps the focus on that tab
- Font size: changes no longer stack up, 100 % restores the page exactly
- What's New also appears for a new beta of the same version

### Fixed
- No more *Could Not Load Webpage* alert when a load is cancelled (e.g. when going back quickly)
- Crashes while holding the clickpad and right after closing a screen
- Swiping with link navigation no longer flings the page to the bottom
- Empty tabs no longer show a blank white page

## [1.1.0-beta.1] – 2026-11-05

**Beta 1** – try the new Reader and RSS feeds. Things may still change; please report anything odd.

### Added
- **Reader mode** – only the article, no ads or menus. Calm, large text you scroll with the touch surface
  - *Reader* button right inside the address bar as soon as a page has an article (found while the page is still loading)
  - Appearance panel (Play/Pause): font size in five steps, background *Light*, *Sepia*, *Grey* or *Dark*, font *Serif* or *System*
  - *Always Open in Reader* per website – articles of that site open straight in the Reader
  - Images of the article are shown in the text
- **RSS feeds**
  - RSS button next to the address bar: orange when the page has a feed (subscribe in one click), grey otherwise (opens your feeds)
  - Feeds overview below the top bar, like the tab overview – the address bar reads *Feeds* and the number of new articles
  - Sidebar with all subscribed feeds and unread counts, *All* / *Unread* filter, article cards with picture
  - *Add Feed* finds the feed of the page you are on; Play/Pause on a feed unsubscribes
  - RSS and Atom supported
- New *Reader & Feeds* section in Settings and *Open in Reader* in the quick menu
- What's New shows the beta features; the version in Settings reads "1.1.0 Beta 1"
- `make-ipa.sh` puts the beta label into the file name (`Orbrisa-1.1.0-Beta-1-unsigned.ipa`)

## [1.0.0] – 2026-11-03

First release as **Orbrisa** (formerly tvOSBrowser).

### Added
- New name, app icon (layered for parallax) and Top Shelf image
- Video popup when a video starts: *Fullscreen*, *Choose video…*, *Stay on page*
- Fullscreen plays the page's real stream in the native Apple TV player (from the player's configuration, the video element or captured network requests)
- Stream capture for HLS, MP4 and DASH, with advert filter and stream picker
- Pre-roll advert detection and skipping on the page and in the player
- VLC player (VLCKit) as fallback for formats AVPlayer can't play
- Top Shelf extension with open tabs and favorites (in development, may not show up yet)
- Address bar and text fields open the keyboard directly
- Top bar hides while scrolling down, returns when scrolling up
- Usage guide with Siri Remote illustrations
- `scripts/make-ipa.sh` builds an unsigned IPA with one command
- Credits for Steven Troughton-Smith, Jip van Akker and Claude (Anthropic) in the README
- Ko-fi link to support Orbrisa (Sponsor button, README)
- Screenshots in the README
- English and German: the app follows the Apple TV language (German for German, English for everything else)
- Version number and studio logo in the menu
- Tab strip under the address bar with site logos, a large preview of the focused tab and optional site colours
- Settings redesigned like the tvOS Settings app: centred panel, section titles, Apple-style switches; the address bar reads "Einstellungen" while it is open
- Liquid Glass switch and intensity slider for the whole app
- Appearance for websites: Automatic (follows the Apple TV), Light or Dark
- Font size slider (50–200 %) instead of separate increase / decrease / reset entries
- *What's New* screen after each update, also under Settings → Help

### Changed
- Siri Remote input in the Apple TV player is handled by the system player (fixes play after scrubbing)
- Tab icon with two squares and the tab count

### Removed
- Developer leftovers: WKWebView proof of concept, two disabled fullscreen experiments, Top Shelf test tile
- Diagnostics menu in release builds (still available in Debug builds)
- Console logging in release builds
- YouTube quality selector (YouTube rejects the required client)
