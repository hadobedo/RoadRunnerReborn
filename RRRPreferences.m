#import "RRRPreferences.h"
#import <notify.h>

NSString *const RRRPreferencesFilePath = @"/var/mobile/Library/Preferences/com.nicksworks.roadrunnerreborn.preferences.plist";
NSString *const RRRPreferencesChangedNotification = @"com.nicksworks.roadrunnerreborn.settings-changed";
NSString *const RRRPreferencesEnabledKey = @"enabled";
NSString *const RRRPreferencesNowPlayingKey = @"preserveNowPlaying";
NSString *const RRRPreferencesOtherAppsKey = @"preserveOtherApps";
NSString *const RRRPreferencesWhitelistKey = @"isWhitelist";
NSString *const RRRPreferencesListedAppsKey = @"listedApps";
NSString *const RRRPreferencesLoggingKey = @"loggingEnabled";
NSString *const RRRPreferencesUniverseKey = @"appUniverse";

static BOOL RRRLoggingEnabledState = NO;

BOOL RRRLoggingEnabled(void) {
    return RRRLoggingEnabledState;
}

// Call UI must never survive a SpringBoard replacement: its remote view
// connection dies with SpringBoard and the process is left frozen. Spotlight
// was already excluded from list preservation; this set centralizes the
// policy so both the list path and the now-playing path honor it. Identifiers
// are the documented iOS 15-17 candidates; call UI on these releases is
// com.apple.InCallService hosted by com.apple.mobilephone.
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

BOOL RRRNeverPreserveBundleID(NSString *bundleIdentifier) {
    return [RRRNeverPreserveSet() containsObject:bundleIdentifier];
}

static BOOL RRRValidBundleID(NSString *value) {
    if (![value isKindOfClass:NSString.class] || value.length == 0 || value.length > 255) return NO;
    NSArray *parts = [value componentsSeparatedByString:@"."];
    if (parts.count < 2) return NO;
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"];
    for (NSString *part in parts) {
        if (part.length == 0 || [part rangeOfCharacterFromSet:[allowed invertedSet]].location != NSNotFound) return NO;
    }
    return YES;
}

// The applications visible to the system (the same set AltList shows in the
// preference list). Blacklist mode must be evaluated against this universe
// rather than against every bundle ID that exists at runtime: an invisible
// system service can never be seen or toggled by the user, so it must never
// be preserved.
static NSSet<NSString *> *RRRVisibleAppBundleIDs(void) {
    NSMutableSet *result = [NSMutableSet set];
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (!workspaceClass) return result;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    id workspace = [workspaceClass performSelector:@selector(defaultWorkspace)];
    NSArray *applications = [workspace performSelector:@selector(allApplications)];
    for (id proxy in applications) {
        NSString *bundleID = [proxy performSelector:@selector(bundleIdentifier)];
        if (RRRValidBundleID(bundleID)) [result addObject:bundleID];
    }
#pragma clang diagnostic pop
    return result;
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
    // Blacklist mode: only applications that were visible in the list and are
    // not toggled are preserved. Apps outside the captured universe (invisible
    // system services, apps installed after the last capture) are never
    // preserved; an empty universe fails closed and preserves nothing.
    return [_appUniverse containsObject:bundleIdentifier] && ![_listedApps containsObject:bundleIdentifier];
}
@end

