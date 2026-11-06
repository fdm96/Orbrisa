//
//  BrowserWallpaperViewController.m
//  Orbrisa
//
//  Orbrisa by Fabio Di Marco (di marcostudio.) with Claude (Anthropic) – next stage reached on 05/11/2026
//

#import "BrowserWallpaperViewController.h"
#import "BrowserLocalization.h"
#import "BrowserLog.h"

static NSString * const kWallpaperInfoKey = @"BrowserStartWallpaper"; // {id, author}
static CGFloat const kWallpaperInset = 60.0;
static CGFloat const kWallpaperRadius = 48.0;
static NSInteger const kWallpaperPageSize = 40;

static NSURL *WallpaperFileURL(void) {
    NSURL *folder = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
    [NSFileManager.defaultManager createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:nil];
    return [folder URLByAppendingPathComponent:@"OrbrisaWallpaper.jpg"];
}

static NSCache<NSString *, UIImage *> *WallpaperThumbnails(void) {
    static NSCache *cache;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [NSCache new];
        cache.countLimit = 200;
    });
    return cache;
}

#pragma mark - Cell

@interface BrowserWallpaperCell : UICollectionViewCell
@property (nonatomic) UIImageView *imageView;
@property (nonatomic) UILabel *authorLabel;
@property (nonatomic) UIImageView *checkView;
@property (nonatomic) UIActivityIndicatorView *spinner;
@property (nonatomic, copy) NSString *photoID;
@end

@implementation BrowserWallpaperCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.clipsToBounds = NO;
        _imageView = [UIImageView new];
        _imageView.translatesAutoresizingMaskIntoConstraints = NO;
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
        _imageView.layer.cornerRadius = 22.0;
        _imageView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
        [self.contentView addSubview:_imageView];

        _authorLabel = [UILabel new];
        _authorLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _authorLabel.font = [UIFont systemFontOfSize:20.0 weight:UIFontWeightMedium];
        _authorLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.75];
        _authorLabel.textAlignment = NSTextAlignmentCenter;
        [self.contentView addSubview:_authorLabel];

        _checkView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.circle.fill"
            withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:36.0 weight:UIImageSymbolWeightBold]]];
        _checkView.translatesAutoresizingMaskIntoConstraints = NO;
        _checkView.tintColor = UIColor.systemBlueColor;
        _checkView.backgroundColor = UIColor.whiteColor;
        _checkView.layer.cornerRadius = 20.0;
        _checkView.clipsToBounds = YES;
        _checkView.hidden = YES;
        [self.contentView addSubview:_checkView];

        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
        _spinner.translatesAutoresizingMaskIntoConstraints = NO;
        _spinner.color = UIColor.whiteColor;
        _spinner.hidesWhenStopped = YES;
        [self.contentView addSubview:_spinner];

        [NSLayoutConstraint activateConstraints:@[
            [_imageView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [_imageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_imageView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [_imageView.heightAnchor constraintEqualToAnchor:_imageView.widthAnchor multiplier:9.0 / 16.0],
            [_authorLabel.topAnchor constraintEqualToAnchor:_imageView.bottomAnchor constant:10.0],
            [_authorLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_authorLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [_checkView.topAnchor constraintEqualToAnchor:_imageView.topAnchor constant:12.0],
            [_checkView.trailingAnchor constraintEqualToAnchor:_imageView.trailingAnchor constant:-12.0],
            [_checkView.widthAnchor constraintEqualToConstant:40.0],
            [_checkView.heightAnchor constraintEqualToConstant:40.0],
            [_spinner.centerXAnchor constraintEqualToAnchor:_imageView.centerXAnchor],
            [_spinner.centerYAnchor constraintEqualToAnchor:_imageView.centerYAnchor],
        ]];
        [self applyFocused:NO];
    }
    return self;
}

- (void)applyFocused:(BOOL)focused {
    self.transform = focused ? CGAffineTransformMakeScale(1.08, 1.08) : CGAffineTransformIdentity;
    self.imageView.layer.borderWidth = focused ? 5.0 : 0.0;
    self.imageView.layer.borderColor = UIColor.whiteColor.CGColor;
    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowOpacity = focused ? 0.5 : 0.0;
    self.layer.shadowRadius = 20.0;
    self.layer.shadowOffset = CGSizeMake(0.0, 12.0);
    self.authorLabel.textColor = focused ? UIColor.whiteColor : [UIColor colorWithWhite:1.0 alpha:0.75];
}

- (void)didUpdateFocusInContext:(UIFocusUpdateContext *)context withAnimationCoordinator:(UIFocusAnimationCoordinator *)coordinator {
    [super didUpdateFocusInContext:context withAnimationCoordinator:coordinator];
    BOOL focused = (context.nextFocusedView == self);
    [coordinator addCoordinatedAnimations:^{ [self applyFocused:focused]; } completion:nil];
}

@end

#pragma mark - Picker

@interface BrowserWallpaperViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property (nonatomic) NSMutableArray<NSDictionary *> *photos; // {id, author}
@property (nonatomic) NSInteger nextPage;
@property (nonatomic) BOOL loading;
@property (nonatomic) BOOL reachedEnd;
@property (nonatomic) BOOL choosing;
@property (nonatomic) UICollectionView *collectionView;
@property (nonatomic) UILabel *statusLabel;
@property (nonatomic) UIView *windowView;
@property (nonatomic) BOOL closing;
@end

@implementation BrowserWallpaperViewController

+ (UIImage *)currentWallpaper {
    if ([NSUserDefaults.standardUserDefaults dictionaryForKey:kWallpaperInfoKey] == nil) {
        return nil;
    }
    NSData *data = [NSData dataWithContentsOfURL:WallpaperFileURL()];
    return data.length > 0 ? [UIImage imageWithData:data] : nil;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
        _photos = [NSMutableArray array];
        _nextPage = 1;
    }
    return self;
}

