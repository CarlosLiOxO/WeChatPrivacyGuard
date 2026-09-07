#import "ApplicationCatalog.h"

static NSString *const GuardBundleIdentifier = @"com.carlosli.WeChatPrivacyGuard";
static NSString *const WeChatBundleIdentifier = @"com.tencent.xinWeChat";

@interface ApplicationCatalog ()
@property(nonatomic, copy) NSArray<NSURL *> *searchURLs;
@property(nonatomic, copy) NSSet<NSString *> *excludedBundleIdentifiers;
@end

@implementation ApplicationCatalog

- (instancetype)init {
    NSArray<NSURL *> *roots = @[
        [NSURL fileURLWithPath:@"/Applications" isDirectory:YES],
        [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Applications"] isDirectory:YES],
        [NSURL fileURLWithPath:@"/System/Applications" isDirectory:YES],
    ];
    return [self initWithSearchURLs:roots
          excludedBundleIdentifiers:[NSSet setWithObjects:GuardBundleIdentifier, WeChatBundleIdentifier, nil]];
}

- (instancetype)initWithSearchURLs:(NSArray<NSURL *> *)searchURLs
          excludedBundleIdentifiers:(NSSet<NSString *> *)excludedBundleIdentifiers {
    self = [super init];
    if (self) {
        _searchURLs = [searchURLs copy];
        _excludedBundleIdentifiers = [excludedBundleIdentifiers copy];
    }
    return self;
}

- (NSArray<ProtectedApplication *> *)scanApplications {
    NSMutableDictionary<NSString *, ProtectedApplication *> *applicationsByID = [NSMutableDictionary dictionary];
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSArray<NSURLResourceKey> *keys = @[NSURLIsDirectoryKey, NSURLIsPackageKey, NSURLIsHiddenKey];
    NSSet<NSString *> *knownPackageExtensions = [NSSet setWithObjects:
        @"bundle", @"plugin", @"framework", @"prefpane", @"appex", @"xpc", @"pkg", nil];

    for (NSURL *rootURL in self.searchURLs) {
        BOOL isDirectory = NO;
        if (![fileManager fileExistsAtPath:rootURL.path isDirectory:&isDirectory] || !isDirectory) continue;

        NSDirectoryEnumerator<NSURL *> *enumerator =
            [fileManager enumeratorAtURL:rootURL
              includingPropertiesForKeys:keys
                                 options:NSDirectoryEnumerationSkipsHiddenFiles
                            errorHandler:^BOOL(NSURL *url, NSError *error) {
                                return YES;
                            }];

        for (NSURL *url in enumerator) {
            NSNumber *isPackage = nil;
            [url getResourceValue:&isPackage forKey:NSURLIsPackageKey error:nil];
            BOOL isApplication = [url.pathExtension caseInsensitiveCompare:@"app"] == NSOrderedSame;
            BOOL hasKnownPackageExtension = [knownPackageExtensions containsObject:url.pathExtension.lowercaseString];
            if (!isApplication && (isPackage.boolValue || hasKnownPackageExtension)) {
                [enumerator skipDescendants];
                continue;
            }
            if (!isApplication) continue;
            [enumerator skipDescendants];

            NSBundle *bundle = [NSBundle bundleWithURL:url];
            NSString *bundleIdentifier = bundle.bundleIdentifier;
            if (bundleIdentifier.length == 0 ||
                [self.excludedBundleIdentifiers containsObject:bundleIdentifier] ||
                applicationsByID[bundleIdentifier]) {
                continue;
            }

            NSDictionary *info = bundle.infoDictionary;
            if ([info[@"LSBackgroundOnly"] boolValue] || [info[@"LSUIElement"] boolValue]) continue;

            NSDictionary *localizedInfo = bundle.localizedInfoDictionary;
            NSString *displayName = localizedInfo[@"CFBundleDisplayName"]
                ?: localizedInfo[@"CFBundleName"]
                ?: info[@"CFBundleDisplayName"]
                ?: info[@"CFBundleName"]
                ?: url.URLByDeletingPathExtension.lastPathComponent;
            if (displayName.length == 0) continue;

            applicationsByID[bundleIdentifier] = [[ProtectedApplication alloc]
                initWithBundleIdentifier:bundleIdentifier
                             displayName:displayName
                          applicationURL:url];
        }
    }

    return [applicationsByID.allValues sortedArrayUsingComparator:^NSComparisonResult(
        ProtectedApplication *left,
        ProtectedApplication *right
    ) {
        return [left.displayName localizedStandardCompare:right.displayName];
    }];
}

@end
