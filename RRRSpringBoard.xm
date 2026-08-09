// RoadRunnerReborn — SpringBoard side.
//
// Two jobs, matching RoadRunner's SpringBoard side:
//  1. Publish the now-playing process for runningboardd.
//  2. After SpringBoard relaunches, reattach that surviving process and restore
//     FrontBoard/MediaRemote state. It does not intercept termination itself.
//
// The MediaRemote notification constants are resolved with dlsym at runtime
// (they live in the dyld shared cache on iOS 16+) so a missing symbol can only
// degrade behavior, never crash SpringBoard at load.
//
// Private APIs below are declared against the iOS 17.0.3 runtime headers
// (MTACS/iOS-17-Runtime-Headers); each one was verified to exist on iOS 15-17.

#import "RRRSpringBoard.h"
#import "RRRState.h"
#import "RRRLog.h"
#import "RRRIdentity.h"
#import "RRRSurvivors.h"
#import "RRRPreferences.h"

#import <UIKit/UIKit.h>
#import <CydiaSubstrate.h>
#import <notify.h>
#import <dlfcn.h>

// ---- SpringBoard private classes (verified against iOS 17 runtime headers) ----

@interface SBApplication : NSObject
@property (nonatomic, readonly, copy) NSString *bundleIdentifier;
@property (nonatomic, getter=isPlayingAudio) BOOL playingAudio;
- (void)_processWillLaunch:(id)applicationProcess;
- (void)_processDidLaunch:(id)applicationProcess;
- (void)_setInternalProcessState:(id)processState;
@end

@interface SBApplicationController : NSObject
+ (instancetype)sharedInstance;
- (SBApplication *)applicationWithBundleIdentifier:(NSString *)bundleIdentifier;
@end

@interface SBApplicationProcessState : NSObject
- (instancetype)_initWithProcess:(id)process stateSnapshot:(id)processState;
@end

@interface SBMediaController : NSObject
+ (instancetype)sharedInstance;
@property (nonatomic, readonly) SBApplication *nowPlayingApplication;
@property (nonatomic) int nowPlayingProcessPID;
@end

typedef NS_ENUM(long long, RRRProcessVisibility) {
    RRRVisibilityUnknown = 0,
    RRRVisibilityBackground = 1,
    RRRVisibilityForeground = 2,
    RRRVisibilityForegroundObscured = 3,
};

typedef NS_ENUM(long long, RRRProcessTaskState) {
    RRRTaskStateUnknown = 0,
    RRRTaskStateNotRunning = 1,
    RRRTaskStateRunning = 2,
    RRRTaskStateSuspended = 3,
};

@interface FBProcessState : NSObject
@property (nonatomic) long long taskState;
@property (nonatomic) long long visibility;
@end

@interface FBProcess : NSObject
@property (nonatomic, readonly, copy) NSString *bundleIdentifier;
@property (nonatomic, readonly) int pid;
@property (nonatomic, readonly) FBProcessState *state;
@property (nonatomic, readonly) FBProcess *hostProcess;
@end

@interface FBApplicationProcess : FBProcess
@property (nonatomic, getter=isNowPlayingWithAudio) BOOL nowPlayingWithAudio;
@end

@interface FBProcessManager : NSObject
+ (instancetype)sharedInstance;
- (FBApplicationProcess *)applicationProcessForPID:(int)pid;
- (FBProcess *)processForPID:(int)pid;
- (FBProcess *)registerProcessForHandle:(id)handle;
@end

@interface BSProcessHandle : NSObject
+ (instancetype)processHandleForPID:(int)pid;
@end

// Runtime class lookup keeps private SpringBoard/FrontBoard references out of
// the dylib's static symbol table.
#define RRR_CLS(cls) ((Class)NSClassFromString(@#cls))