- (UIVisualEffect *)glassEffect {
    Class glassClass = NSClassFromString(@"UIGlassEffect");
    if (glassClass != Nil) {
        id glass = [[glassClass alloc] init];
        if ([glass isKindOfClass:[UIVisualEffect class]]) {
            return glass;
        }
    }
    return [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];

    // A floating glass window, like the feeds.
    UIVisualEffectView *window = [[UIVisualEffectView alloc] initWithEffect:[self glassEffect]];
    window.translatesAutoresizingMaskIntoConstraints = NO;
    window.layer.cornerRadius = kWallpaperRadius;
    window.clipsToBounds = YES;
    window.layer.borderWidth = 1.5;
    window.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.28].CGColor;
    window.contentView.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.55];
    [self.view addSubview:window];
    self.windowView = window;

    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = BrowserLocalized(@"Wallpaper");
    title.font = [UIFont systemFontOfSize:44.0 weight:UIFontWeightBold];
    title.textColor = UIColor.whiteColor;
    [window.contentView addSubview:title];

    UILabel *subtitle = [UILabel new];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = BrowserLocalized(@"Photos from Unsplash – shown blurred behind the start page");
    subtitle.font = [UIFont systemFontOfSize:23.0 weight:UIFontWeightMedium];
    subtitle.textColor = [UIColor colorWithWhite:1.0 alpha:0.6];
    [window.contentView addSubview:subtitle];

    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.minimumInteritemSpacing = 40.0;
    layout.minimumLineSpacing = 50.0;
    layout.sectionInset = UIEdgeInsetsMake(30.0, 50.0, 60.0, 50.0);
    UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    collectionView.backgroundColor = UIColor.clearColor;
    collectionView.clipsToBounds = YES;
    collectionView.remembersLastFocusedIndexPath = YES;
    collectionView.dataSource = self;
    collectionView.delegate = self;
    [collectionView registerClass:[BrowserWallpaperCell class] forCellWithReuseIdentifier:@"photo"];
    [window.contentView addSubview:collectionView];
    self.collectionView = collectionView;

    UILabel *status = [UILabel new];
    status.translatesAutoresizingMaskIntoConstraints = NO;
    status.font = [UIFont systemFontOfSize:26.0 weight:UIFontWeightMedium];
    status.textColor = [UIColor colorWithWhite:1.0 alpha:0.6];
    status.textAlignment = NSTextAlignmentCenter;
    status.numberOfLines = 0;
    status.text = BrowserLocalized(@"Loading photos …");
    [window.contentView addSubview:status];
    self.statusLabel = status;

    [NSLayoutConstraint activateConstraints:@[
        [window.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:kWallpaperInset],
        [window.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-kWallpaperInset],
        [window.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:kWallpaperInset],
        [window.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-kWallpaperInset],
        [title.leadingAnchor constraintEqualToAnchor:window.contentView.leadingAnchor constant:60.0],
        [title.topAnchor constraintEqualToAnchor:window.contentView.topAnchor constant:44.0],
        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:6.0],
        [collectionView.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:10.0],
        [collectionView.leadingAnchor constraintEqualToAnchor:window.contentView.leadingAnchor],
        [collectionView.trailingAnchor constraintEqualToAnchor:window.contentView.trailingAnchor],
        [collectionView.bottomAnchor constraintEqualToAnchor:window.contentView.bottomAnchor],
        [status.centerXAnchor constraintEqualToAnchor:window.contentView.centerXAnchor],
        [status.centerYAnchor constraintEqualToAnchor:window.contentView.centerYAnchor],
        [status.widthAnchor constraintLessThanOrEqualToConstant:900.0],
    ]];
    // Back: our own recognizer, so tvOS doesn't close the start page underneath as well.
    UITapGestureRecognizer *back = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(backPressed)];
    back.allowedPressTypes = @[@(UIPressTypeMenu)];
    [self.view addGestureRecognizer:back];
    [self loadNextPage];
}

