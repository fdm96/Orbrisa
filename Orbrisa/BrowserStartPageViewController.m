//
//  BrowserStartPageViewController.m
//  Orbrisa
//

#import "BrowserStartPageViewController.h"
#import "BrowserFeedStore.h"
#import "BrowserLocalization.h"
#import "BrowserTopBarView.h"

static NSString * const kStartFavoritesKey = @"FAVORITES";
static NSString * const kStartHistoryKey = @"HISTORY";
static NSString * const kStartWebAppsKey = @"BrowserWebAppURLs";
static NSString * const kStartLaunchWebAppKey = @"BrowserLaunchWebAppURL";

static CGFloat const kStartSideInset = 160.0;
static CGFloat const kStartFavoriteTile = 180.0;

static UIColor *StartBackgroundColor(void) { return [UIColor colorWithRed:0.067 green:0.071 blue:0.086 alpha:1.0]; }

static NSString *StartHostForURL(NSString *URLString) {
    NSString *host = [NSURL URLWithString:URLString].host.lowercaseString ?: @"";
    if ([host hasPrefix:@"www."]) {
        host = [host substringFromIndex:4];
    }
    return host;
}

static NSString *StartLetterForName(NSString *name, NSString *URLString) {
    NSString *source = name.length > 0 ? name : StartHostForURL(URLString);
    NSString *trimmed = [source stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length == 0) {
        return @"•";
    }
    return [[trimmed substringToIndex:[trimmed rangeOfComposedCharacterSequenceAtIndex:0].length] uppercaseString];
}

static NSCache<NSString *, UIImage *> *StartLogoCache(void) {
    static NSCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [NSCache new];
        cache.countLimit = 120;
    });
    return cache;
}

static void StartFetchFirstImage(NSArray<NSString *> *candidates, NSUInteger index, void (^completion)(UIImage *image)) {
    if (index >= candidates.count) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); });
        return;
    }
    NSURL *URL = [NSURL URLWithString:candidates[index]];
    if (URL == nil) {
        StartFetchFirstImage(candidates, index + 1, completion);
        return;
    }
    NSURLRequest *request = [NSURLRequest requestWithURL:URL cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:6.0];
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)response).statusCode : 200;
        UIImage *image = (error == nil && status < 400 && data.length > 0) ? [UIImage imageWithData:data] : nil;
        if (image != nil && image.size.width >= 48.0) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(image); });
        } else {
            StartFetchFirstImage(candidates, index + 1, completion); // too small or missing: try the next one
        }
    }] resume];
}

#pragma mark - Favorite tile

@interface BrowserStartFavoriteCell : UICollectionViewCell
@property (nonatomic) UIView *tile;
@property (nonatomic) UILabel *letterLabel;
@property (nonatomic) UIImageView *symbolView;
@property (nonatomic) UILabel *nameLabel;
@property (nonatomic) UILabel *badgeLabel;
@property (nonatomic) UIImageView *logoView;
@property (nonatomic, copy) NSString *logoURL;
@end

@implementation BrowserStartFavoriteCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.clipsToBounds = NO;
        self.contentView.clipsToBounds = NO;

        _tile = [UIView new];
        _tile.translatesAutoresizingMaskIntoConstraints = NO;
        _tile.layer.cornerRadius = 40.0;
        _tile.layer.borderColor = UIColor.whiteColor.CGColor;
        _tile.layer.shadowColor = UIColor.blackColor.CGColor;
        _tile.layer.shadowOffset = CGSizeMake(0.0, 14.0);
        _tile.layer.shadowRadius = 22.0;
        [self.contentView addSubview:_tile];

        _letterLabel = [UILabel new];
        _letterLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _letterLabel.font = [UIFont systemFontOfSize:72.0 weight:UIFontWeightBold];
        _letterLabel.textColor = UIColor.whiteColor;
        _letterLabel.textAlignment = NSTextAlignmentCenter;
        [_tile addSubview:_letterLabel];

        _logoView = [UIImageView new];
        _logoView.translatesAutoresizingMaskIntoConstraints = NO;
        _logoView.contentMode = UIViewContentModeScaleAspectFill;
        _logoView.layer.cornerRadius = 40.0;
        _logoView.clipsToBounds = YES;
        _logoView.hidden = YES;
        [_tile addSubview:_logoView];

        _symbolView = [UIImageView new];
        _symbolView.translatesAutoresizingMaskIntoConstraints = NO;
        _symbolView.tintColor = UIColor.whiteColor;
        _symbolView.contentMode = UIViewContentModeCenter;
        [_tile addSubview:_symbolView];

        _nameLabel = [UILabel new];
        _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _nameLabel.font = [UIFont systemFontOfSize:24.0 weight:UIFontWeightMedium];
        _nameLabel.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:_nameLabel];

        _badgeLabel = [UILabel new];
        _badgeLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _badgeLabel.text = [NSString stringWithFormat:@"  %@  ", BrowserLocalized(@"Web App")];
        _badgeLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightBold];
        _badgeLabel.textColor = UIColor.whiteColor;
        _badgeLabel.backgroundColor = [UIColor colorWithRed:0.04 green:0.52 blue:1.0 alpha:0.92];
        _badgeLabel.layer.cornerRadius = 13.0;
        _badgeLabel.layer.masksToBounds = YES;
        [self.contentView addSubview:_badgeLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_tile.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [_tile.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
            [_tile.widthAnchor constraintEqualToConstant:kStartFavoriteTile],
            [_tile.heightAnchor constraintEqualToConstant:kStartFavoriteTile],
            [_letterLabel.centerXAnchor constraintEqualToAnchor:_tile.centerXAnchor],
            [_letterLabel.centerYAnchor constraintEqualToAnchor:_tile.centerYAnchor],
            [_logoView.topAnchor constraintEqualToAnchor:_tile.topAnchor],
            [_logoView.bottomAnchor constraintEqualToAnchor:_tile.bottomAnchor],
            [_logoView.leadingAnchor constraintEqualToAnchor:_tile.leadingAnchor],
            [_logoView.trailingAnchor constraintEqualToAnchor:_tile.trailingAnchor],
            [_symbolView.centerXAnchor constraintEqualToAnchor:_tile.centerXAnchor],
            [_symbolView.centerYAnchor constraintEqualToAnchor:_tile.centerYAnchor],
            [_nameLabel.topAnchor constraintEqualToAnchor:_tile.bottomAnchor constant:18.0],
            [_nameLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_nameLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [_badgeLabel.topAnchor constraintEqualToAnchor:_nameLabel.bottomAnchor constant:8.0],
            [_badgeLabel.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
            [_badgeLabel.heightAnchor constraintEqualToConstant:26.0],
        ]];
        [self applyFocused:NO];
    }
    return self;
}

- (void)applyFocused:(BOOL)focused {
    self.tile.transform = focused ? CGAffineTransformMakeScale(1.1, 1.1) : CGAffineTransformIdentity;
    self.tile.layer.borderWidth = focused ? 5.0 : 0.0;
    self.tile.layer.shadowOpacity = focused ? 0.55 : 0.3;
    self.nameLabel.textColor = focused ? UIColor.whiteColor : [UIColor colorWithWhite:1.0 alpha:0.75];
    self.layer.zPosition = focused ? 1.0 : 0.0;
}

- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator {
    [super didUpdateFocusInContext:context withAnimationCoordinator:coordinator];
    BOOL focused = (context.nextFocusedView == self);
    [coordinator addCoordinatedAnimations:^{ [self applyFocused:focused]; } completion:nil];
}

@end

#pragma mark - Recently visited card

@interface BrowserStartRecentCell : UICollectionViewCell
@property (nonatomic) UIView *card;
@property (nonatomic) UILabel *letterLabel;
@property (nonatomic) UILabel *titleLabel;
@property (nonatomic) UILabel *hostLabel;
@property (nonatomic) UIImageView *thumbnailView;
@property (nonatomic, copy) NSString *thumbnailHost;
@end

@implementation BrowserStartRecentCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.clipsToBounds = NO;
        self.contentView.clipsToBounds = NO;

        _card = [UIView new];
        _card.translatesAutoresizingMaskIntoConstraints = NO;
        _card.layer.cornerRadius = 24.0;
        _card.layer.borderColor = UIColor.whiteColor.CGColor;
        _card.layer.shadowColor = UIColor.blackColor.CGColor;
        _card.layer.shadowOffset = CGSizeMake(0.0, 18.0);
        _card.layer.shadowRadius = 26.0;
        [self.contentView addSubview:_card];

        _letterLabel = [UILabel new];
        _letterLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _letterLabel.font = [UIFont systemFontOfSize:110.0 weight:UIFontWeightBold];
        _letterLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.9];
        [_card addSubview:_letterLabel];

        _thumbnailView = [UIImageView new];
        _thumbnailView.translatesAutoresizingMaskIntoConstraints = NO;
        _thumbnailView.contentMode = UIViewContentModeScaleAspectFill;
        _thumbnailView.layer.cornerRadius = 24.0;
        _thumbnailView.clipsToBounds = YES;
        _thumbnailView.hidden = YES;
        [_card addSubview:_thumbnailView];

        _titleLabel = [UILabel new];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.font = [UIFont systemFontOfSize:26.0 weight:UIFontWeightSemibold];
        _titleLabel.textColor = UIColor.whiteColor;
        [self.contentView addSubview:_titleLabel];

        _hostLabel = [UILabel new];
        _hostLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _hostLabel.font = [UIFont systemFontOfSize:21.0 weight:UIFontWeightRegular];
        _hostLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.55];
        [self.contentView addSubview:_hostLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_card.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [_card.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_card.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [_card.heightAnchor constraintEqualToConstant:270.0],
            [_letterLabel.centerXAnchor constraintEqualToAnchor:_card.centerXAnchor],
            [_letterLabel.centerYAnchor constraintEqualToAnchor:_card.centerYAnchor],
            [_thumbnailView.topAnchor constraintEqualToAnchor:_card.topAnchor],
            [_thumbnailView.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor],
            [_thumbnailView.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor],
            [_thumbnailView.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor],
            [_titleLabel.topAnchor constraintEqualToAnchor:_card.bottomAnchor constant:20.0],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [_hostLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:6.0],
            [_hostLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_hostLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        ]];
        [self applyFocused:NO];
    }
    return self;
}

- (void)applyFocused:(BOOL)focused {
    self.card.transform = focused ? CGAffineTransformMakeScale(1.04, 1.04) : CGAffineTransformIdentity;
    self.card.layer.borderWidth = focused ? 5.0 : 0.0;
    self.card.layer.shadowOpacity = focused ? 0.5 : 0.0;
    self.layer.zPosition = focused ? 1.0 : 0.0;
}

- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator {
    [super didUpdateFocusInContext:context withAnimationCoordinator:coordinator];
    BOOL focused = (context.nextFocusedView == self);
    [coordinator addCoordinatedAnimations:^{ [self applyFocused:focused]; } completion:nil];
}

@end

#pragma mark - Section header

@interface BrowserStartHeaderView : UICollectionReusableView
@property (nonatomic) UILabel *label;
@end

@implementation BrowserStartHeaderView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _label = [UILabel new];
        _label.translatesAutoresizingMaskIntoConstraints = NO;
        _label.font = [UIFont systemFontOfSize:38.0 weight:UIFontWeightBold];
        _label.textColor = UIColor.whiteColor;
        [self addSubview:_label];
        [NSLayoutConstraint activateConstraints:@[
            [_label.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:kStartSideInset],
            [_label.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-22.0],
        ]];
    }
    return self;
}

@end

#pragma mark - Options panel row

/// One row of the favorite options panel (like the "Web App 1" concept): glass when idle, white when focused, optional switch.
@interface BrowserStartPanelRow : UIButton
@property (nonatomic) UIImageView *iconView;
@property (nonatomic) UILabel *mainLabel;
@property (nonatomic) UILabel *detailLabel;
@property (nonatomic) UIView *track;
@property (nonatomic) UIView *knob;
@property (nonatomic) BOOL switchOn;
@property (nonatomic) BOOL destructive;
@property (nonatomic) BOOL highlightedIdle; // the main action: white even when not focused
@end

@implementation BrowserStartPanelRow

+ (instancetype)rowWithSymbol:(NSString *)symbol title:(NSString *)title detail:(NSString *)detail hasSwitch:(BOOL)hasSwitch height:(CGFloat)height {
    BrowserStartPanelRow *row = [BrowserStartPanelRow buttonWithType:UIButtonTypeCustom];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.layer.cornerRadius = 26.0;
    row.layer.shadowColor = UIColor.blackColor.CGColor;
    row.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    row.layer.shadowRadius = 22.0;
    [row.heightAnchor constraintEqualToConstant:height].active = YES;

    UIStackView *texts = [UIStackView new];
    texts.axis = UILayoutConstraintAxisVertical;
    texts.spacing = 3.0;
    texts.userInteractionEnabled = NO;
    texts.translatesAutoresizingMaskIntoConstraints = NO;
    row.mainLabel = [UILabel new];
    row.mainLabel.text = title;
    row.mainLabel.font = [UIFont systemFontOfSize:26.0 weight:UIFontWeightBold];
    [texts addArrangedSubview:row.mainLabel];
    if (detail.length > 0) {
        row.detailLabel = [UILabel new];
        row.detailLabel.text = detail;
        row.detailLabel.font = [UIFont systemFontOfSize:19.0 weight:UIFontWeightRegular];
        [texts addArrangedSubview:row.detailLabel];
    }
    [row addSubview:texts];

    NSMutableArray *constraints = [NSMutableArray array];
    if (symbol != nil) {
        row.iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:28.0 weight:UIImageSymbolWeightSemibold]]];
        row.iconView.translatesAutoresizingMaskIntoConstraints = NO;
        row.iconView.contentMode = UIViewContentModeCenter;
        [row addSubview:row.iconView];
        [constraints addObjectsFromArray:@[
            [row.iconView.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:28.0],
            [row.iconView.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
            [row.iconView.widthAnchor constraintEqualToConstant:36.0],
            [texts.leadingAnchor constraintEqualToAnchor:row.iconView.trailingAnchor constant:20.0],
        ]];
    } else {
        row.mainLabel.textAlignment = NSTextAlignmentCenter;
        [constraints addObject:[texts.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:20.0]];
    }
    [constraints addObject:[texts.centerYAnchor constraintEqualToAnchor:row.centerYAnchor]];
    if (hasSwitch) {
        row.track = [UIView new];
        row.track.translatesAutoresizingMaskIntoConstraints = NO;
        row.track.layer.cornerRadius = 23.0;
        row.track.userInteractionEnabled = NO;
        row.knob = [[UIView alloc] initWithFrame:CGRectMake(4.0, 4.0, 38.0, 38.0)];
        row.knob.backgroundColor = UIColor.whiteColor;
        row.knob.layer.cornerRadius = 19.0;
        [row.track addSubview:row.knob];
        [row addSubview:row.track];
        [constraints addObjectsFromArray:@[
            [row.track.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-24.0],
            [row.track.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
            [row.track.widthAnchor constraintEqualToConstant:84.0],
            [row.track.heightAnchor constraintEqualToConstant:46.0],
            [texts.trailingAnchor constraintLessThanOrEqualToAnchor:row.track.leadingAnchor constant:-16.0],
        ]];
    } else {
        [constraints addObject:[texts.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:(symbol != nil ? -24.0 : -20.0)]];
    }
    [NSLayoutConstraint activateConstraints:constraints];
    [row applyFocused:NO];
    return row;
}

