#import "RRRSurvivors.h"
#import "RRRIdentity.h"
#import "RRRPolicy.h"
#import <notify.h>
#import <rootless.h>
#import <errno.h>
#import <fcntl.h>
#import <limits.h>
#import <pwd.h>
#import <sys/file.h>
#import <sys/stat.h>
#import <sys/types.h>
#import <unistd.h>

NSString *const RRRSurvivorsFilePath = @"/var/mobile/Library/Preferences/com.nicksworks.roadrunnerreborn.survivors.plist";
NSString *const RRRSpringBoardReadyNotification = @"com.nicksworks.roadrunnerreborn.springboard-ready";
NSString *const RRRSurvivorsReadyNotification = @"com.nicksworks.roadrunnerreborn.survivors-ready";
NSString *const RRRSurvivorsConsumedNotification = @"com.nicksworks.roadrunnerreborn.survivors-consumed";

// The record file is shared by runningboardd and SpringBoard, but must never
// live in globally writable /tmp. The rootless-aware and unprefixed paths are
// both used because each injected process can resolve the mobile preference
// directory through a different root mapping.
static NSArray<NSString *> *RRRSurvivorPaths(void) {
    return @[
        ROOT_PATH_NS(@"/var/mobile/Library/Preferences/com.nicksworks.roadrunnerreborn.survivors.plist"),
        @"/var/mobile/Library/Preferences/com.nicksworks.roadrunnerreborn.survivors.plist",
    ];
}

static struct passwd *RRRMobileAccount(void) {
    return getpwnam("mobile");
}

static uid_t RRRMobileUID(void) {
    struct passwd *mobile = RRRMobileAccount();
    return mobile ? mobile->pw_uid : (uid_t)-1;
}

static gid_t RRRMobileGID(void) {
    struct passwd *mobile = RRRMobileAccount();
    return mobile ? mobile->pw_gid : (gid_t)-1;
}

static BOOL RRRParentDirectoriesSecure(NSString *directory) {
    char resolved[PATH_MAX];
    if (!realpath(directory.fileSystemRepresentation, resolved)) return NO;
    uid_t mobileUID = RRRMobileUID();
    if (mobileUID == (uid_t)-1) return NO;
    NSString *current = [NSString stringWithUTF8String:resolved];
    while (current.length > 1) {
        struct stat info;
        if (lstat(current.fileSystemRepresentation, &info) != 0 || !S_ISDIR(info.st_mode) ||
            (info.st_mode & (S_IWGRP | S_IWOTH)) != 0 ||
            (info.st_uid != mobileUID && info.st_uid != 0)) return NO;
        current = [current stringByDeletingLastPathComponent];
    }
    return YES;
}

static BOOL RRRPathIsSecure(NSString *path, BOOL requireExisting) {
    NSString *directory = [path stringByDeletingLastPathComponent];
    if (!RRRParentDirectoriesSecure(directory)) return NO;
    uid_t mobileUID = RRRMobileUID();
    struct stat item;
    if (lstat(path.fileSystemRepresentation, &item) != 0) return !requireExisting && errno == ENOENT;
    return S_ISREG(item.st_mode) &&
           (item.st_mode & (S_IWGRP | S_IWOTH)) == 0 &&
           (item.st_uid == mobileUID || item.st_uid == 0);
}

static int RRRAcquireTransportLock(void) {
    NSString *path = [RRRSurvivorPaths()[0] stringByAppendingString:@".lock"];
    if (!RRRPathIsSecure(path, NO)) return -1;
    int fd = open(path.fileSystemRepresentation, O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW, 0600);
    if (fd >= 0) {
        BOOL secure = fchmod(fd, 0600) == 0;
        if (secure && geteuid() == 0) secure = fchown(fd, RRRMobileUID(), RRRMobileGID()) == 0;
        if (!secure) {
            close(fd);
            unlink(path.fileSystemRepresentation);
            return -1;
        }
    } else if (errno == EEXIST) {
        struct stat item;
        if (lstat(path.fileSystemRepresentation, &item) != 0 || !S_ISREG(item.st_mode) ||
            (item.st_mode & (S_IWGRP | S_IWOTH)) != 0 || item.st_uid != RRRMobileUID()) return -1;
        fd = open(path.fileSystemRepresentation, O_RDWR | O_NOFOLLOW);
    }
    if (fd < 0 || flock(fd, LOCK_EX) != 0) {
        if (fd >= 0) close(fd);
        return -1;
    }
    return fd;
}