RRRPreferencesSnapshot *RRRPreferencesLoad(void) {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:RRRPreferencesFilePath];
    RRRPreferencesSnapshot *snapshot;
    if (![dict isKindOfClass:NSDictionary.class]) {
        snapshot = [[RRRPreferencesSnapshot alloc] initWithEnabled:YES preserveNowPlaying:YES preserveOtherApps:NO whitelist:YES loggingEnabled:NO listedApps:[NSSet set] appUniverse:[NSSet set]];
    } else {
        id enabledValue = dict[RRRPreferencesEnabledKey];
        id nowPlaying = dict[RRRPreferencesNowPlayingKey];
        id otherApps = dict[RRRPreferencesOtherAppsKey];
        id whitelist = dict[RRRPreferencesWhitelistKey];
        id listed = dict[RRRPreferencesListedAppsKey];
        id logging = dict[RRRPreferencesLoggingKey];
        id universe = dict[RRRPreferencesUniverseKey];
        BOOL enabled = [enabledValue isKindOfClass:NSNumber.class] ? [enabledValue boolValue] : YES;
        BOOL preserveNowPlaying = [nowPlaying isKindOfClass:NSNumber.class] ? [nowPlaying boolValue] : YES;
        BOOL preserveOtherApps = [otherApps isKindOfClass:NSNumber.class] ? [otherApps boolValue] : NO;
        BOOL validWhitelist = !whitelist || [whitelist isKindOfClass:NSNumber.class];
        BOOL validList = !listed || [listed isKindOfClass:NSArray.class];
        NSArray *rawList = [listed isKindOfClass:NSArray.class] ? listed : @[];
        NSMutableSet *clean = [NSMutableSet set];
        for (id value in rawList) if (RRRValidBundleID(value)) [clean addObject:value];
        NSArray *rawUniverse = [universe isKindOfClass:NSArray.class] ? universe : @[];
        NSMutableSet *cleanUniverse = [NSMutableSet set];
        for (id value in rawUniverse) if (RRRValidBundleID(value)) [cleanUniverse addObject:value];
        snapshot = [[RRRPreferencesSnapshot alloc] initWithEnabled:enabled
                                                   preserveNowPlaying:preserveNowPlaying
                                                           preserveOtherApps:(validWhitelist && validList && preserveOtherApps)
                                                                   whitelist:(whitelist ? [whitelist boolValue] : YES)
                                                         loggingEnabled:([logging isKindOfClass:NSNumber.class] ? [logging boolValue] : NO)
                                                               listedApps:clean
                                                           appUniverse:cleanUniverse];
    }
    RRRLoggingEnabledState = snapshot.loggingEnabled;
    return snapshot;
}

BOOL RRRPreferencesWrite(BOOL enabled, BOOL preserveNowPlaying, BOOL preserveOtherApps, BOOL whitelist, BOOL loggingEnabled, NSArray<NSString *> *listedApps) {
    NSMutableSet *clean = [NSMutableSet set];
    for (id value in listedApps) if (RRRValidBundleID(value)) [clean addObject:value];
    NSDictionary *dict = @{ RRRPreferencesEnabledKey: @(enabled),
                            RRRPreferencesNowPlayingKey: @(preserveNowPlaying),
                            RRRPreferencesOtherAppsKey: @(preserveOtherApps),
                            RRRPreferencesWhitelistKey: @(whitelist),
                            RRRPreferencesLoggingKey: @(loggingEnabled),
                            RRRPreferencesListedAppsKey: clean.allObjects,
                            RRRPreferencesUniverseKey: RRRVisibleAppBundleIDs().allObjects };
    if (![dict writeToFile:RRRPreferencesFilePath atomically:YES]) return NO;
    notify_post(RRRPreferencesChangedNotification.UTF8String);
    return YES;
}

BOOL RRRPreferencesUpdateAppUniverse(void) {
    NSDictionary *current = [NSDictionary dictionaryWithContentsOfFile:RRRPreferencesFilePath];
    NSSet *universe = RRRVisibleAppBundleIDs();
    // Never erase a known universe because enumeration failed in this process.
    if (universe.count == 0) return NO;
    NSArray *existing = [current[RRRPreferencesUniverseKey] isKindOfClass:NSArray.class] ? current[RRRPreferencesUniverseKey] : @[];
    if ([[NSSet setWithArray:existing] isEqualToSet:universe]) return NO;
    NSMutableDictionary *updated = current ? [current mutableCopy] : [NSMutableDictionary dictionary];
    updated[RRRPreferencesUniverseKey] = universe.allObjects;
    if (![updated writeToFile:RRRPreferencesFilePath atomically:YES]) return NO;
    notify_post(RRRPreferencesChangedNotification.UTF8String);
    return YES;
}