- (void)backPressed {
    [self closeChanged:NO];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout;
    CGFloat available = CGRectGetWidth(self.collectionView.bounds) - layout.sectionInset.left - layout.sectionInset.right;
    CGFloat width = floor((available - 3.0 * layout.minimumInteritemSpacing) / 4.0);
    if (width > 0.0 && fabs(layout.itemSize.width - width) > 0.5) {
        layout.itemSize = CGSizeMake(width, ceil(width * 9.0 / 16.0) + 44.0);
        [layout invalidateLayout];
    }
}

#pragma mark Loading

- (void)loadNextPage {
    if (self.loading || self.reachedEnd) {
        return;
    }
    self.loading = YES;
    NSString *address = [NSString stringWithFormat:@"https://picsum.photos/v2/list?page=%ld&limit=%ld", (long)self.nextPage, (long)kWallpaperPageSize];
    __weak typeof(self) weakSelf = self;
    [[NSURLSession.sharedSession dataTaskWithURL:[NSURL URLWithString:address] completionHandler:^(NSData *data, __unused NSURLResponse *response, NSError *error) {
        NSArray *list = data.length > 0 ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        NSMutableArray *photos = [NSMutableArray array];
        if ([list isKindOfClass:[NSArray class]]) {
            for (NSDictionary *entry in list) {
                if (![entry isKindOfClass:[NSDictionary class]]) {
                    continue;
                }
                NSString *photoID = [entry[@"id"] description];
                NSNumber *width = entry[@"width"];
                NSNumber *height = entry[@"height"];
                // Landscape photos only – they fill the TV.
                if (photoID.length > 0 && (![width isKindOfClass:[NSNumber class]] || width.doubleValue >= height.doubleValue)) {
                    [photos addObject:@{@"id": photoID, @"author": [entry[@"author"] description] ?: @""}];
                }
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            BrowserWallpaperViewController *strongSelf = weakSelf;
            if (strongSelf == nil) {
                return;
            }
            strongSelf.loading = NO;
            if (error != nil || ![list isKindOfClass:[NSArray class]]) {
                BrowserLog(@"[Wallpaper] list failed: %@", error.localizedDescription);
                if (strongSelf.photos.count == 0) {
                    strongSelf.statusLabel.text = BrowserLocalized(@"The photos could not be loaded. Check the internet connection and try again.");
                }
                return;
            }
            strongSelf.reachedEnd = (list.count == 0);
            strongSelf.nextPage += 1;
            [strongSelf.photos addObjectsFromArray:photos];
            strongSelf.statusLabel.hidden = YES;
            [strongSelf.collectionView reloadData];
            if (photos.count == 0 && !strongSelf.reachedEnd) {
                [strongSelf loadNextPage]; // only portrait photos on this page – take the next one
            }
        });
    }] resume];
}

- (void)loadThumbnailForCell:(BrowserWallpaperCell *)cell photoID:(NSString *)photoID {
    UIImage *cached = [WallpaperThumbnails() objectForKey:photoID];
    if (cached != nil) {
        cell.imageView.image = cached;
        return;
    }
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"https://picsum.photos/id/%@/640/360", photoID]];
    __weak BrowserWallpaperCell *weakCell = cell;
    [[NSURLSession.sharedSession dataTaskWithURL:URL completionHandler:^(NSData *data, __unused NSURLResponse *response, __unused NSError *error) {
        UIImage *image = data.length > 0 ? [UIImage imageWithData:data] : nil;
        if (image == nil) {
            return;
        }
        [WallpaperThumbnails() setObject:image forKey:photoID];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([weakCell.photoID isEqualToString:photoID]) {
                weakCell.imageView.image = image;
            }
        });
    }] resume];
}

