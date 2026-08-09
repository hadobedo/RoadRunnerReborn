#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// SpringBoard-side manager: tracks the now-playing app, and after SpringBoard
// relaunches, reattaches the processes runningboardd kept alive and restores
// the Now Playing state.
@interface RRRSpringBoardManager : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic, readonly, copy, nullable) NSString *currentNowPlayingBundleID;
@property (nonatomic, readonly) BOOL preserveNowPlaying;

- (void)start;

@end

NS_ASSUME_NONNULL_END