static NSString *RRRSafeBundleIdentifier(id process) {
    if (!process || ![process respondsToSelector:@selector(bundleIdentifier)]) return nil;
    @try {
        id value = [process bundleIdentifier];
        return [value isKindOfClass:NSString.class] ? value : nil;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static id RRRSafeHostProcess(id process) {
    if (!process || ![process respondsToSelector:@selector(hostProcess)]) return nil;
    @try { return [process hostProcess]; }
    @catch (__unused NSException *exception) { return nil; }
}

static id RRRSafeProcessState(id process) {
    if (!process || ![process respondsToSelector:@selector(state)]) return nil;
    @try {
        id (*getter)(id, SEL) = (id (*)(id, SEL))[process methodForSelector:@selector(state)];
        return getter ? getter(process, @selector(state)) : nil;
    } @catch (__unused NSException *exception) { return nil; }
}

// Process survival intentionally has one owner: the RoadRunner-derived
// RBProcess termination hook in runningboardd (RRRRunningBoard.xm).
// SpringBoard only tracks and restores the surviving media process.

// ---- MediaRemote notification constants (resolved at runtime) ----

static NSString *RRRMRSymbolString(const char *name) {
    __unsafe_unretained NSString **symbol = (__unsafe_unretained NSString **)dlsym(RTLD_DEFAULT, name);
    return symbol ? *symbol : nil;
}

static const char *const KMRNowPlayingDidChange = "kMRMediaRemoteNowPlayingApplicationDidChangeNotification";
static const char *const KMRIsPlayingDidChange = "kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification";
static const char *const KMRPIDUserInfoKey = "kMRMediaRemoteNowPlayingApplicationPIDUserInfoKey";
static const char *const KMRIsPlayingUserInfoKey = "kMRMediaRemoteNowPlayingApplicationIsPlayingUserInfoKey";

static NSString *const KSBMediaNowPlayingAppChangedNotification = @"SBMediaNowPlayingAppChangedNotification";
static const char *const KSBSpringBoardDidLaunchNotification = "SBSpringBoardDidLaunchNotification";

@implementation RRRSpringBoardManager {
    NSString *_currentNowPlayingBundleID;
    RRRPreferencesSnapshot *_settings;
}


+ (instancetype)sharedInstance {
    static RRRSpringBoardManager *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [RRRSpringBoardManager new];
    });
    return sharedInstance;
}

- (NSString *)currentNowPlayingBundleID {
    return _currentNowPlayingBundleID;
}

- (BOOL)preserveNowPlaying {
    return _settings ? (_settings.enabled && _settings.preserveNowPlaying) : YES;
}

- (void)settingsChanged {
    RRRPreferencesSnapshot *settings = RRRPreferencesLoad();
    BOOL wasEnabled = _settings ? (_settings.enabled && _settings.preserveNowPlaying) : YES;
    _settings = settings;
    BOOL isEnabled = settings.enabled && settings.preserveNowPlaying;
    if (!isEnabled) {
        [self clearNowPlayingState];
    } else if (!wasEnabled) {
        SBMediaController *mediaController = (SBMediaController *)[(id)RRR_CLS(SBMediaController) sharedInstance];
        if (mediaController.nowPlayingProcessPID > 0) [self updateNowPlayingForPID:mediaController.nowPlayingProcessPID];
    }
}

- (void)clearNowPlayingState {
    _currentNowPlayingBundleID = nil;
    [RRRState setNowPlayingBundleID:nil pid:0 startIdentity:0];
    static int token = -1;
    if (token == -1) notify_register_check("com.nicksworks.roadrunnerreborn.party", &token);
    if (token >= 0) {
        notify_set_state(token, 0);
        notify_post("com.nicksworks.roadrunnerreborn.party-changed");
    }
    RRRLog(@"[SB] now playing preservation disabled");
}