- (void)applyFocused:(BOOL)focused {
    BOOL light = focused || self.highlightedIdle;
    UIColor *dark = [UIColor colorWithWhite:0.11 alpha:1.0];
    self.backgroundColor = light ? UIColor.whiteColor : [UIColor colorWithWhite:1.0 alpha:0.08];
    UIColor *main = self.destructive ? (light ? [UIColor colorWithRed:0.85 green:0.2 blue:0.18 alpha:1.0] : [UIColor colorWithRed:1.0 green:0.54 blue:0.5 alpha:1.0])
                                     : (light ? dark : UIColor.whiteColor);
    self.mainLabel.textColor = main;
    self.detailLabel.textColor = light ? [UIColor colorWithWhite:0.11 alpha:0.6] : [UIColor colorWithWhite:1.0 alpha:0.55];
    self.iconView.tintColor = light ? dark : UIColor.whiteColor;
    self.track.backgroundColor = self.switchOn ? [UIColor colorWithRed:0.04 green:0.52 blue:1.0 alpha:1.0]
                                               : (light ? [UIColor colorWithWhite:0.0 alpha:0.16] : [UIColor colorWithWhite:0.47 alpha:0.5]);
    CGRect knob = self.knob.frame;
    knob.origin.x = self.switchOn ? 42.0 : 4.0;
    self.knob.frame = knob;
    self.transform = focused ? CGAffineTransformMakeScale(1.03, 1.03) : CGAffineTransformIdentity;
    self.layer.shadowOpacity = focused ? 0.4 : 0.0;
}

- (void)setSwitchOn:(BOOL)switchOn {
    _switchOn = switchOn;
    [self applyFocused:self.isFocused];
}

- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator {
    [super didUpdateFocusInContext:context withAnimationCoordinator:coordinator];
    BOOL focused = (context.nextFocusedView == self);
    [coordinator addCoordinatedAnimations:^{ [self applyFocused:focused]; } completion:nil];
}

@end

#pragma mark - Start page

@interface BrowserStartPageViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, BrowserTopBarViewDelegate>
@property (nonatomic) NSUInteger tabCount;
@property (nonatomic) BOOL canGoBack;
@property (nonatomic) BrowserTopBarView *topBar;
@property (nonatomic) UICollectionView *collectionView;   // favorites: one row, scrolls left and right, stays in place
@property (nonatomic) UICollectionView *recentsView;      // recently visited: scrolls up and down below
@property (nonatomic) UILabel *recentsLabel;
@property (nonatomic, copy) NSArray<NSArray<NSString *> *> *favorites; // [url, title]
@property (nonatomic, copy) NSArray<NSArray<NSString *> *> *recents;   // [url, title]
@property (nonatomic) UIView *panelBackdrop;
@property (nonatomic) UIView *panel;
@property (nonatomic) BrowserStartPanelRow *panelFirstRow;
@property (nonatomic) BOOL focusFavoritesNext;
@property (nonatomic) CFTimeInterval panelClosedTime;
@end

@implementation BrowserStartPageViewController

+ (BOOL)isWebAppURL:(NSString *)URLString {
    return URLString.length > 0 && [[NSUserDefaults.standardUserDefaults arrayForKey:kStartWebAppsKey] containsObject:URLString];
}

+ (NSString *)nameForFavoriteURL:(NSString *)URLString {
    for (id entry in [NSUserDefaults.standardUserDefaults arrayForKey:kStartFavoritesKey]) {
        if ([entry isKindOfClass:[NSArray class]] && [entry count] > 1 && [entry[0] isEqual:URLString] && [entry[1] isKindOfClass:[NSString class]] && [entry[1] length] > 0) {
            return entry[1];
        }
    }
    return nil;
}

+ (void)loadLogoForURL:(NSString *)URLString completion:(void (^)(UIImage *image))completion {
    NSURL *URL = [NSURL URLWithString:URLString];
    NSString *host = StartHostForURL(URLString);
    if (URL.host.length == 0 || completion == nil) {
        if (completion != nil) {
            completion(nil);
        }
        return;
    }
    UIImage *cached = [StartLogoCache() objectForKey:host];
    if (cached != nil) {
        completion(cached);
        return;
    }
    NSMutableArray *candidates = [NSMutableArray array];
    NSString *remembered = [[NSUserDefaults.standardUserDefaults dictionaryForKey:@"BrowserSiteIcons"] objectForKey:host];
    if (remembered.length > 0) {
        [candidates addObject:remembered];
    }
    NSString *origin = [NSString stringWithFormat:@"%@://%@", URL.scheme ?: @"https", URL.host];
    [candidates addObject:[origin stringByAppendingString:@"/apple-touch-icon.png"]];
    [candidates addObject:[origin stringByAppendingString:@"/apple-touch-icon-precomposed.png"]];
    StartFetchFirstImage(candidates, 0, ^(UIImage *image) {
        if (image != nil) {
            [StartLogoCache() setObject:image forKey:host];
        }
        completion(image);
    });
}

+ (NSString *)launchWebAppURL {
    NSString *URLString = [NSUserDefaults.standardUserDefaults stringForKey:kStartLaunchWebAppKey];
    return URLString.length > 0 ? URLString : nil;
}

- (instancetype)initWithTabCount:(NSUInteger)tabCount canGoBack:(BOOL)canGoBack {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _tabCount = tabCount;
        _canGoBack = canGoBack;
        _favorites = @[];
        _recents = @[];
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    }
    return self;
}

#pragma mark Data

