#import "RRRPreferences.h"
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface MXCoreSessionBase : NSObject
@property(nonatomic, copy) NSString *displayID;
@property(nonatomic) BOOL hasInput;
@property(nonatomic) BOOL isRecording;
@end

@interface MXSession : NSObject
- (MXCoreSessionBase *)getCoreSession;
@end

static BOOL RRRAudioIsEligibleSession(MXCoreSessionBase *session) {
    NSString *displayIdentifier = session.displayID;
    return RRRAudioAllowsBundleIdentifier(displayIdentifier) &&
           !session.hasInput &&
           !session.isRecording;
}

static void RRRAudioSetMixFlag(MXCoreSessionBase *session) {
    if (!RRRAudioIsEligibleSession(session)) return;

    Ivar mixIvar = class_getInstanceVariable([session class], "_mixesWithEveryone");
    if (mixIvar == NULL) return;

    uint8_t *bytes = (uint8_t *)(__bridge void *)session;
    *(BOOL *)(bytes + ivar_getOffset(mixIvar)) = YES;
}

%hook MXCoreSessionBase

- (void)setAudioCategory:(NSString *)category {
    %orig;
    RRRAudioSetMixFlag(self);
}

- (void)setDisplayID:(NSString *)displayIdentifier {
    %orig;
    RRRAudioSetMixFlag(self);
}

%end

%hook MXSession

- (int)setIsPlaying:(BOOL)isPlaying {
    if (isPlaying) RRRAudioSetMixFlag([self getCoreSession]);
    return %orig;
}

- (int)setIsPlayingOutput:(BOOL)isPlayingOutput {
    if (isPlayingOutput) RRRAudioSetMixFlag([self getCoreSession]);
    return %orig;
}

%end