- (void)start {
    _settings = RRRPreferencesLoad();
    RRRLog(@"[SB] manager start");
    if (![self preserveNowPlaying]) [self clearNowPlayingState];
    static int settingsToken = -1;
    notify_register_dispatch(RRRPreferencesChangedNotification.UTF8String, &settingsToken,
        dispatch_get_main_queue(), ^(int token) { [self settingsChanged]; });

    int runningBoardLoadedToken = -1;
    uint64_t runningBoardLoaded = 0;
    if (notify_register_check("com.nicksworks.roadrunnerreborn.runningboard-loaded", &runningBoardLoadedToken) == NOTIFY_STATUS_OK) {
        notify_get_state(runningBoardLoadedToken, &runningBoardLoaded);
    }
    RRRLog(@"[SB] runningboard hook state -> %llu", runningBoardLoaded);

    // Preserve the last party PID across SpringBoard replacement only when
    // Now Playing preservation is enabled.
    if ([self preserveNowPlaying] && [RRRState nowPlayingBundleID].length && [RRRState nowPlayingPID] > 0) {
        static int partyToken = -1;
        if (partyToken == -1 && notify_register_check("com.nicksworks.roadrunnerreborn.party", &partyToken) != NOTIFY_STATUS_OK) partyToken = -1;
        if (partyToken >= 0) {
            notify_set_state(partyToken, (uint64_t)[RRRState nowPlayingPID]);
            static int partyStartToken = -1;
            if (partyStartToken == -1 && notify_register_check("com.nicksworks.roadrunnerreborn.party-start", &partyStartToken) != NOTIFY_STATUS_OK) partyStartToken = -1;
            if (partyStartToken >= 0) notify_set_state(partyStartToken, [RRRState nowPlayingStartIdentity]);
            notify_post("com.nicksworks.roadrunnerreborn.party-changed");
        }
    }

    NSString *didChange = RRRMRSymbolString(KMRNowPlayingDidChange);
    if (didChange) {
        [[NSNotificationCenter defaultCenter] addObserverForName:didChange
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            NSString *pidKey = RRRMRSymbolString(KMRPIDUserInfoKey);
            NSNumber *pid = pidKey ? note.userInfo[pidKey] : nil;
            [self updateNowPlayingForPID:pid ? pid.intValue : -1];
        }];
    } else {
        RRRLog(@"[SB] WARNING: MediaRemote didChange notification symbol missing");
    }

    // runningboardd publishes a completed survivor generation only after its
    // serial record queue reaches a barrier. This is the readiness handshake;
    // the delayed media restore below remains only a FrontBoard warm-up.
    int token;
    notify_register_dispatch(KSBSpringBoardDidLaunchNotification,
        &token,
        dispatch_get_main_queue(),
        ^(int) {
            notify_post(RRRSpringBoardReadyNotification.UTF8String);
            [self scheduleRestore];
        });
    static int survivorsToken = -1;
    notify_register_dispatch(RRRSurvivorsReadyNotification.UTF8String, &survivorsToken,
        dispatch_get_main_queue(), ^(int) { [self restoreSurvivors]; });

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *) { [self scheduleRestore]; }];

    // Covers the case where we are injected into an already-running SpringBoard.
    notify_post(RRRSpringBoardReadyNotification.UTF8String);
    [self scheduleRestore];
}

- (void)scheduleRestore {
    static BOOL scheduled = NO;
    if (scheduled) return;
    scheduled = YES;

    RRRLog(@"[SB] scheduling restore");

    // Give FrontBoard time to publish the surviving process before reattaching
    // the party to the new SpringBoard session.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self restoreParty];
    });
}