- (void)reloadData {
    NSMutableArray *favorites = [NSMutableArray array];
    for (id entry in [NSUserDefaults.standardUserDefaults arrayForKey:kStartFavoritesKey]) {
        if ([entry isKindOfClass:[NSArray class]] && [entry count] > 0 && [entry[0] isKindOfClass:[NSString class]] && [entry[0] length] > 0) {
            NSString *title = ([entry count] > 1 && [entry[1] isKindOfClass:[NSString class]]) ? entry[1] : @"";
            [favorites addObject:@[entry[0], title]];
        }
    }
    self.favorites = favorites;

    // Recently visited: the newest page of each site, at most six sites.
    NSMutableArray *recents = [NSMutableArray array];
    NSMutableSet *hosts = [NSMutableSet set];
    for (id entry in [NSUserDefaults.standardUserDefaults arrayForKey:kStartHistoryKey]) {
        if (![entry isKindOfClass:[NSArray class]] || [entry count] == 0 || ![entry[0] isKindOfClass:[NSString class]]) {
            continue;
        }
        NSString *URLString = entry[0];
        NSString *host = StartHostForURL(URLString);
        if (![URLString hasPrefix:@"http"] || host.length == 0 || [hosts containsObject:host]) {
            continue;
        }
        [hosts addObject:host];
        NSString *title = ([entry count] > 1 && [entry[1] isKindOfClass:[NSString class]] && [entry[1] length] > 0) ? entry[1] : host;
        [recents addObject:@[URLString, title]];
        if (recents.count == 6) {
            break;
        }
    }
    self.recents = recents;
    [self.collectionView reloadData];
    [self.recentsView reloadData];
    self.recentsLabel.hidden = (self.recents.count == 0);
}

- (void)saveFavorites:(NSArray *)favorites {
    [NSUserDefaults.standardUserDefaults setObject:favorites forKey:kStartFavoritesKey];
    [self reloadData];
    if (self.favoritesChanged != nil) {
        self.favoritesChanged();
    }
}

- (void)setURL:(NSString *)URLString inList:(NSString *)key enabled:(BOOL)enabled {
    NSMutableArray *list = [[NSUserDefaults.standardUserDefaults arrayForKey:key] mutableCopy] ?: [NSMutableArray array];
    [list removeObject:URLString];
    if (enabled) {
        [list addObject:URLString];
    }
    [NSUserDefaults.standardUserDefaults setObject:list forKey:key];
}

