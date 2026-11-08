#import "RRRPreferences.h"
#import <AVFAudio/AVAudioSession.h>
#import <Foundation/Foundation.h>

@interface AVAudioSession (RRRSimultaneousAudioPrivate)
- (BOOL)setCategoryOptions:(AVAudioSessionCategoryOptions)options error:(NSError **)outError;
@end

static BOOL RRRAudioShouldMixCategory(NSString *category) {
    NSString *bundleIdentifier = NSBundle.mainBundle.bundleIdentifier;
    if (!RRRAudioAllowsBundleIdentifier(bundleIdentifier)) return NO;

    return [category isEqualToString:AVAudioSessionCategoryPlayback] ||
           [category isEqualToString:AVAudioSessionCategoryAmbient];
}

static AVAudioSessionCategoryOptions RRRAudioMixedOptions(
    NSString *category,
    AVAudioSessionCategoryOptions options,
    AVAudioSessionRouteSharingPolicy routeSharingPolicy
) {
    if (!RRRAudioShouldMixCategory(category) ||
        routeSharingPolicy == AVAudioSessionRouteSharingPolicyLongFormAudio) {
        return options;
    }
    return options | AVAudioSessionCategoryOptionMixWithOthers;
}

%hook AVAudioSession

- (BOOL)setCategory:(AVAudioSessionCategory)category error:(NSError **)outError {
    BOOL result = %orig;
    if (!result || !RRRAudioShouldMixCategory(category)) return result;

    AVAudioSessionCategoryOptions options = self.categoryOptions;
    AVAudioSessionCategoryOptions mixedOptions =
        RRRAudioMixedOptions(category, options, self.routeSharingPolicy);
    if (mixedOptions == options) return result;

    NSError *mixError = nil;
    [self setCategoryOptions:mixedOptions error:&mixError];
    return result;
}

- (BOOL)setCategory:(AVAudioSessionCategory)category
        withOptions:(AVAudioSessionCategoryOptions)options
              error:(NSError **)outError {
    return %orig(category,
                 RRRAudioMixedOptions(category, options, self.routeSharingPolicy),
                 outError);
}

- (BOOL)setCategory:(AVAudioSessionCategory)category
               mode:(AVAudioSessionMode)mode
            options:(AVAudioSessionCategoryOptions)options
              error:(NSError **)outError {
    return %orig(category,
                 mode,
                 RRRAudioMixedOptions(category, options, self.routeSharingPolicy),
                 outError);
}

- (BOOL)setCategory:(AVAudioSessionCategory)category
               mode:(AVAudioSessionMode)mode
 routeSharingPolicy:(AVAudioSessionRouteSharingPolicy)policy
            options:(AVAudioSessionCategoryOptions)options
              error:(NSError **)outError {
    return %orig(category,
                 mode,
                 policy,
                 RRRAudioMixedOptions(category, options, policy),
                 outError);
}

- (BOOL)setCategoryOptions:(AVAudioSessionCategoryOptions)options
                     error:(NSError **)outError {
    return %orig(RRRAudioMixedOptions(self.category,
                                     options,
                                     self.routeSharingPolicy),
                 outError);
}

%end