- (void)updateNowPlayingForPID:(int)pid {
    if (!self.preserveNowPlaying) {
        [self clearNowPlayingState];
        return;
    }
    @try {
    NSString *bundleID = nil;
    uint64_t startIdentity = 0;
    if (pid > 0) {
        FBProcess *process = [[(id)RRR_CLS(FBProcessManager) sharedInstance] processForPID:pid];
        NSMutableSet *seen = [NSMutableSet set];
        while (process && ![seen containsObject:[NSValue valueWithNonretainedObject:process]]) {
            [seen addObject:[NSValue valueWithNonretainedObject:process]];
            FBProcess *host = RRRSafeHostProcess(process);
            if (!host) break;
            process = host;
        }
        if (process) {
            bundleID = RRRSafeBundleIdentifier(process);
            startIdentity = RRRProcessStartIdentity(process.pid, process);
            pid = process.pid;
        }
    }

    // Start identity is an optional PID-reuse guard. Several iOS 15-17
    // FrontBoard process classes expose none of the private candidate keys;
    // requiring it erased a valid media bundle/PID and disabled protection.
    if (bundleID.length == 0 || pid <= 0) {
        bundleID = nil;
        pid = 0;
        startIdentity = 0;
    }
    _currentNowPlayingBundleID = bundleID;
    [RRRState setNowPlayingBundleID:bundleID pid:pid startIdentity:startIdentity];

    // Publish the party PID to notifyd for the runningboardd hook. Keep the
    // registration alive for SpringBoard's lifetime so the daemon sees the
    // state through a respring.
    static int partyToken = -1;
    if (partyToken == -1 && notify_register_check("com.nicksworks.roadrunnerreborn.party", &partyToken) != NOTIFY_STATUS_OK) partyToken = -1;
    if (partyToken >= 0) {
        notify_set_state(partyToken, (uint64_t)(pid > 0 ? pid : 0));
        static int partyStartToken = -1;
        if (partyStartToken == -1 && notify_register_check("com.nicksworks.roadrunnerreborn.party-start", &partyStartToken) != NOTIFY_STATUS_OK) partyStartToken = -1;
        if (partyStartToken >= 0) notify_set_state(partyStartToken, startIdentity);
        notify_post("com.nicksworks.roadrunnerreborn.party-changed");
    }
    RRRLog(@"[SB] party notify state set -> %d", pid > 0 ? pid : 0);

    RRRLog(@"[SB] now playing -> %@ (pid %d)", bundleID ?: @"none", pid);
    } @catch (NSException *exception) {
        RRRLog(@"[SB] MediaRemote update exception: %@", exception);
    }
}

- (void)restoreParty {
    if (!self.preserveNowPlaying) return;
    // Prefer the freshest in-memory value; fall back to the pre-respring value
    // persisted in the state file.
    if (!_currentNowPlayingBundleID.length) {
        _currentNowPlayingBundleID = [RRRState nowPlayingBundleID];
    }

    RRRLog(@"[SB] restore party nowPlaying=%@", _currentNowPlayingBundleID ?: @"-");

    if (_currentNowPlayingBundleID.length) {
        int partyPID = [RRRState nowPlayingPID];
        uint64_t partyStart = [RRRState nowPlayingStartIdentity];
        if (partyPID > 0) {
            [self reattachPartyPID:partyPID bundleID:_currentNowPlayingBundleID startIdentity:partyStart];
        } else {
            RRRLog(@"[SB] party %@ has no PID in state; skipping reattach", _currentNowPlayingBundleID);
        }
    }

    // If MediaRemote has not told us who is playing yet, ask SpringBoard's own
    // media controller, which re-syncs with mediaremoted at launch.
    if (!_currentNowPlayingBundleID.length) {
        SBMediaController *mediaController = (SBMediaController *)[(id)RRR_CLS(SBMediaController) sharedInstance];
        if (mediaController.nowPlayingProcessPID > 0) {
            [self updateNowPlayingForPID:mediaController.nowPlayingProcessPID];
        }
    }
}

- (void)reattachPartyPID:(int)pid bundleID:(NSString *)bundleID startIdentity:(uint64_t)expectedStart {
    FBProcessManager *processManager = (FBProcessManager *)[(id)RRR_CLS(FBProcessManager) sharedInstance];
    // RoadRunner's proven reattachment boundary is applicationProcessForPID:.
    // processForPID: can return a generic/hosted FBProcess that SpringBoard's
    // application launch callbacks reject with SIGABRT.
    FBApplicationProcess *process = [processManager applicationProcessForPID:pid];

    if (!process) {
        RRRLog(@"[SB] party %@ pid=%d not found; skipping reattach", bundleID, pid);
        return;
    }

    // PID reuse guard: never attach a different process generation.
    uint64_t actualStart = RRRProcessStartIdentity(process.pid, process);
    NSString *actualBundleID = RRRSafeBundleIdentifier(process);
    if (![actualBundleID isEqualToString:bundleID] ||
        (expectedStart > 0 && actualStart > 0 && actualStart != expectedStart)) {
        RRRLog(@"[SB] party pid=%d identity mismatch (%@/%llu); skipping", pid, actualBundleID, actualStart);
        return;
    }

    RRRLog(@"[SB] reattaching party %@ pid=%d", bundleID, pid);
    if (![self reattachAppProcess:process bundleID:bundleID]) return;
    [self restoreMediaForProcess:(FBApplicationProcess *)process bundleID:bundleID pid:pid];
}