static void RRRReleaseTransportLock(int fd) {
    if (fd < 0) return;
    flock(fd, LOCK_UN);
    close(fd);
}

static NSDictionary *RRRReadPayloadAtPath(NSString *path) {
    if (!RRRPathIsSecure(path, YES)) return nil;
    NSDictionary *payload = [NSDictionary dictionaryWithContentsOfFile:path];
    return [payload isKindOfClass:NSDictionary.class] ? payload : nil;
}

static NSDictionary *RRRReadBestPayload(void) {
    NSDictionary *best = nil;
    uint64_t bestGeneration = 0;
    uint64_t bestRevision = 0;
    for (NSString *path in RRRSurvivorPaths()) {
        NSDictionary *payload = RRRReadPayloadAtPath(path);
        if (!payload) continue;
        uint64_t generation = [payload[@"generation"] unsignedLongLongValue];
        uint64_t revision = [payload[@"revision"] unsignedLongLongValue];
        if (generation > bestGeneration || (generation == bestGeneration && revision > bestRevision)) {
            bestGeneration = generation;
            bestRevision = revision;
            best = payload;
        }
    }
    return best;
}

static dispatch_queue_t RRRSurvivorQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ queue = dispatch_queue_create("com.nicksworks.roadrunnerreborn.survivors", DISPATCH_QUEUE_SERIAL); });
    return queue;
}

static uint64_t RRRGeneration;
static uint64_t RRRRevision;

NSDictionary *RRRMakeSurvivorRecord(int pid, uint64_t startIdentity, NSString *bundleID, int hostPID,
                                     uint64_t hostStartIdentity, NSString *rootBundleID, NSString *role) {
    if (pid <= 0 || bundleID.length == 0 || rootBundleID.length == 0) return @{};
    return @{ @"pid": @(pid), @"startIdentity": @(startIdentity), @"bundleID": bundleID,
              @"hostPID": @(hostPID), @"hostStartIdentity": @(hostStartIdentity),
              @"rootBundleID": rootBundleID, @"role": role ?: @"root" };
}

static BOOL RRRWriteFileAtomically(NSData *data, NSString *path) {
    if (!RRRPathIsSecure(path, NO)) return NO;
    NSString *directory = [path stringByDeletingLastPathComponent];
    NSString *temporary = [directory stringByAppendingPathComponent:[NSString stringWithFormat:@".%@.%d.tmp", path.lastPathComponent, getpid()]];
    int fd = open(temporary.fileSystemRepresentation, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600);
    if (fd < 0) return NO;
    BOOL success = YES;
    if (fchmod(fd, 0600) != 0) success = NO;
    if (success && geteuid() == 0 && fchown(fd, RRRMobileUID(), RRRMobileGID()) != 0) success = NO;
    const uint8_t *bytes = data.bytes;
    NSUInteger remaining = data.length;
    while (success && remaining > 0) {
        ssize_t written = write(fd, bytes, remaining);
        if (written <= 0) success = NO;
        else { bytes += written; remaining -= (NSUInteger)written; }
    }
    if (success && fsync(fd) != 0) success = NO;
    close(fd);
    if (!success || rename(temporary.fileSystemRepresentation, path.fileSystemRepresentation) != 0) {
        unlink(temporary.fileSystemRepresentation);
        return NO;
    }
    int directoryFD = open(directory.fileSystemRepresentation, O_RDONLY);
    if (directoryFD >= 0) {
        success = fsync(directoryFD) == 0;
        close(directoryFD);
    }
    return success;
}

static BOOL RRRWriteLocked(NSArray *records, uint64_t generation, uint64_t revision) {
    NSDictionary *payload = @{ @"generation": @(generation), @"revision": @(revision), @"records": records ?: @[] };
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:payload format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];
    if (!data) return NO;
    BOOL wroteAny = NO;
    for (NSString *path in RRRSurvivorPaths()) {
        if (RRRWriteFileAtomically(data, path)) wroteAny = YES;
    }
    return wroteAny;
}