#pragma mark View

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = StartBackgroundColor();
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;

    // The real Orbrisa top bar (Liquid Glass), the address field focused – like on a page, just with nothing loaded yet.
    BrowserTopBarView *topBar = [[BrowserTopBarView alloc] initWithEffect:nil];
    topBar.frame = CGRectMake(0.0, 0.0, CGRectGetWidth(self.view.bounds), 170.0);
    topBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    topBar.delegate = self;
    [topBar setPageTitle:nil URLString:nil];
    [topBar setTabCount:self.tabCount];
    [topBar setCanGoBack:self.canGoBack canGoForward:NO];
    [topBar setReaderAvailable:NO feedAvailable:NO];
    [topBar setFocusModeActive:YES];
    [self.view addSubview:topBar];
    self.topBar = topBar;

    UILabel *favoritesLabel = [UILabel new];
    favoritesLabel.translatesAutoresizingMaskIntoConstraints = NO;
    favoritesLabel.text = BrowserLocalized(@"Favorites");
    favoritesLabel.font = [UIFont systemFontOfSize:38.0 weight:UIFontWeightBold];
    favoritesLabel.textColor = UIColor.whiteColor;
    [self.view addSubview:favoritesLabel];

    // Favorites: one row that stays where it is and scrolls left / right.
    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.itemSize = CGSizeMake(220.0, 280.0);
    layout.minimumLineSpacing = 34.0;
    layout.sectionInset = UIEdgeInsetsMake(0.0, kStartSideInset - 20.0, 0.0, kStartSideInset - 20.0);
    UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    collectionView.backgroundColor = UIColor.clearColor;
    collectionView.clipsToBounds = NO;
    collectionView.showsHorizontalScrollIndicator = NO;
    collectionView.remembersLastFocusedIndexPath = YES;
    collectionView.dataSource = self;
    collectionView.delegate = self;
    [collectionView registerClass:[BrowserStartFavoriteCell class] forCellWithReuseIdentifier:@"favorite"];
    [self.view insertSubview:collectionView atIndex:0];
    self.collectionView = collectionView;

    UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleHold:)];
    hold.allowedPressTypes = @[@(UIPressTypeSelect)];
    hold.minimumPressDuration = 0.6;
    [collectionView addGestureRecognizer:hold];

    UILabel *recentsLabel = [UILabel new];
    recentsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    recentsLabel.text = BrowserLocalized(@"Recently Visited");
    recentsLabel.font = [UIFont systemFontOfSize:38.0 weight:UIFontWeightBold];
    recentsLabel.textColor = UIColor.whiteColor;
    [self.view addSubview:recentsLabel];
    self.recentsLabel = recentsLabel;

    // Recently visited: the only part that scrolls up and down, cut off cleanly at its top edge.
    UICollectionViewFlowLayout *recentsLayout = [UICollectionViewFlowLayout new];
    recentsLayout.minimumInteritemSpacing = 40.0;
    recentsLayout.minimumLineSpacing = 50.0;
    recentsLayout.sectionInset = UIEdgeInsetsMake(24.0, kStartSideInset, 60.0, kStartSideInset);
    UICollectionView *recentsView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:recentsLayout];
    recentsView.translatesAutoresizingMaskIntoConstraints = NO;
    recentsView.backgroundColor = UIColor.clearColor;
    recentsView.clipsToBounds = YES;
    recentsView.remembersLastFocusedIndexPath = YES;
    recentsView.dataSource = self;
    recentsView.delegate = self;
    [recentsView registerClass:[BrowserStartRecentCell class] forCellWithReuseIdentifier:@"recent"];
    [self.view insertSubview:recentsView atIndex:0];
    self.recentsView = recentsView;

    [NSLayoutConstraint activateConstraints:@[
        [favoritesLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:kStartSideInset],
        [favoritesLabel.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:165.0],
        [collectionView.topAnchor constraintEqualToAnchor:favoritesLabel.bottomAnchor constant:28.0],
        [collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [collectionView.heightAnchor constraintEqualToConstant:290.0],
        [recentsLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:kStartSideInset],
        [recentsLabel.topAnchor constraintEqualToAnchor:collectionView.bottomAnchor constant:22.0],
        [recentsView.topAnchor constraintEqualToAnchor:recentsLabel.bottomAnchor constant:4.0],
        [recentsView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [recentsView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [recentsView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];
    [self reloadData];
}

- (NSArray<id<UIFocusEnvironment>> *)preferredFocusEnvironments {
    if (self.panel != nil) {
        return @[self.panelFirstRow];
    }
    if (self.focusFavoritesNext) {
        self.focusFavoritesNext = NO;
        return @[self.collectionView]; // back to the favorite the panel belonged to
    }
    UIView *item = [self.topBar preferredFocusItem];
    return item != nil ? @[item] : @[self.topBar];
}

- (void)browserTopBarView:(__unused BrowserTopBarView *)topBarView didTriggerAction:(BrowserTopBarAction)action {
    switch (action) {
        case BrowserTopBarActionURL:
            [self searchPressed];
            break;
        case BrowserTopBarActionTabs:
            [self tabsPressed];
            break;
        case BrowserTopBarActionMenu:
            [self settingsPressed];
            break;
        case BrowserTopBarActionFeed:
            [self closeThen:self.showFeeds];
            break;
        case BrowserTopBarActionBack:
            if (self.canGoBack) {
                [self backPressed];
            }
            break;
        default:
            break; // reload, forward, home, full screen: nothing to do on the start page
    }
}

#pragma mark Collection

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(__unused NSInteger)section {
    if (collectionView == self.recentsView) {
        return (NSInteger)self.recents.count;
    }
    return (NSInteger)self.favorites.count + 1; // + "Add Favorite"
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (collectionView != self.recentsView) {
        BrowserStartFavoriteCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"favorite" forIndexPath:indexPath];
        if (indexPath.item < (NSInteger)self.favorites.count) {
            NSArray<NSString *> *favorite = self.favorites[(NSUInteger)indexPath.item];
            NSString *name = favorite[1].length > 0 ? favorite[1] : StartHostForURL(favorite[0]);
            cell.nameLabel.text = name;
            cell.letterLabel.text = StartLetterForName(favorite[1], favorite[0]);
            cell.letterLabel.hidden = NO;
            cell.symbolView.hidden = YES;
            cell.tile.backgroundColor = [BrowserFeedStore colorForFeedURL:StartHostForURL(favorite[0])];
            cell.badgeLabel.hidden = ![BrowserStartPageViewController isWebAppURL:favorite[0]];
            cell.logoView.hidden = YES;
            cell.logoView.image = nil;
            cell.logoURL = favorite[0];
            NSString *logoURL = favorite[0];
            __weak BrowserStartFavoriteCell *weakCell = cell;
            [BrowserStartPageViewController loadLogoForURL:logoURL completion:^(UIImage *image) {
                if (image == nil || ![weakCell.logoURL isEqualToString:logoURL]) {
                    return; // no logo, or the cell shows another favorite by now
                }
                weakCell.logoView.image = image;
                weakCell.logoView.hidden = NO;
                weakCell.letterLabel.hidden = YES;
            }];
        } else {
            cell.nameLabel.text = BrowserLocalized(@"Add Favorite");
            cell.letterLabel.hidden = YES;
            cell.symbolView.hidden = NO;
            cell.symbolView.image = [UIImage systemImageNamed:@"plus" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:60.0 weight:UIImageSymbolWeightSemibold]];
            cell.tile.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
            cell.badgeLabel.hidden = YES;
            cell.logoView.hidden = YES;
            cell.logoURL = nil;
        }
        [cell applyFocused:cell.isFocused];
        return cell;
    }

    BrowserStartRecentCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"recent" forIndexPath:indexPath];
    NSArray<NSString *> *recent = self.recents[(NSUInteger)indexPath.item];
    NSString *host = StartHostForURL(recent[0]);
    cell.titleLabel.text = recent[1];
    cell.hostLabel.text = host;
    cell.letterLabel.text = StartLetterForName(host, recent[0]);
    cell.card.backgroundColor = [[BrowserFeedStore colorForFeedURL:host] colorWithAlphaComponent:0.55];
    // The real page as it looked on the last visit (saved by the tabs), else colour and letter.
    cell.thumbnailHost = host;
    cell.thumbnailView.image = nil;
    cell.thumbnailView.hidden = YES;
    cell.letterLabel.hidden = NO;
    __weak BrowserStartRecentCell *weakCell = cell;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSURL *caches = [NSFileManager.defaultManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject;
        NSURL *file = [[caches URLByAppendingPathComponent:@"OrbrisaThumbnails" isDirectory:YES] URLByAppendingPathComponent:[host stringByAppendingString:@".jpg"]];
        UIImage *image = [UIImage imageWithContentsOfFile:file.path];
        if (image == nil) {
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![weakCell.thumbnailHost isEqualToString:host]) {
                return;
            }
            weakCell.thumbnailView.image = image;
            weakCell.thumbnailView.hidden = NO;
            weakCell.letterLabel.hidden = YES;
        });
    });
    [cell applyFocused:cell.isFocused];
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout sizeForItemAtIndexPath:(__unused NSIndexPath *)indexPath {
    if (collectionView != self.recentsView) {
        return ((UICollectionViewFlowLayout *)layout).itemSize;
    }
    CGFloat available = CGRectGetWidth(collectionView.bounds) - kStartSideInset * 2.0;
    return CGSizeMake(floor((available - 2.0 * 40.0) / 3.0), 360.0);
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (collectionView != self.recentsView) {
        if (indexPath.item >= (NSInteger)self.favorites.count) {
            [self presentAddFavorite];
            return;
        }
        NSString *URLString = self.favorites[(NSUInteger)indexPath.item][0];
        [self closeAndOpenURL:URLString asWebApp:[BrowserStartPageViewController isWebAppURL:URLString]];
        return;
    }
    [self closeAndOpenURL:self.recents[(NSUInteger)indexPath.item][0] asWebApp:NO];
}

#pragma mark Actions

- (void)closeThen:(void (^)(void))block {
    [self dismissViewControllerAnimated:YES completion:^{
        if (block != nil) {
            block();
        }
    }];
}

- (void)closeAndOpenURL:(NSString *)URLString asWebApp:(BOOL)asWebApp {
    void (^openURL)(NSString *, BOOL) = self.openURL;
    [self closeThen:^{
        if (openURL != nil) {
            openURL(URLString, asWebApp);
        }
    }];
}

- (void)searchPressed { [self closeThen:self.search]; }
- (void)tabsPressed { [self closeThen:self.showTabs]; }
- (void)settingsPressed { [self closeThen:self.showSettings]; }
- (void)backPressed { [self closeThen:nil]; }

- (NSInteger)focusedFavoriteIndex {
    id<UIFocusItem> focused = [UIFocusSystem focusSystemForEnvironment:self].focusedItem;
    if (![focused isKindOfClass:[BrowserStartFavoriteCell class]]) {
        return NSNotFound;
    }
    NSIndexPath *indexPath = [self.collectionView indexPathForCell:(BrowserStartFavoriteCell *)focused];
    if (indexPath == nil || indexPath.section != 0 || indexPath.item >= (NSInteger)self.favorites.count) {
        return NSNotFound;
    }
    return indexPath.item;
}

- (void)handleHold:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateBegan) {
        return;
    }
    NSInteger index = self.panel == nil ? [self focusedFavoriteIndex] : NSNotFound;
    if (index != NSNotFound) {
        [self presentOptionsForFavoriteAtIndex:(NSUInteger)index];
    }
}