- (void)restoreSurvivors {
    if (_settings && !_settings.enabled) {
        notify_post(RRRSurvivorsConsumedNotification.UTF8String);
        return;
    }
    uint64_t generation = 0;
    NSArray<NSDictionary *> *records = RRRReadSurvivorRecords(&generation);
    if (generation == 0) return;
    if (records.count == 0) {
        notify_post(RRRSurvivorsConsumedNotification.UTF8String);
        return;
    }

    NSArray *ordered = [records sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        BOOL ar = [a[@"role"] isEqualToString:@"root"];
        BOOL br = [b[@"role"] isEqualToString:@"root"];
        return ar == br ? NSOrderedSame : (ar ? NSOrderedAscending : NSOrderedDescending);
    }];
    NSMutableSet *restoredRoots = [NSMutableSet set];
    FBProcessManager *manager = (FBProcessManager *)[(id)RRR_CLS(FBProcessManager) sharedInstance];
    for (NSDictionary *record in ordered) {
        int pid = [record[@"pid"] intValue];
        uint64_t expected = [record[@"startIdentity"] unsignedLongLongValue];
        NSString *bundle = record[@"bundleID"];
        BOOL rootRecord = [record[@"role"] isEqualToString:@"root"];
        FBProcess *process = rootRecord ? [manager applicationProcessForPID:pid] : [manager processForPID:pid];
        if (!process && !rootRecord) {
            BSProcessHandle *handle = (BSProcessHandle *)[(id)RRR_CLS(BSProcessHandle) processHandleForPID:pid];
            if (handle) process = [manager registerProcessForHandle:handle];
        }
        uint64_t actual = RRRProcessStartIdentity(pid, process);
        NSString *actualBundleID = RRRSafeBundleIdentifier(process);
        if (!process || (expected > 0 && actual > 0 && actual != expected) ||
            ![actualBundleID isEqualToString:bundle]) continue;
        NSString *root = record[@"rootBundleID"];
        if ([record[@"role"] isEqualToString:@"root"]) {
            if ([self reattachAppProcess:process bundleID:root]) {
                [restoredRoots addObject:root];
                if ([root isEqualToString:_currentNowPlayingBundleID] && pid == [RRRState nowPlayingPID]) {
                    [self restoreMediaForProcess:(FBApplicationProcess *)process bundleID:root pid:pid];
                }
            }
        } else if ([restoredRoots containsObject:root]) {
            // A child is accepted only when its live FrontBoard host still
            // matches the captured host tuple. Never attach a child to a
            // reused PID or to an unrelated application.
            int hostPID = [record[@"hostPID"] intValue];
            uint64_t hostStart = [record[@"hostStartIdentity"] unsignedLongLongValue];
            FBProcess *host = RRRSafeHostProcess(process);
            uint64_t actualHostStart = host ? RRRProcessStartIdentity(host.pid, host) : 0;
            if (hostPID <= 0 || !host || host.pid != hostPID ||
                (hostStart > 0 && actualHostStart > 0 && actualHostStart != hostStart)) continue;
            [self reattachAppProcess:process bundleID:root];
        }
    }
    notify_post(RRRSurvivorsConsumedNotification.UTF8String);
    RRRLog(@"[SB] consumed survivor generation %llu", generation);
}

