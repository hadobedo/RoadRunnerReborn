// RoadRunnerReborn — runningboardd side.
// The only survival owner is RBProcess -terminateWithContext:. Preferences,
// records, and notifications are kept off the termination decision path.

#import <Foundation/Foundation.h>
#import <notify.h>
#import <fcntl.h>
#import <stdint.h>
#import <stdio.h>
#import <string.h>
#import <unistd.h>
#import <objc/runtime.h>
#import "RRRPreferences.h"
#import "RRRIdentity.h"
#import "RRRSurvivors.h"

static void RRRRunningBoardMarker(const char *message) {
    int fd = open("/tmp/roadrunnerreborn_daemon.log", O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd < 0) return;
    dprintf(fd, "%s pid=%d\n", message, getpid());
    close(fd);
}

@interface RBSProcessIdentity : NSObject
@property (getter=isEmbeddedApplication, nonatomic, readonly) BOOL embeddedApplication;
@property (nonatomic, readonly, copy) NSString *embeddedApplicationIdentifier;
@property (nonatomic, readonly, copy) NSString *daemonJobLabel;
@end
@interface RBSTerminateContext : NSObject
@property (nonatomic, copy) NSString *explanation;
@property (nonatomic) unsigned long long exceptionCode;
@end
@interface RBProcess : NSObject
@property (nonatomic, readonly) RBProcess *hostProcess;
@property (nonatomic, readonly, copy) RBSProcessIdentity *identity;
@property (nonatomic, readonly) int rbs_pid;
- (BOOL)terminateWithContext:(RBSTerminateContext *)context;
@end

static RRRPreferencesSnapshot *RRRSettings;
static dispatch_queue_t RRRSettingsQueue(void) {
    static dispatch_queue_t q; static dispatch_once_t once;
    dispatch_once(&once, ^{ q = dispatch_queue_create("com.nicksworks.roadrunnerreborn.settings", DISPATCH_QUEUE_SERIAL); });
    return q;
}
static RRRPreferencesSnapshot *RRRCurrentSettings(void) {
    __block RRRPreferencesSnapshot *snapshot;
    dispatch_sync(RRRSettingsQueue(), ^{ snapshot = RRRSettings; });
    return snapshot ?: [[RRRPreferencesSnapshot alloc] initWithEnabled:YES preserveNowPlaying:YES preserveOtherApps:NO whitelist:YES listedApps:[NSSet set]];
}
static void RRRReloadSettings(void) {
    RRRPreferencesSnapshot *snapshot = RRRPreferencesLoad();
    dispatch_async(RRRSettingsQueue(), ^{ RRRSettings = snapshot; });
}

static int RRRRunningBoardPartyPID(void) {
    static int token = -1;
    if (token == -1) {
        uint32_t status = notify_register_dispatch("com.nicksworks.roadrunnerreborn.party", &token,
            dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(int notificationToken) {});
        if (status != NOTIFY_STATUS_OK) { token = -1; return 0; }
    }
    uint64_t state = 0;
    if (notify_get_state(token, &state) != NOTIFY_STATUS_OK || state == 0 || state > INT32_MAX) return 0;
    return (int)state;
}

static uint64_t RRRRunningBoardPartyStartIdentity(void) {
    static int token = -1;
    if (token == -1) {
        uint32_t status = notify_register_dispatch("com.nicksworks.roadrunnerreborn.party-start", &token,
            dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(int notificationToken) {});
        if (status != NOTIFY_STATUS_OK) { token = -1; return 0; }
    }
    uint64_t state = 0;
    return notify_get_state(token, &state) == NOTIFY_STATUS_OK ? state : 0;
}

static BOOL RRRIsRespringTermination(RBSTerminateContext *context) {
    NSString *explanation = context.explanation;
    if ([explanation isEqualToString:@"/usr/libexec/backboardd respawn"]) return YES;
    if ([explanation isEqualToString:@"SBRestartManager"]) return YES;
    return context.exceptionCode == 0xB111B111 || context.exceptionCode == 0x5BC1EA45;
}

static RBProcess *RRREmbeddedRoot(RBProcess *process) {
    NSMutableSet *seen = [NSMutableSet set];
    RBProcess *cursor = process;
    while (cursor) {
        NSValue *identity = [NSValue valueWithNonretainedObject:cursor];
        if ([seen containsObject:identity]) return nil;
        [seen addObject:identity];
        RBProcess *host = cursor.hostProcess;
        if (!host) return cursor;
        cursor = host;
    }
    return nil;
}