- (void)presentOptionsForFavoriteAtIndex:(NSUInteger)index {
    // The panel from the "Web App 1" concept, right under the favorite.
    [self closePanel];
    NSArray<NSString *> *favorite = self.favorites[index];
    NSString *URLString = favorite[0];
    NSString *name = favorite[1].length > 0 ? favorite[1] : StartHostForURL(URLString);

    UIView *backdrop = [[UIView alloc] initWithFrame:self.view.bounds];
    backdrop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    backdrop.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    backdrop.userInteractionEnabled = NO;
    [self.view addSubview:backdrop];
    self.panelBackdrop = backdrop;

    UIVisualEffectView *panel = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    panel.layer.cornerRadius = 40.0;
    panel.clipsToBounds = YES;
    panel.contentView.backgroundColor = [UIColor colorWithRed:0.19 green:0.19 blue:0.21 alpha:0.75];

    // Header: tile, name, address
    UILabel *tile = [UILabel new];
    tile.text = StartLetterForName(favorite[1], URLString);
    tile.textAlignment = NSTextAlignmentCenter;
    tile.font = [UIFont systemFontOfSize:36.0 weight:UIFontWeightBold];
    tile.textColor = UIColor.whiteColor;
    tile.backgroundColor = [BrowserFeedStore colorForFeedURL:StartHostForURL(URLString)];
    tile.layer.cornerRadius = 18.0;
    tile.layer.masksToBounds = YES;
    [tile.widthAnchor constraintEqualToConstant:72.0].active = YES;
    [tile.heightAnchor constraintEqualToConstant:72.0].active = YES;
    UILabel *title = [UILabel new];
    title.text = name;
    title.font = [UIFont systemFontOfSize:32.0 weight:UIFontWeightBold];
    title.textColor = UIColor.whiteColor;
    UILabel *address = [UILabel new];
    address.text = StartHostForURL(URLString);
    address.font = [UIFont systemFontOfSize:21.0 weight:UIFontWeightRegular];
    address.textColor = [UIColor colorWithWhite:1.0 alpha:0.6];
    UIStackView *titles = [[UIStackView alloc] initWithArrangedSubviews:@[title, address]];
    titles.axis = UILayoutConstraintAxisVertical;
    titles.spacing = 2.0;
    UIStackView *header = [[UIStackView alloc] initWithArrangedSubviews:@[tile, titles]];
    header.spacing = 20.0;
    header.alignment = UIStackViewAlignmentCenter;
    header.layoutMargins = UIEdgeInsetsMake(0.0, 8.0, 8.0, 8.0);
    header.layoutMarginsRelativeArrangement = YES;

    BrowserStartPanelRow *open = [BrowserStartPanelRow rowWithSymbol:@"arrow.up.left.and.arrow.down.right" title:BrowserLocalized(@"Open as Web App")
                                                              detail:BrowserLocalized(@"Full screen – no bar, no buttons") hasSwitch:NO height:100.0];
    [open addTarget:self action:@selector(panelOpenPressed:) forControlEvents:UIControlEventPrimaryActionTriggered];
    BrowserStartPanelRow *launch = [BrowserStartPanelRow rowWithSymbol:@"power" title:BrowserLocalized(@"Open When Orbrisa Starts")
                                                                detail:BrowserLocalized(@"Orbrisa starts right away with this web app") hasSwitch:YES height:88.0];
    launch.switchOn = [[BrowserStartPageViewController launchWebAppURL] isEqualToString:URLString];
    [launch addTarget:self action:@selector(panelLaunchPressed:) forControlEvents:UIControlEventPrimaryActionTriggered];
    BrowserStartPanelRow *always = [BrowserStartPanelRow rowWithSymbol:@"square.on.square" title:BrowserLocalized(@"Always Open as Web App")
                                                                detail:BrowserLocalized(@"A click on the tile opens it full screen") hasSwitch:YES height:88.0];
    always.switchOn = [BrowserStartPageViewController isWebAppURL:URLString];
    [always addTarget:self action:@selector(panelAlwaysPressed:) forControlEvents:UIControlEventPrimaryActionTriggered];
    BrowserStartPanelRow *rename = [BrowserStartPanelRow rowWithSymbol:nil title:BrowserLocalized(@"Rename") detail:nil hasSwitch:NO height:72.0];
    [rename addTarget:self action:@selector(panelRenamePressed:) forControlEvents:UIControlEventPrimaryActionTriggered];
    BrowserStartPanelRow *remove = [BrowserStartPanelRow rowWithSymbol:nil title:BrowserLocalized(@"Remove") detail:nil hasSwitch:NO height:72.0];
    remove.destructive = YES;
    [remove applyFocused:NO];
    [remove addTarget:self action:@selector(panelRemovePressed:) forControlEvents:UIControlEventPrimaryActionTriggered];
    for (BrowserStartPanelRow *row in @[rename, remove]) {
        row.layer.cornerRadius = 36.0;
    }
    UIStackView *bottom = [[UIStackView alloc] initWithArrangedSubviews:@[rename, remove]];
    bottom.distribution = UIStackViewDistributionFillEqually;
    bottom.spacing = 14.0;

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[header, open, launch, always, bottom]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 14.0;
    [stack setCustomSpacing:20.0 afterView:always];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [panel.contentView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:panel.contentView.topAnchor constant:34.0],
        [stack.bottomAnchor constraintEqualToAnchor:panel.contentView.bottomAnchor constant:-34.0],
        [stack.leadingAnchor constraintEqualToAnchor:panel.contentView.leadingAnchor constant:34.0],
        [stack.trailingAnchor constraintEqualToAnchor:panel.contentView.trailingAnchor constant:-34.0],
    ]];
    for (BrowserStartPanelRow *row in @[open, launch, always, rename, remove]) {
        row.tag = (NSInteger)index;
    }

    // Under the tile, kept on screen
    CGFloat width = 780.0;
    CGSize size = CGSizeMake(width, 34.0 + 80.0 + 14.0 + 100.0 + 14.0 + 88.0 + 14.0 + 88.0 + 20.0 + 72.0 + 34.0);
    UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForItem:(NSInteger)index inSection:0]];
    CGRect cellFrame = cell != nil ? [cell convertRect:cell.bounds toView:self.view] : CGRectMake(CGRectGetMidX(self.view.bounds), 300.0, 0.0, 0.0);
    CGFloat bounds = CGRectGetWidth(self.view.bounds);
    CGFloat x = MIN(MAX(CGRectGetMidX(cellFrame) - width / 2.0, kStartSideInset), bounds - kStartSideInset - width);
    CGFloat y = MIN(CGRectGetMinY(cellFrame) + kStartFavoriteTile + 70.0, CGRectGetHeight(self.view.bounds) - size.height - 40.0);
    panel.frame = CGRectMake(x, MAX(y, 140.0), width, size.height);
    [self.view addSubview:panel];
    self.panel = panel;
    self.panelFirstRow = open;

    self.collectionView.userInteractionEnabled = NO;
    self.recentsView.userInteractionEnabled = NO;
    self.topBar.userInteractionEnabled = NO;
    panel.alpha = 0.0;
    backdrop.alpha = 0.0;
    [UIView animateWithDuration:0.22 animations:^{
        panel.alpha = 1.0;
        backdrop.alpha = 1.0;
    }];
    [self setNeedsFocusUpdate];
    [self updateFocusIfNeeded];
}

- (BOOL)consumeMenuPress {
    if (self.panel != nil) {
        [self closePanel];
        return YES;
    }
    return CACurrentMediaTime() - self.panelClosedTime < 0.4; // the same press, seen a second time
}