// Rebuild SpringBoard's view of the surviving app so it shows up in the app
// switcher and can be foregrounded again.
- (BOOL)reattachAppProcess:(FBProcess *)process bundleID:(NSString *)bundleID {
    if (!process || !bundleID.length) return NO;
    Class applicationController = RRR_CLS(SBApplicationController);
    Class applicationProcessState = RRR_CLS(SBApplicationProcessState);
    if (!applicationController || !applicationProcessState) return NO;
    SBApplicationController *controller = [(id)applicationController sharedInstance];
    SBApplication *app = [controller applicationWithBundleIdentifier:bundleID];
    if (!app || ![app respondsToSelector:@selector(_processWillLaunch:)] ||
        ![app respondsToSelector:@selector(_processDidLaunch:)] ||
        ![app respondsToSelector:@selector(_setInternalProcessState:)]) {
        RRRLog(@"[SB] no compatible SBApplication for %@", bundleID);
        return NO;
    }

    FBProcessState *processState = RRRSafeProcessState(process);
    if (!processState) return NO;
    RRRLog(@"[SB] reattach %@ step=willLaunch", bundleID);
    [app _processWillLaunch:process];
    RRRLog(@"[SB] reattach %@ step=didLaunch", bundleID);
    [app _processDidLaunch:process];
    RRRLog(@"[SB] reattach %@ step=state", bundleID);
    processState.visibility = RRRVisibilityBackground;
    processState.taskState = RRRTaskStateRunning;

    SBApplicationProcessState *appProcessState = [(id)applicationProcessState alloc];
    if (![appProcessState respondsToSelector:@selector(_initWithProcess:stateSnapshot:)]) return NO;
    RRRLog(@"[SB] reattach %@ step=snapshot", bundleID);
    appProcessState = [appProcessState _initWithProcess:process stateSnapshot:processState];
    if (!appProcessState) return NO;
    RRRLog(@"[SB] reattach %@ step=internalState", bundleID);
    [app _setInternalProcessState:appProcessState];

    RRRLog(@"[SB] reattached app %@ pid=%d", bundleID, process.pid);
    return YES;
}

// Tell SpringBoard/MediaRemote that the surviving app is the now-playing one
// (audio + Now Playing UI on the lock screen / control center).
- (void)restoreMediaForProcess:(FBApplicationProcess *)process bundleID:(NSString *)bundleID pid:(int)pid {
    if (!self.preserveNowPlaying) return;
    process.nowPlayingWithAudio = YES;

    SBApplication *app = [[(id)RRR_CLS(SBApplicationController) sharedInstance] applicationWithBundleIdentifier:bundleID];
    app.playingAudio = YES;

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

    NSString *didChange = RRRMRSymbolString(KMRNowPlayingDidChange);
    NSString *isPlayingChange = RRRMRSymbolString(KMRIsPlayingDidChange);
    NSString *pidKey = RRRMRSymbolString(KMRPIDUserInfoKey);
    NSString *isPlayingKey = RRRMRSymbolString(KMRIsPlayingUserInfoKey);

    if (didChange && pidKey) {
        [center postNotificationName:didChange
                              object:nil
                            userInfo:@{ pidKey: @(pid) }];
    }
    if (isPlayingChange && isPlayingKey) {
        [center postNotificationName:isPlayingChange
                              object:nil
                            userInfo:@{ isPlayingKey: @YES }];
    }

    // Bring SpringBoard's own media controller up to date.
    SBMediaController *mediaController = (SBMediaController *)[(id)RRR_CLS(SBMediaController) sharedInstance];
    @try {
        [mediaController setValue:app forKey:@"_lastNowPlayingApplication"];
    } @catch (NSException *exception) {
        RRRLog(@"[SB] could not restore _lastNowPlayingApplication: %@", exception);
    }
    mediaController.nowPlayingProcessPID = pid;

    [center postNotificationName:KSBMediaNowPlayingAppChangedNotification object:mediaController];

    RRRLog(@"[SB] restored now playing %@ pid=%d", bundleID, pid);
}

@end
