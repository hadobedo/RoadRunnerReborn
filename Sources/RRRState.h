#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const RRRStateFilePath;

@interface RRRState : NSObject
+ (nullable NSString *)nowPlayingBundleID;
+ (int)nowPlayingPID;
+ (uint64_t)nowPlayingStartIdentity;
+ (void)setNowPlayingBundleID:(nullable NSString *)bundleID pid:(int)pid startIdentity:(uint64_t)startIdentity;
@end

NS_ASSUME_NONNULL_END
