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
NSString *const RRRPreferencesSimultaneousAudioKey = @"simultaneousAudioEnabled";
NSString *const RRRPreferencesAudioWhitelistKey = @"audioIsWhitelist";
NSString *const RRRPreferencesAudioListedAppsKey = @"audioListedApps";
NSString *const RRRPreferencesUniverseKey = @"appUniverse";

static BOOL RRRLoggingEnabledState = NO;

BOOL RRRLoggingEnabled(void) {
    return RRRLoggingEnabledState;
}

static id RRRCopyPreferenceValue(NSString *key) {
    return CFBridgingRelease(CFPreferencesCopyAppValue(
        (__bridge CFStringRef)key,
        CFSTR("com.nicksworks.roadrunnerreborn.preferences")
    ));
}

BOOL RRRSimultaneousAudioEnabled(void) {
    id value = RRRCopyPreferenceValue(RRRPreferencesSimultaneousAudioKey);
    return [value isKindOfClass:NSNumber.class] ? [value boolValue] : NO;
}

BOOL RRRAudioPolicyEnabled(void) {
    id masterValue = RRRCopyPreferenceValue(RRRPreferencesEnabledKey);
    BOOL masterEnabled = [masterValue isKindOfClass:NSNumber.class]
        ? [masterValue boolValue]
        : YES;
    return masterEnabled && RRRSimultaneousAudioEnabled();
}

BOOL RRRAudioWhitelistEnabled(void) {
    id value = RRRCopyPreferenceValue(RRRPreferencesAudioWhitelistKey);
    return [value isKindOfClass:NSNumber.class] ? [value boolValue] : YES;
}

NSSet<NSString *> *RRRAudioListedApplications(void) {
    id value = RRRCopyPreferenceValue(RRRPreferencesAudioListedAppsKey);
    if (![value isKindOfClass:NSArray.class]) return [NSSet set];
    NSMutableSet *clean = [NSMutableSet set];
    for (id bundleIdentifier in value) {
        if (RRRValidBundleID(bundleIdentifier)) [clean addObject:bundleIdentifier];
    }
    return clean;
}

BOOL RRRAudioAllowsBundleIdentifier(NSString *bundleIdentifier) {
    if (!RRRAudioPolicyEnabled() || !RRRValidBundleID(bundleIdentifier) ||
        [bundleIdentifier hasPrefix:@"com.apple."]) return NO;
    BOOL listed = [RRRAudioListedApplications() containsObject:bundleIdentifier];
    return RRRAudioWhitelistEnabled() ? listed : !listed;
}

static BOOL RRRSetAudioPreferenceValue(NSString *key, id value) {
    CFPreferencesSetAppValue(
        (__bridge CFStringRef)key,
        (__bridge CFPropertyListRef)value,
        CFSTR("com.nicksworks.roadrunnerreborn.preferences")
    );
    if (!CFPreferencesAppSynchronize(CFSTR("com.nicksworks.roadrunnerreborn.preferences"))) return NO;
    notify_post(RRRPreferencesChangedNotification.UTF8String);
    return YES;
}

BOOL RRRPreferencesSetSimultaneousAudioEnabled(BOOL enabled) {
    return RRRSetAudioPreferenceValue(RRRPreferencesSimultaneousAudioKey, @(enabled));
}

BOOL RRRPreferencesSetAudioWhitelistEnabled(BOOL whitelist) {
    return RRRSetAudioPreferenceValue(RRRPreferencesAudioWhitelistKey, @(whitelist));
}

BOOL RRRPreferencesSetAudioListedApplications(NSArray<NSString *> *bundleIdentifiers) {
    NSMutableSet *clean = [NSMutableSet set];
    for (id bundleIdentifier in bundleIdentifiers) {
        if (RRRValidBundleID(bundleIdentifier)) [clean addObject:bundleIdentifier];
    }
    return RRRSetAudioPreferenceValue(RRRPreferencesAudioListedAppsKey, clean.allObjects);
}

// The applications visible to the system (the same set AltList shows in the
// preference list). Blacklist mode must be evaluated against this universe
// rather than against every bundle ID that exists at runtime: an invisible
// system service can never be seen or toggled by the user, so it must never
// be preserved.
static NSSet<NSString *> *RRRVisibleAppBundleIDs(void) {
    NSMutableSet *result = [NSMutableSet set];
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    if (!workspaceClass || ![workspaceClass respondsToSelector:@selector(defaultWorkspace)]) return result;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    @try {
        id workspace = [workspaceClass performSelector:@selector(defaultWorkspace)];
        if (!workspace || ![workspace respondsToSelector:@selector(allApplications)]) return result;
        id applications = [workspace performSelector:@selector(allApplications)];
        if (![applications isKindOfClass:NSArray.class]) return result;
        for (id proxy in applications) {
            if (![proxy respondsToSelector:@selector(bundleIdentifier)]) continue;
            id bundleID = [proxy performSelector:@selector(bundleIdentifier)];
            if (RRRValidBundleID(bundleID)) [result addObject:bundleID];
        }
    } @catch (__unused NSException *exception) {
        // A private API mismatch must fail closed rather than disable the
        // caller's existing blacklist universe.
        return [NSSet set];
    }
#pragma clang diagnostic pop
    return result;
}

