#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const RRRPreferencesFilePath;
extern NSString *const RRRPreferencesChangedNotification;
extern NSString *const RRRPreferencesEnabledKey;
extern NSString *const RRRPreferencesNowPlayingKey;
extern NSString *const RRRPreferencesOtherAppsKey;
extern NSString *const RRRPreferencesWhitelistKey;
extern NSString *const RRRPreferencesListedAppsKey;
extern NSString *const RRRPreferencesLoggingKey;
extern NSString *const RRRPreferencesUniverseKey;

@interface RRRPreferencesSnapshot : NSObject
@property(nonatomic, readonly) BOOL enabled;
@property(nonatomic, readonly) BOOL preserveNowPlaying;
@property(nonatomic, readonly) BOOL preserveOtherApps;
@property(nonatomic, readonly) BOOL whitelist;
@property(nonatomic, readonly) BOOL loggingEnabled;
@property(nonatomic, readonly, copy) NSSet<NSString *> *listedApps;
@property(nonatomic, readonly, copy) NSSet<NSString *> *appUniverse;
- (instancetype)initWithEnabled:(BOOL)enabled
              preserveNowPlaying:(BOOL)preserveNowPlaying
               preserveOtherApps:(BOOL)preserveOtherApps
                        whitelist:(BOOL)whitelist
                   loggingEnabled:(BOOL)loggingEnabled
                       listedApps:(NSSet<NSString *> *)listedApps
                       appUniverse:(NSSet<NSString *> *)appUniverse;
- (BOOL)preservesBundleIdentifier:(NSString *)bundleIdentifier;
@end

FOUNDATION_EXPORT RRRPreferencesSnapshot *RRRPreferencesLoad(void);
FOUNDATION_EXPORT BOOL RRRPreferencesWrite(BOOL enabled, BOOL preserveNowPlaying, BOOL preserveOtherApps, BOOL whitelist, BOOL loggingEnabled, NSArray<NSString *> *listedApps);

// Centralized “never preserve” policy: call-critical UI and Spotlight are
// excluded from every preservation path (Preserve Other Apps and Now Playing).
FOUNDATION_EXPORT BOOL RRRNeverPreserveBundleID(NSString *bundleIdentifier);

// Re-captures the visible application universe (the apps shown in the
// preference list) into the preferences file. Used by SpringBoard to
// self-heal and refresh the universe; posts the settings-changed notification
// only when the universe actually changed.
FOUNDATION_EXPORT BOOL RRRPreferencesUpdateAppUniverse(void);

// Whether diagnostic logging is enabled per the current preferences.
FOUNDATION_EXPORT BOOL RRRLoggingEnabled(void);

NS_ASSUME_NONNULL_END
