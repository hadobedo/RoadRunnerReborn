#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Shared Foundation-only policy used by both injected targets and the
// contract probe. Keeping these semantics here prevents tests from drifting
// into a second, unshipped implementation.
FOUNDATION_EXPORT BOOL RRRValidBundleID(NSString * _Nullable value);
FOUNDATION_EXPORT BOOL RRRNeverPreserveBundleID(NSString * _Nullable bundleIdentifier);

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
- (BOOL)preservesBundleIdentifier:(NSString * _Nullable)bundleIdentifier;
@end

NS_ASSUME_NONNULL_END