#pragma mark Collection

- (NSInteger)collectionView:(__unused UICollectionView *)collectionView numberOfItemsInSection:(__unused NSInteger)section {
    return self.photos.count > 0 ? (NSInteger)self.photos.count + 1 : 0; // first: "No Wallpaper"
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    BrowserWallpaperCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"photo" forIndexPath:indexPath];
    [cell.spinner stopAnimating];
    NSString *currentID = [NSUserDefaults.standardUserDefaults dictionaryForKey:kWallpaperInfoKey][@"id"];
    if (indexPath.item == 0) {
        cell.photoID = @"";
        cell.imageView.image = [UIImage systemImageNamed:@"nosign" withConfiguration:
            [UIImageSymbolConfiguration configurationWithPointSize:60.0 weight:UIImageSymbolWeightSemibold]];
        cell.imageView.contentMode = UIViewContentModeCenter;
        cell.imageView.tintColor = [UIColor colorWithWhite:1.0 alpha:0.6];
        cell.authorLabel.text = BrowserLocalized(@"No Wallpaper");
        cell.checkView.hidden = (currentID != nil);
        return cell;
    }
    NSDictionary *photo = self.photos[(NSUInteger)indexPath.item - 1];
    cell.photoID = photo[@"id"];
    cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
    cell.imageView.image = nil;
    cell.authorLabel.text = photo[@"author"];
    cell.checkView.hidden = ![photo[@"id"] isEqualToString:currentID];
    [self loadThumbnailForCell:cell photoID:photo[@"id"]];
    return cell;
}

- (void)collectionView:(__unused UICollectionView *)collectionView willDisplayCell:(__unused UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.item >= (NSInteger)self.photos.count - 8) {
        [self loadNextPage]; // more photos as you scroll down
    }
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (self.choosing) {
        return;
    }
    if (indexPath.item == 0) {
        [NSUserDefaults.standardUserDefaults removeObjectForKey:kWallpaperInfoKey];
        [NSFileManager.defaultManager removeItemAtURL:WallpaperFileURL() error:nil];
        [self closeChanged:YES];
        return;
    }
    NSDictionary *photo = self.photos[(NSUInteger)indexPath.item - 1];
    BrowserWallpaperCell *cell = (BrowserWallpaperCell *)[collectionView cellForItemAtIndexPath:indexPath];
    [cell.spinner startAnimating];
    self.choosing = YES;
    // The full TV size; blurred later, so 1920 × 1080 is plenty.
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"https://picsum.photos/id/%@/1920/1080", photo[@"id"]]];
    __weak typeof(self) weakSelf = self;
    [[NSURLSession.sharedSession dataTaskWithURL:URL completionHandler:^(NSData *data, __unused NSURLResponse *response, NSError *error) {
        BOOL ok = data.length > 0 && [UIImage imageWithData:data] != nil && [data writeToURL:WallpaperFileURL() atomically:YES];
        dispatch_async(dispatch_get_main_queue(), ^{
            BrowserWallpaperViewController *strongSelf = weakSelf;
            [cell.spinner stopAnimating];
            strongSelf.choosing = NO;
            if (!ok) {
                BrowserLog(@"[Wallpaper] download failed: %@", error.localizedDescription);
                return;
            }
            [NSUserDefaults.standardUserDefaults setObject:photo forKey:kWallpaperInfoKey];
            [strongSelf closeChanged:YES];
        });
    }] resume];
}

- (void)closeChanged:(BOOL)changed {
    if (self.closing) {
        return;
    }
    self.closing = YES;
    void (^wallpaperChanged)(void) = changed ? self.wallpaperChanged : nil;
    [self dismissViewControllerAnimated:YES completion:^{
        if (wallpaperChanged != nil) {
            wallpaperChanged();
        }
    }];
}

#pragma mark Remote

- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    if (presses.anyObject.type == UIPressTypeMenu || presses.anyObject.type == UIPressTypePlayPause) {
        return;
    }
    [super pressesBegan:presses withEvent:event];
}

- (void)pressesEnded:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    if (presses.anyObject.type == UIPressTypeMenu || presses.anyObject.type == UIPressTypePlayPause) {
        [self closeChanged:NO];
        return;
    }
    [super pressesEnded:presses withEvent:event];
}

@end
