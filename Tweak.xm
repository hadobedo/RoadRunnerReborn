// RoadRunnerReborn — entry point.
//
// One dylib, two active hosts: SpringBoard tracks/restores the media process,
// while runningboardd owns survival through the RoadRunner termination seam.

#import "RRRLog.h"
#import "RRRState.h"
#import "RRRSpringBoard.h"

@interface SBApplication : NSObject
@property (nonatomic, readonly, copy) NSString *bundleIdentifier;
@end

%group SpringBoardHooks

// Without this, iOS may refuse to treat the reattached process as a media
// player (SpringBoard caches the now-playing decision per process).
%hook SBMediaController

+ (BOOL)applicationCanBeConsideredNowPlaying:(id)app {
    // The argument is not consistently SBApplication across iOS 15-17
    // (some callers pass a proxy during MediaRemote churn). Never message an
    // unknown object as though it were an SBApplication.
    NSString *bundleID = nil;
    @try {
        if ([app respondsToSelector:@selector(bundleIdentifier)]) {
            id value = [app bundleIdentifier];
            if ([value isKindOfClass:NSString.class]) bundleID = value;
        }
    } @catch (__unused NSException *exception) {
        bundleID = nil;
    }
    RRRSpringBoardManager *manager = [RRRSpringBoardManager sharedInstance];
    if (!manager.preserveNowPlaying) return %orig;
    NSString *nowPlaying = manager.currentNowPlayingBundleID;
    if (bundleID.length && nowPlaying.length && [bundleID isEqualToString:nowPlaying]) return YES;
    return %orig;
}

%end

%end

%ctor {
    if (%c(SpringBoard)) {
        // The iOS 15 implementation reaches this private class method with a
        // different internal calling contract and repeatedly SIGABRTed while
        // media state changed. Survival is owned by runningboardd; this hook
        // only assists post-reattach media eligibility, so omit it on iOS 15.
        if ([NSProcessInfo processInfo].operatingSystemVersion.majorVersion >= 16) {
            %init(SpringBoardHooks);
        }
        [[RRRSpringBoardManager sharedInstance] start];
        RRRLog(@"[SB] RoadRunnerReborn loaded");
    }
}
