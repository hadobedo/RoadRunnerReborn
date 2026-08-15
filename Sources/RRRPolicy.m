#import "RRRPolicy.h"

static NSSet *RRRNeverPreserveSet(void) {
    static NSSet *set;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        set = [NSSet setWithArray:@[
            @"com.apple.Spotlight",
            @"com.apple.mobilephone",
            @"com.apple.InCallService",
        ]];
    });
    return set;
}

BOOL RRRValidBundleID(NSString *value) {
    if (![value isKindOfClass:NSString.class] || value.length == 0 || value.length > 255) return NO;
    NSArray *parts = [value componentsSeparatedByString:@"."];
    if (parts.count < 2) return NO;
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"];
    for (NSString *part in parts) {
        if (part.length == 0 || [part rangeOfCharacterFromSet:[allowed invertedSet]].location != NSNotFound) return NO;
    }
    return YES;
}

BOOL RRRNeverPreserveBundleID(NSString *bundleIdentifier) {
    return [RRRNeverPreserveSet() containsObject:bundleIdentifier];
}

@implementation RRRPreferencesSnapshot
- (instancetype)initWithEnabled:(BOOL)enabled preserveNowPlaying:(BOOL)preserveNowPlaying preserveOtherApps:(BOOL)preserveOtherApps whitelist:(BOOL)whitelist loggingEnabled:(BOOL)loggingEnabled listedApps:(NSSet<NSString *> *)listedApps appUniverse:(NSSet<NSString *> *)appUniverse {
    if ((self = [super init])) {
        _enabled = enabled;
        _preserveNowPlaying = preserveNowPlaying;
        _preserveOtherApps = preserveOtherApps;
        _whitelist = whitelist;
        _loggingEnabled = loggingEnabled;
        _listedApps = [listedApps copy] ?: [NSSet set];
        _appUniverse = [appUniverse copy] ?: [NSSet set];
    }
    return self;
}
- (BOOL)preservesBundleIdentifier:(NSString *)bundleIdentifier {
    if (!_enabled || !_preserveOtherApps || !RRRValidBundleID(bundleIdentifier) || RRRNeverPreserveBundleID(bundleIdentifier)) return NO;
    if (_whitelist) return [_listedApps containsObject:bundleIdentifier];
    return [_appUniverse containsObject:bundleIdentifier] && ![_listedApps containsObject:bundleIdentifier];
}
@end
