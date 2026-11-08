#import <Foundation/Foundation.h>
#import "RRRPolicy.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const RRRPreferencesFilePath;
extern NSString *const RRRPreferencesChangedNotification;
extern NSString *const RRRPreferencesEnabledKey;
extern NSString *const RRRPreferencesNowPlayingKey;
extern NSString *const RRRPreferencesOtherAppsKey;
extern NSString *const RRRPreferencesWhitelistKey;
extern NSString *const RRRPreferencesListedAppsKey;
extern NSString *const RRRPreferencesLoggingKey;
extern NSString *const RRRPreferencesSimultaneousAudioKey;
extern NSString *const RRRPreferencesAudioWhitelistKey;
extern NSString *const RRRPreferencesAudioListedAppsKey;
extern NSString *const RRRPreferencesUniverseKey;

FOUNDATION_EXPORT RRRPreferencesSnapshot *RRRPreferencesLoad(void);
FOUNDATION_EXPORT BOOL RRRPreferencesWrite(BOOL enabled, BOOL preserveNowPlaying, BOOL preserveOtherApps, BOOL whitelist, BOOL loggingEnabled, NSArray<NSString *> *listedApps);
FOUNDATION_EXPORT BOOL RRRNeverPreserveBundleID(NSString * _Nullable bundleIdentifier);
FOUNDATION_EXPORT BOOL RRRPreferencesUpdateAppUniverse(void);
FOUNDATION_EXPORT BOOL RRRLoggingEnabled(void);
FOUNDATION_EXPORT BOOL RRRSimultaneousAudioEnabled(void);
FOUNDATION_EXPORT BOOL RRRAudioPolicyEnabled(void);
FOUNDATION_EXPORT BOOL RRRAudioWhitelistEnabled(void);
FOUNDATION_EXPORT NSSet<NSString *> *RRRAudioListedApplications(void);
FOUNDATION_EXPORT BOOL RRRAudioAllowsBundleIdentifier(NSString * _Nullable bundleIdentifier);
FOUNDATION_EXPORT BOOL RRRPreferencesSetSimultaneousAudioEnabled(BOOL enabled);
FOUNDATION_EXPORT BOOL RRRPreferencesSetAudioWhitelistEnabled(BOOL whitelist);
FOUNDATION_EXPORT BOOL RRRPreferencesSetAudioListedApplications(NSArray<NSString *> *bundleIdentifiers);

NS_ASSUME_NONNULL_END
