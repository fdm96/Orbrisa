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

#pragma mark - Favorite tile

@interface BrowserStartFavoriteCell : UICollectionViewCell
@property (nonatomic) UIView *tile;
@property (nonatomic) UILabel *letterLabel;
@property (nonatomic) UIImageView *symbolView;
@property (nonatomic) UILabel *nameLabel;
@property (nonatomic) UILabel *badgeLabel;
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

#pragma mark - Start page

@interface BrowserStartPageViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, BrowserTopBarViewDelegate>
@property (nonatomic) NSUInteger tabCount;
@property (nonatomic) BOOL canGoBack;
@property (nonatomic) BrowserTopBarView *topBar;
@property (nonatomic) UICollectionView *collectionView;
@property (nonatomic, copy) NSArray<NSArray<NSString *> *> *favorites; // [url, title]
@property (nonatomic, copy) NSArray<NSArray<NSString *> *> *recents;   // [url, title]
@end

@implementation BrowserStartPageViewController

+ (BOOL)isWebAppURL:(NSString *)URLString {
    return URLString.length > 0 && [[NSUserDefaults.standardUserDefaults arrayForKey:kStartWebAppsKey] containsObject:URLString];
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

    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.minimumInteritemSpacing = 40.0;
    layout.minimumLineSpacing = 50.0;
    UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    collectionView.backgroundColor = UIColor.clearColor;
    collectionView.clipsToBounds = NO;
    collectionView.remembersLastFocusedIndexPath = YES;
    collectionView.dataSource = self;
    collectionView.delegate = self;
    [collectionView registerClass:[BrowserStartFavoriteCell class] forCellWithReuseIdentifier:@"favorite"];
    [collectionView registerClass:[BrowserStartRecentCell class] forCellWithReuseIdentifier:@"recent"];
    [collectionView registerClass:[BrowserStartHeaderView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"header"];
    [self.view insertSubview:collectionView atIndex:0];
    self.collectionView = collectionView;

    UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleHold:)];
    hold.allowedPressTypes = @[@(UIPressTypeSelect)];
    hold.minimumPressDuration = 0.6;
    [collectionView addGestureRecognizer:hold];

    NSMutableArray *constraints = [@[
        [collectionView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:170.0],
        [collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ] mutableCopy];
    [NSLayoutConstraint activateConstraints:constraints];
    [self reloadData];
}

- (NSArray<id<UIFocusEnvironment>> *)preferredFocusEnvironments {
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

- (NSInteger)numberOfSectionsInCollectionView:(__unused UICollectionView *)collectionView {
    return 2;
}

- (NSInteger)collectionView:(__unused UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return section == 0 ? (NSInteger)self.favorites.count + 1 : (NSInteger)self.recents.count; // + "Add Favorite"
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
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
        } else {
            cell.nameLabel.text = BrowserLocalized(@"Add Favorite");
            cell.letterLabel.hidden = YES;
            cell.symbolView.hidden = NO;
            cell.symbolView.image = [UIImage systemImageNamed:@"plus" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:60.0 weight:UIImageSymbolWeightSemibold]];
            cell.tile.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
            cell.badgeLabel.hidden = YES;
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
    [cell applyFocused:cell.isFocused];
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    BrowserStartHeaderView *header = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"header" forIndexPath:indexPath];
    header.label.text = indexPath.section == 0 ? BrowserLocalized(@"Favorites") : BrowserLocalized(@"Recently Visited");
    return header;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(__unused UICollectionViewLayout *)layout referenceSizeForHeaderInSection:(NSInteger)section {
    if (section == 1 && self.recents.count == 0) {
        return CGSizeZero;
    }
    return CGSizeMake(CGRectGetWidth(collectionView.bounds), section == 0 ? 80.0 : 110.0);
}

- (UIEdgeInsets)collectionView:(__unused UICollectionView *)collectionView layout:(__unused UICollectionViewLayout *)layout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(0.0, kStartSideInset, section == 0 ? 10.0 : 80.0, kStartSideInset);
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(__unused UICollectionViewLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat available = CGRectGetWidth(collectionView.bounds) - kStartSideInset * 2.0;
    if (indexPath.section == 0) {
        return CGSizeMake(floor((available - 5.0 * 40.0) / 6.0), 280.0);
    }
    return CGSizeMake(floor((available - 2.0 * 40.0) / 3.0), 360.0);
}

- (void)collectionView:(__unused UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
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
    NSInteger index = [self focusedFavoriteIndex];
    if (index != NSNotFound) {
        [self presentOptionsForFavoriteAtIndex:(NSUInteger)index];
    }
}

- (void)presentOptionsForFavoriteAtIndex:(NSUInteger)index {
    NSArray<NSString *> *favorite = self.favorites[index];
    NSString *URLString = favorite[0];
    NSString *name = favorite[1].length > 0 ? favorite[1] : StartHostForURL(URLString);
    BOOL webApp = [BrowserStartPageViewController isWebAppURL:URLString];
    BOOL launches = [[BrowserStartPageViewController launchWebAppURL] isEqualToString:URLString];

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:name message:URLString preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [sheet addAction:[UIAlertAction actionWithTitle:BrowserLocalized(@"Open as Web App") style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [weakSelf closeAndOpenURL:URLString asWebApp:YES];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:(webApp ? BrowserLocalized(@"Always Open as Web App: On") : BrowserLocalized(@"Always Open as Web App: Off"))
                                              style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [weakSelf setURL:URLString inList:kStartWebAppsKey enabled:!webApp];
        if (webApp && launches) {
            [NSUserDefaults.standardUserDefaults removeObjectForKey:kStartLaunchWebAppKey];
        }
        [weakSelf reloadData];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:(launches ? BrowserLocalized(@"Open When Orbrisa Starts: On") : BrowserLocalized(@"Open When Orbrisa Starts: Off"))
                                              style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        if (launches) {
            [NSUserDefaults.standardUserDefaults removeObjectForKey:kStartLaunchWebAppKey];
        } else {
            [NSUserDefaults.standardUserDefaults setObject:URLString forKey:kStartLaunchWebAppKey];
            [weakSelf setURL:URLString inList:kStartWebAppsKey enabled:YES]; // it starts as a web app
        }
        [weakSelf reloadData];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:BrowserLocalized(@"Rename") style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        [weakSelf presentRenameForFavoriteAtIndex:index];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:BrowserLocalized(@"Remove") style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        NSMutableArray *favorites = [weakSelf.favorites mutableCopy];
        if (index < favorites.count) {
            [favorites removeObjectAtIndex:index];
        }
        [weakSelf setURL:URLString inList:kStartWebAppsKey enabled:NO];
        if (launches) {
            [NSUserDefaults.standardUserDefaults removeObjectForKey:kStartLaunchWebAppKey];
        }
        [weakSelf saveFavorites:favorites];
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:BrowserLocalized(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:sheet animated:YES completion:nil];
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
    if (press.type == UIPressTypeMenu || press.type == UIPressTypePlayPause) {
        return;
    }
    [super pressesBegan:presses withEvent:event];
}

- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    UIPress *press = presses.anyObject;
    if (press.type == UIPressTypeMenu) {
        [self closeThen:nil];
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