- (void)closePanel {
    if (self.panel == nil) {
        return;
    }
    UIView *panel = self.panel;
    UIView *backdrop = self.panelBackdrop;
    self.panel = nil;
    self.panelBackdrop = nil;
    self.panelFirstRow = nil;
    self.panelClosedTime = CACurrentMediaTime();
    self.collectionView.userInteractionEnabled = YES;
    self.recentsView.userInteractionEnabled = YES;
    self.topBar.userInteractionEnabled = YES;
    self.focusFavoritesNext = YES;
    [UIView animateWithDuration:0.18 animations:^{
        panel.alpha = 0.0;
        backdrop.alpha = 0.0;
    } completion:^(__unused BOOL finished) {
        [panel removeFromSuperview];
        [backdrop removeFromSuperview];
    }];
    [self setNeedsFocusUpdate];
    [self updateFocusIfNeeded];
}

- (NSString *)URLForPanelRow:(UIButton *)row {
    return (row.tag >= 0 && row.tag < (NSInteger)self.favorites.count) ? self.favorites[(NSUInteger)row.tag][0] : nil;
}

- (void)panelOpenPressed:(UIButton *)row {
    NSString *URLString = [self URLForPanelRow:row];
    [self closePanel];
    if (URLString != nil) {
        [self closeAndOpenURL:URLString asWebApp:YES];
    }
}

- (void)panelLaunchPressed:(BrowserStartPanelRow *)row {
    NSString *URLString = [self URLForPanelRow:row];
    if (URLString == nil) {
        return;
    }
    if (row.switchOn) {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:kStartLaunchWebAppKey];
    } else {
        [NSUserDefaults.standardUserDefaults setObject:URLString forKey:kStartLaunchWebAppKey];
    }
    [UIView animateWithDuration:0.2 animations:^{ row.switchOn = !row.switchOn; }];
}

- (void)panelAlwaysPressed:(BrowserStartPanelRow *)row {
    NSString *URLString = [self URLForPanelRow:row];
    if (URLString == nil) {
        return;
    }
    [self setURL:URLString inList:kStartWebAppsKey enabled:!row.switchOn];
    [UIView animateWithDuration:0.2 animations:^{ row.switchOn = !row.switchOn; }];
    [self.collectionView reloadItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:row.tag inSection:0]]];
}

- (void)panelRenamePressed:(UIButton *)row {
    NSUInteger index = (NSUInteger)row.tag;
    [self closePanel];
    if (index < self.favorites.count) {
        [self presentRenameForFavoriteAtIndex:index];
    }
}

- (void)panelRemovePressed:(UIButton *)row {
    NSString *URLString = [self URLForPanelRow:row];
    NSUInteger index = (NSUInteger)row.tag;
    [self closePanel];
    if (URLString == nil) {
        return;
    }
    NSMutableArray *favorites = [self.favorites mutableCopy];
    [favorites removeObjectAtIndex:index];
    [self setURL:URLString inList:kStartWebAppsKey enabled:NO];
    if ([[BrowserStartPageViewController launchWebAppURL] isEqualToString:URLString]) {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:kStartLaunchWebAppKey];
    }
    [self saveFavorites:favorites];
}

- (void)presentRenameForFavoriteAtIndex:(NSUInteger)index {
    NSArray<NSString *> *favorite = self.favorites[index];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:BrowserLocalized(@"Rename") message:favorite[0] preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = favorite[1];
        textField.placeholder = BrowserLocalized(@"Name");
    }];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:BrowserLocalized(@"Save") style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *name = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @"";
        NSMutableArray *favorites = [weakSelf.favorites mutableCopy];
        if (index < favorites.count) {
            favorites[index] = @[favorite[0], name];
        }
        [weakSelf saveFavorites:favorites];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:BrowserLocalized(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)presentAddFavorite {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:BrowserLocalized(@"Add Favorite") message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = BrowserLocalized(@"Name");
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = BrowserLocalized(@"Address");
        textField.keyboardType = UIKeyboardTypeURL;
        textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:BrowserLocalized(@"Save") style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSCharacterSet *spaces = NSCharacterSet.whitespaceAndNewlineCharacterSet;
        NSString *name = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:spaces] ?: @"";
        NSString *address = [alert.textFields.lastObject.text stringByTrimmingCharactersInSet:spaces] ?: @"";
        if (address.length == 0) {
            return;
        }
        if (![address.lowercaseString hasPrefix:@"http://"] && ![address.lowercaseString hasPrefix:@"https://"]) {
            address = [@"https://" stringByAppendingString:address];
        }
        if ([NSURL URLWithString:address].host.length == 0) {
            return;
        }
        NSMutableArray *favorites = [weakSelf.favorites mutableCopy];
        [favorites addObject:@[address, name]];
        [weakSelf saveFavorites:favorites];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:BrowserLocalized(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark Remote

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    UIPress *press = presses.anyObject;
    if (press.type == UIPressTypeMenu && [self backLeavesApp]) {
        [super pressesBegan:presses withEvent:event]; // the only, empty tab: Back goes to the Home screen as usual
        return;
    }
    if (press.type == UIPressTypeMenu || press.type == UIPressTypePlayPause) {
        return;
    }
    [super pressesBegan:presses withEvent:event];
}

/// YES when Back has nowhere to go inside Orbrisa: the only tab, and it is empty.
- (BOOL)backLeavesApp {
    return self.panel == nil && !self.canGoBack && (self.closeEmptyTab == nil || self.tabCount <= 1);
}

- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    UIPress *press = presses.anyObject;
    if (press.type == UIPressTypeMenu && [self consumeMenuPress]) {
        return; // Back closes only the panel – the start page stays
    }
    if (self.panel != nil && press.type == UIPressTypePlayPause) {
        [self closePanel];
        return;
    }
    if (press.type == UIPressTypeMenu) {
        if ([self backLeavesApp]) {
            [super pressesEnded:presses withEvent:event];
        } else if (!self.canGoBack && self.closeEmptyTab != nil) {
            [self closeThen:self.closeEmptyTab]; // an empty tab: close it and go back into the previous tab
        } else {
            [self closeThen:nil];
        }
        return;
    }
    if (press.type == UIPressTypePlayPause) {
        NSInteger index = [self focusedFavoriteIndex];
        if (index != NSNotFound) {
            [self presentOptionsForFavoriteAtIndex:(NSUInteger)index];
        }
        return;
    }
    [super pressesEnded:presses withEvent:event];
}

@end

#pragma mark - Web app dock

@interface BrowserWebAppDockViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property (nonatomic, copy) NSString *currentURL;
@property (nonatomic, copy) NSArray<NSArray<NSString *> *> *apps; // [url, title]; the last entry is the start page
@property (nonatomic) UIVisualEffectView *panel;
@property (nonatomic) UICollectionView *collectionView;
@end

@implementation BrowserWebAppDockViewController

