#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const RRRPreferencesFilePath;
extern NSString *const RRRPreferencesChangedNotification;
extern NSString *const RRRPreferencesEnabledKey;
extern NSString *const RRRPreferencesNowPlayingKey;
extern NSString *const RRRPreferencesOtherAppsKey;
extern NSString *const RRRPreferencesWhitelistKey;
extern NSString *const RRRPreferencesListedAppsKey;

@interface RRRPreferencesSnapshot : NSObject
@property(nonatomic, readonly) BOOL enabled;
@property(nonatomic, readonly) BOOL preserveNowPlaying;
@property(nonatomic, readonly) BOOL preserveOtherApps;
@property(nonatomic, readonly) BOOL whitelist;
@property(nonatomic, readonly, copy) NSSet<NSString *> *listedApps;
- (instancetype)initWithEnabled:(BOOL)enabled
                       preserveNowPlaying:(BOOL)preserveNowPlaying
                            preserveOtherApps:(BOOL)preserveOtherApps
                                   whitelist:(BOOL)whitelist
                                 listedApps:(NSSet<NSString *> *)listedApps;
- (BOOL)preservesBundleIdentifier:(NSString *)bundleIdentifier;
@end

FOUNDATION_EXPORT RRRPreferencesSnapshot *RRRPreferencesLoad(void);
FOUNDATION_EXPORT BOOL RRRPreferencesWrite(BOOL enabled, BOOL preserveNowPlaying, BOOL preserveOtherApps, BOOL whitelist, NSArray<NSString *> *listedApps);

NS_ASSUME_NONNULL_END