static NSString *RRRBundleForProcess(RBProcess *process) {
    RBSProcessIdentity *identity = process.identity;
    if (![identity isEmbeddedApplication] || ![identity.embeddedApplicationIdentifier isKindOfClass:NSString.class]) return nil;
    return identity.embeddedApplicationIdentifier;
}

static BOOL RRRProtected(RBProcess *process, RBProcess *root, RRRPreferencesSnapshot *settings, int partyPID, uint64_t partyStart) {
    if (!settings.enabled) return NO;
    NSString *rootBundle = RRRBundleForProcess(root);
    if (root.rbs_pid <= 0 || !rootBundle.length) return NO;
    uint64_t rootStart = RRRProcessStartIdentity(root.rbs_pid, root);
    // Start identity is an additional guard when this OS exposes it. The
    // proven media path is the live RBProcess bundle + party PID; requiring a
    // private generation key made both iOS 15 and 17 silently unprotectable.
    if (settings.preserveNowPlaying && root.rbs_pid == partyPID &&
        (partyStart == 0 || rootStart == 0 || rootStart == partyStart)) return YES;
    if (settings.preserveOtherApps && [settings preservesBundleIdentifier:rootBundle]) return YES;
    return NO;
}

%group RunningBoardHooks
%hook RBProcess
- (BOOL)terminateWithContext:(RBSTerminateContext *)context {
    if (!RRRIsRespringTermination(context)) return %orig;

    RRRPreferencesSnapshot *settings = RRRCurrentSettings();
    int partyPID = RRRRunningBoardPartyPID();
    uint64_t partyStart = RRRRunningBoardPartyStartIdentity();

    RBProcess *root = RRREmbeddedRoot(self);
    if (!root || !RRRProtected(self, root, settings, partyPID, partyStart)) return %orig;

    NSString *bundle = RRRBundleForProcess(self);
    NSString *rootBundle = RRRBundleForProcess(root);
    uint64_t start = RRRProcessStartIdentity(self.rbs_pid, self);
    RBProcess *host = self.hostProcess;
    uint64_t hostStart = host ? RRRProcessStartIdentity(host.rbs_pid, host) : 0;
    NSDictionary *record = RRRMakeSurvivorRecord(self.rbs_pid, start, bundle ?: rootBundle,
                                                   host ? host.rbs_pid : 0, hostStart,
                                                   rootBundle, self == root ? @"root" : @"hosted-child");
    RRRCaptureSurvivorAsync(record);
    RRRRunningBoardMarker(self == root ? "[RRR][RB] PROTECTED root" : "[RRR][RB] PROTECTED hosted-child");
    NSLog(@"[RRR][RB] PROTECTED %@ pid=%d app=%@ root=%@ hostPid=%d expl=%@ code=0x%llx",
          self == root ? @"root" : @"hosted-child", self.rbs_pid, bundle ?: @"-", rootBundle ?: @"-",
          host ? host.rbs_pid : 0, context.explanation ?: @"-", context.exceptionCode);
    return YES;
}
%end
%end

%ctor {
    const char *program = getprogname();
    if (!program || strcmp(program, "runningboardd") != 0) return;
    RRRRunningBoardMarker("[RRR][RB] constructor entered");
    // /tmp may be denied by runningboardd's sandbox on some releases. Publish
    // a persistent notify state too so SpringBoard can prove daemon injection.
    static int loadedToken = -1;
    if (notify_register_check("com.nicksworks.roadrunnerreborn.runningboard-loaded", &loadedToken) == NOTIFY_STATUS_OK) {
        notify_set_state(loadedToken, 1);
    }
    RRRSettings = RRRPreferencesLoad();
    RRRInitializeSurvivorTransport();
    static int settingsToken = -1;
    notify_register_dispatch(RRRPreferencesChangedNotification.UTF8String, &settingsToken,
        RRRSettingsQueue(), ^(int token) { RRRReloadSettings(); });
    Class processClass = %c(RBProcess);
    SEL selector = @selector(terminateWithContext:);
    if (!processClass || ![processClass instancesRespondToSelector:selector]) {
        RRRRunningBoardMarker("[RRR][RB] ERROR boundary unavailable");
        return;
    }
    %init(RunningBoardHooks);
    RRRRunningBoardMarker("[RRR][RB] hook installed");
}