- (instancetype)initWithCurrentURL:(NSString *)currentURL {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _currentURL = [currentURL copy] ?: @"";
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;

        NSMutableArray *webApps = [NSMutableArray array];
        NSMutableArray *favorites = [NSMutableArray array];
        for (id entry in [NSUserDefaults.standardUserDefaults arrayForKey:kStartFavoritesKey]) {
            if (![entry isKindOfClass:[NSArray class]] || [entry count] == 0 || ![entry[0] isKindOfClass:[NSString class]]) {
                continue;
            }
            NSString *title = ([entry count] > 1 && [entry[1] isKindOfClass:[NSString class]]) ? entry[1] : @"";
            NSArray *item = @[entry[0], title];
            [favorites addObject:item];
            if ([BrowserStartPageViewController isWebAppURL:entry[0]]) {
                [webApps addObject:item];
            }
        }
        NSMutableArray *apps = [(webApps.count > 0 ? webApps : favorites) mutableCopy];
        [apps addObject:@[@"", BrowserLocalized(@"Start Page")]];
        _apps = apps;
    }
    return self;
}

- (UIVisualEffect *)glassEffect {
    Class glassClass = NSClassFromString(@"UIGlassEffect");
    if (glassClass != Nil) {
        id effect = [[glassClass alloc] init];
        if ([effect isKindOfClass:[UIVisualEffect class]]) {
            return effect;
        }
    }
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.25];

    UIVisualEffectView *panel = [[UIVisualEffectView alloc] initWithEffect:[self glassEffect]];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    panel.layer.cornerRadius = 48.0;
    panel.clipsToBounds = YES;
    panel.contentView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.25];
    [self.view addSubview:panel];
    self.panel = panel;

    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = BrowserLocalized(@"Web Apps");
    title.font = [UIFont systemFontOfSize:24.0 weight:UIFontWeightSemibold];
    title.textColor = [UIColor colorWithWhite:1.0 alpha:0.7];
    [panel.contentView addSubview:title];

    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.itemSize = CGSizeMake(210.0, 280.0);
    layout.minimumLineSpacing = 30.0;
    layout.sectionInset = UIEdgeInsetsMake(0.0, 40.0, 0.0, 40.0);
    UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    collectionView.backgroundColor = UIColor.clearColor;
    collectionView.clipsToBounds = NO;
    collectionView.showsHorizontalScrollIndicator = NO;
    collectionView.dataSource = self;
    collectionView.delegate = self;
    [collectionView registerClass:[BrowserStartFavoriteCell class] forCellWithReuseIdentifier:@"app"];
    [panel.contentView addSubview:collectionView];
    self.collectionView = collectionView;

    CGFloat width = MIN(1700.0, 80.0 + self.apps.count * 210.0 + (self.apps.count - 1) * 30.0);
    [NSLayoutConstraint activateConstraints:@[
        [panel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [panel.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-50.0],
        [panel.widthAnchor constraintEqualToConstant:MAX(width, 560.0)],
        [panel.heightAnchor constraintEqualToConstant:400.0],
        [title.topAnchor constraintEqualToAnchor:panel.contentView.topAnchor constant:26.0],
        [title.leadingAnchor constraintEqualToAnchor:panel.contentView.leadingAnchor constant:44.0],
        [collectionView.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:26.0],
        [collectionView.leadingAnchor constraintEqualToAnchor:panel.contentView.leadingAnchor],
        [collectionView.trailingAnchor constraintEqualToAnchor:panel.contentView.trailingAnchor],
        [collectionView.heightAnchor constraintEqualToConstant:290.0],
    ]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // Slides up from the bottom edge, like a drop rising.
    self.panel.transform = CGAffineTransformMakeTranslation(0.0, 520.0);
    [UIView animateWithDuration:0.55 delay:0.0 usingSpringWithDamping:0.82 initialSpringVelocity:0.4 options:0 animations:^{
        self.panel.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (NSArray<id<UIFocusEnvironment>> *)preferredFocusEnvironments {
    return @[self.collectionView];
}

- (NSIndexPath *)indexPathForPreferredFocusedViewInCollectionView:(__unused UICollectionView *)collectionView {
    for (NSUInteger i = 0; i < self.apps.count; i++) {
        if (self.apps[i][0].length > 0 && [self.apps[i][0] isEqualToString:self.currentURL]) {
            return [NSIndexPath indexPathForItem:(NSInteger)i inSection:0];
        }
    }
    return [NSIndexPath indexPathForItem:0 inSection:0];
}

- (NSInteger)collectionView:(__unused UICollectionView *)collectionView numberOfItemsInSection:(__unused NSInteger)section {
    return (NSInteger)self.apps.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    BrowserStartFavoriteCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"app" forIndexPath:indexPath];
    NSArray<NSString *> *app = self.apps[(NSUInteger)indexPath.item];
    cell.badgeLabel.hidden = YES;
    cell.logoView.hidden = YES;
    cell.logoView.image = nil;
    if (app[0].length == 0) {
        cell.nameLabel.text = app[1];
        cell.letterLabel.hidden = YES;
        cell.symbolView.hidden = NO;
        cell.symbolView.image = [UIImage systemImageNamed:@"house.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:64.0 weight:UIImageSymbolWeightSemibold]];
        cell.tile.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
        cell.logoURL = nil;
    } else {
        cell.nameLabel.text = app[1].length > 0 ? app[1] : StartHostForURL(app[0]);
        cell.letterLabel.text = StartLetterForName(app[1], app[0]);
        cell.letterLabel.hidden = NO;
        cell.symbolView.hidden = YES;
        cell.tile.backgroundColor = [BrowserFeedStore colorForFeedURL:StartHostForURL(app[0])];
        cell.logoURL = app[0];
        NSString *logoURL = app[0];
        __weak BrowserStartFavoriteCell *weakCell = cell;
        [BrowserStartPageViewController loadLogoForURL:logoURL completion:^(UIImage *image) {
            if (image == nil || ![weakCell.logoURL isEqualToString:logoURL]) {
                return;
            }
            weakCell.logoView.image = image;
            weakCell.logoView.hidden = NO;
            weakCell.letterLabel.hidden = YES;
        }];
        // the web app that is open right now carries a small dot
        cell.badgeLabel.hidden = ![app[0] isEqualToString:self.currentURL];
        cell.badgeLabel.text = [NSString stringWithFormat:@"  %@  ", BrowserLocalized(@"Open")];
    }
    [cell applyFocused:cell.isFocused];
    return cell;
}

- (void)collectionView:(__unused UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSString *URLString = self.apps[(NSUInteger)indexPath.item][0];
    void (^open)(NSString *) = self.openWebApp;
    void (^start)(void) = self.showStartPage;
    [self closeThen:^{
        if (URLString.length == 0) {
            if (start != nil) {
                start();
            }
        } else if (open != nil) {
            open(URLString);
        }
    }];
}

- (void)closeThen:(void (^)(void))block {
    [UIView animateWithDuration:0.25 animations:^{
        self.panel.transform = CGAffineTransformMakeTranslation(0.0, 520.0);
    }];
    [self dismissViewControllerAnimated:YES completion:block];
}

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    if (presses.anyObject.type == UIPressTypeMenu) {
        return;
    }
    [super pressesBegan:presses withEvent:event];
}

- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    if (presses.anyObject.type == UIPressTypeMenu) {
        [self closeThen:nil];
        return;
    }
    [super pressesEnded:presses withEvent:event];
}

@end

