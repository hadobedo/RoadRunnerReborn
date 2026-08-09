#import "RRRPreferences.h"
#import <notify.h>

NSString *const RRRPreferencesFilePath = @"/var/mobile/Library/Preferences/com.nicksworks.roadrunnerreborn.preferences.plist";
NSString *const RRRPreferencesChangedNotification = @"com.nicksworks.roadrunnerreborn.settings-changed";
NSString *const RRRPreferencesEnabledKey = @"enabled";
NSString *const RRRPreferencesNowPlayingKey = @"preserveNowPlaying";
NSString *const RRRPreferencesOtherAppsKey = @"preserveOtherApps";
NSString *const RRRPreferencesWhitelistKey = @"isWhitelist";
NSString *const RRRPreferencesListedAppsKey = @"listedApps";

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

@implementation RRRPreferencesSnapshot
- (instancetype)initWithEnabled:(BOOL)enabled preserveNowPlaying:(BOOL)preserveNowPlaying preserveOtherApps:(BOOL)preserveOtherApps whitelist:(BOOL)whitelist listedApps:(NSSet<NSString *> *)listedApps {
    if ((self = [super init])) {
        _enabled = enabled;
        _preserveNowPlaying = preserveNowPlaying;
        _preserveOtherApps = preserveOtherApps;
        _whitelist = whitelist;
        _listedApps = [listedApps copy] ?: [NSSet set];
    }
    return self;
}
- (BOOL)preservesBundleIdentifier:(NSString *)bundleIdentifier {
    if (!_enabled || !_preserveOtherApps || !RRRValidBundleID(bundleIdentifier) || [bundleIdentifier isEqualToString:@"com.apple.Spotlight"]) return NO;
    BOOL listed = [_listedApps containsObject:bundleIdentifier];
    return _whitelist ? listed : !listed;
}
@end

RRRPreferencesSnapshot *RRRPreferencesLoad(void) {
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:RRRPreferencesFilePath];
    if (![dict isKindOfClass:NSDictionary.class]) {
        return [[RRRPreferencesSnapshot alloc] initWithEnabled:YES preserveNowPlaying:YES preserveOtherApps:NO whitelist:YES listedApps:[NSSet set]];
    }
    id enabledValue = dict[RRRPreferencesEnabledKey];
    id nowPlaying = dict[RRRPreferencesNowPlayingKey];
    id otherApps = dict[RRRPreferencesOtherAppsKey];
    id whitelist = dict[RRRPreferencesWhitelistKey];
    id listed = dict[RRRPreferencesListedAppsKey];
    BOOL enabled = [enabledValue isKindOfClass:NSNumber.class] ? [enabledValue boolValue] : YES;
    BOOL preserveNowPlaying = [nowPlaying isKindOfClass:NSNumber.class] ? [nowPlaying boolValue] : YES;
    BOOL preserveOtherApps = [otherApps isKindOfClass:NSNumber.class] ? [otherApps boolValue] : NO;
    BOOL validWhitelist = !whitelist || [whitelist isKindOfClass:NSNumber.class];
    BOOL validList = !listed || [listed isKindOfClass:NSArray.class];
    NSArray *rawList = [listed isKindOfClass:NSArray.class] ? listed : @[];
    NSMutableSet *clean = [NSMutableSet set];
    for (id value in rawList) if (RRRValidBundleID(value)) [clean addObject:value];
    return [[RRRPreferencesSnapshot alloc] initWithEnabled:enabled
                                               preserveNowPlaying:preserveNowPlaying
                                                       preserveOtherApps:(validWhitelist && validList && preserveOtherApps)
                                                               whitelist:(whitelist ? [whitelist boolValue] : YES)
                                                             listedApps:clean];
}

BOOL RRRPreferencesWrite(BOOL enabled, BOOL preserveNowPlaying, BOOL preserveOtherApps, BOOL whitelist, NSArray<NSString *> *listedApps) {
    NSMutableSet *clean = [NSMutableSet set];
    for (id value in listedApps) if (RRRValidBundleID(value)) [clean addObject:value];
    NSDictionary *dict = @{ RRRPreferencesEnabledKey: @(enabled),
                            RRRPreferencesNowPlayingKey: @(preserveNowPlaying),
                            RRRPreferencesOtherAppsKey: @(preserveOtherApps),
                            RRRPreferencesWhitelistKey: @(whitelist),
                            RRRPreferencesListedAppsKey: clean.allObjects };
    if (![dict writeToFile:RRRPreferencesFilePath atomically:YES]) return NO;
    notify_post(RRRPreferencesChangedNotification.UTF8String);
    return YES;
}