BOOL RRRCaptureSurvivorSync(NSDictionary *record) {
    if (![record isKindOfClass:NSDictionary.class] || record.count == 0) return NO;
    __block BOOL captured = NO;
    dispatch_sync(RRRSurvivorQueue(), ^{
        int lockFD = RRRAcquireTransportLock();
        if (lockFD < 0) return;
        NSDictionary *payload = RRRReadBestPayload();
        if (RRRGeneration == 0) {
            RRRGeneration = MAX((uint64_t)([[NSDate date] timeIntervalSince1970] * 1000000.0) ^ (uint64_t)getpid(), [payload[@"generation"] unsignedLongLongValue]);
        }
        RRRRevision = MAX(RRRRevision, [payload[@"revision"] unsignedLongLongValue]);
        NSArray *old = [payload[@"records"] isKindOfClass:NSArray.class] ? payload[@"records"] : @[];
        NSMutableArray *records = [old mutableCopy];
        BOOL duplicate = NO;
        for (NSDictionary *item in records) {
            if ([item[@"pid"] integerValue] == [record[@"pid"] integerValue] &&
                [item[@"startIdentity"] unsignedLongLongValue] == [record[@"startIdentity"] unsignedLongLongValue] &&
                [item[@"bundleID"] isEqual:record[@"bundleID"]]) { duplicate = YES; break; }
        }
        if (!duplicate) [records addObject:record];
        captured = RRRWriteLocked(records, RRRGeneration, ++RRRRevision);
        RRRReleaseTransportLock(lockFD);
    });
    return captured;
}

BOOL RRRReplaceSurvivorRecords(NSArray<NSDictionary *> *records, uint64_t generation) {
    __block BOOL replaced = NO;
    dispatch_sync(RRRSurvivorQueue(), ^{
        int lockFD = RRRAcquireTransportLock();
        if (lockFD < 0) return;
        NSDictionary *payload = RRRReadBestPayload();
        RRRRevision = MAX(RRRRevision, [payload[@"revision"] unsignedLongLongValue]);
        replaced = RRRWriteLocked(records, generation, ++RRRRevision);
        RRRReleaseTransportLock(lockFD);
    });
    return replaced;
}

void RRRInitializeSurvivorTransport(void) {
    static dispatch_once_t initialized;
    dispatch_once(&initialized, ^{
        static int readyToken = -1;
        static int consumedToken = -1;
        notify_register_dispatch(RRRSpringBoardReadyNotification.UTF8String, &readyToken, dispatch_get_global_queue(0, 0), ^(int token) {
            dispatch_async(RRRSurvivorQueue(), ^{
                if (RRRGeneration == 0) return;
                dispatch_async(dispatch_get_main_queue(), ^{ notify_post(RRRSurvivorsReadyNotification.UTF8String); });
            });
        });
        notify_register_dispatch(RRRSurvivorsConsumedNotification.UTF8String, &consumedToken, dispatch_get_global_queue(0, 0), ^(int token) {
            dispatch_async(RRRSurvivorQueue(), ^{
                for (NSString *path in RRRSurvivorPaths()) unlink(path.fileSystemRepresentation);
                RRRGeneration = 0;
                RRRRevision = 0;
            });
        });
    });
}

NSArray<NSDictionary *> *RRRReadSurvivorRecords(uint64_t *generation) {
    NSDictionary *payload = RRRReadBestPayload();
    uint64_t value = [payload[@"generation"] unsignedLongLongValue];
    if (generation) *generation = value;
    NSArray *records = [payload[@"records"] isKindOfClass:NSArray.class] ? payload[@"records"] : @[];
    NSMutableArray *valid = [NSMutableArray array];
    for (NSDictionary *record in records) {
        if (![record isKindOfClass:NSDictionary.class]) continue;
        NSNumber *pid = record[@"pid"];
        NSNumber *hostPID = record[@"hostPID"], *hostStart = record[@"hostStartIdentity"];
        NSString *bundle = record[@"bundleID"], *root = record[@"rootBundleID"], *role = record[@"role"];
        BOOL isRoot = [role isEqualToString:@"root"];
        BOOL isChild = [role isEqualToString:@"hosted-child"];
        if (value == 0 || pid.intValue <= 0 ||
            !RRRValidBundleID(bundle) || !RRRValidBundleID(root) || (!isRoot && !isChild)) continue;
        if (isRoot) {
            if (hostPID.intValue != 0 || hostStart.unsignedLongLongValue != 0) continue;
        } else if (hostPID.intValue <= 0) {
            continue;
        }
        [valid addObject:record];
    }
    return valid;
}