static NSSet<NSString *> *RRRStoredAppUniverse(NSDictionary *dict) {
    id raw = dict[RRRPreferencesUniverseKey];
    if (![raw isKindOfClass:NSArray.class]) return [NSSet set];
    NSMutableSet *clean = [NSMutableSet set];
    for (id value in raw) if (RRRValidBundleID(value)) [clean addObject:value];
    return clean;
}

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
        BOOL enabled = [enabledValue isKindOfClass:NSNumber.class] ? [enabledValue boolValue] : YES;
        BOOL preserveNowPlaying = [nowPlaying isKindOfClass:NSNumber.class] ? [nowPlaying boolValue] : YES;
        BOOL preserveOtherApps = [otherApps isKindOfClass:NSNumber.class] ? [otherApps boolValue] : NO;
        BOOL validWhitelist = !whitelist || [whitelist isKindOfClass:NSNumber.class];
        BOOL validList = !listed || [listed isKindOfClass:NSArray.class];
        NSArray *rawList = [listed isKindOfClass:NSArray.class] ? listed : @[];
        NSMutableSet *clean = [NSMutableSet set];
        for (id value in rawList) if (RRRValidBundleID(value)) [clean addObject:value];
        snapshot = [[RRRPreferencesSnapshot alloc] initWithEnabled:enabled
                                                   preserveNowPlaying:preserveNowPlaying
                                                           preserveOtherApps:(validWhitelist && validList && preserveOtherApps)
                                                                   whitelist:(whitelist ? [whitelist boolValue] : YES)
                                                         loggingEnabled:([logging isKindOfClass:NSNumber.class] ? [logging boolValue] : NO)
                                                               listedApps:clean
                                                           appUniverse:RRRStoredAppUniverse(dict)];
    }
    RRRLoggingEnabledState = snapshot.loggingEnabled;
    return snapshot;
}

BOOL RRRPreferencesWrite(BOOL enabled, BOOL preserveNowPlaying, BOOL preserveOtherApps, BOOL whitelist, BOOL loggingEnabled, NSArray<NSString *> *listedApps) {
    NSMutableSet *clean = [NSMutableSet set];
    for (id value in listedApps) if (RRRValidBundleID(value)) [clean addObject:value];
    NSDictionary *current = [NSDictionary dictionaryWithContentsOfFile:RRRPreferencesFilePath];
    NSSet *freshUniverse = RRRVisibleAppBundleIDs();
    NSSet *appUniverse = freshUniverse.count > 0 ? freshUniverse : RRRStoredAppUniverse(current);
    id simultaneousAudioValue = current[RRRPreferencesSimultaneousAudioKey];
    BOOL simultaneousAudioEnabled = [simultaneousAudioValue isKindOfClass:NSNumber.class]
        ? [simultaneousAudioValue boolValue]
        : NO;
    id audioWhitelistValue = current[RRRPreferencesAudioWhitelistKey];
    BOOL audioWhitelist = [audioWhitelistValue isKindOfClass:NSNumber.class]
        ? [audioWhitelistValue boolValue]
        : YES;
    id audioListedAppsValue = current[RRRPreferencesAudioListedAppsKey];
    NSArray *audioListedApps = [audioListedAppsValue isKindOfClass:NSArray.class]
        ? audioListedAppsValue
        : @[];
    NSDictionary *dict = @{ RRRPreferencesEnabledKey: @(enabled),
                            RRRPreferencesNowPlayingKey: @(preserveNowPlaying),
                            RRRPreferencesOtherAppsKey: @(preserveOtherApps),
                            RRRPreferencesWhitelistKey: @(whitelist),
                            RRRPreferencesLoggingKey: @(loggingEnabled),
                            RRRPreferencesSimultaneousAudioKey: @(simultaneousAudioEnabled),
                            RRRPreferencesAudioWhitelistKey: @(audioWhitelist),
                            RRRPreferencesAudioListedAppsKey: audioListedApps,
                            RRRPreferencesListedAppsKey: clean.allObjects,
                            RRRPreferencesUniverseKey: appUniverse.allObjects };
    if (![dict writeToFile:RRRPreferencesFilePath atomically:YES]) return NO;
    notify_post(RRRPreferencesChangedNotification.UTF8String);
    return YES;
}

BOOL RRRPreferencesUpdateAppUniverse(void) {
    NSDictionary *current = [NSDictionary dictionaryWithContentsOfFile:RRRPreferencesFilePath];
    NSSet *universe = RRRVisibleAppBundleIDs();
    // Never erase a known universe because enumeration failed in this process.
    if (universe.count == 0) return NO;
    NSSet *existing = RRRStoredAppUniverse(current);
    if ([existing isEqualToSet:universe]) return NO;
    NSMutableDictionary *updated = current ? [current mutableCopy] : [NSMutableDictionary dictionary];
    updated[RRRPreferencesUniverseKey] = universe.allObjects;
    if (![updated writeToFile:RRRPreferencesFilePath atomically:YES]) return NO;
    notify_post(RRRPreferencesChangedNotification.UTF8String);
    return YES;
}
