#import "RRRState.h"
#import "RRRLog.h"

#import <errno.h>
#import <fcntl.h>
#import <sys/file.h>
#import <string.h>
#import <unistd.h>

NSString *const RRRStateFilePath = @"/var/mobile/Library/Preferences/com.nicksworks.roadrunnerreborn.state.plist";

static NSString *const KNowPlayingBundleIDKey = @"nowPlayingBundleID";
static NSString *const KNowPlayingPIDKey = @"nowPlayingPID";
static NSString *const KNowPlayingStartIdentityKey = @"nowPlayingStartIdentity";

static NSMutableDictionary *readFile(void) {
    int fd = open(RRRStateFilePath.UTF8String, O_RDONLY);
    if (fd < 0) return [NSMutableDictionary dictionary];

    flock(fd, LOCK_SH);
    NSFileHandle *handle = [[NSFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:NO];
    NSData *data = [handle readDataToEndOfFile];
    flock(fd, LOCK_UN);
    close(fd);

    NSDictionary *parsed = data.length
        ? [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL]
        : nil;
    if ([parsed isKindOfClass:NSDictionary.class]) return [parsed mutableCopy];
    return [NSMutableDictionary dictionary];
}

static BOOL mutateFile(NSDictionary *(^block)(NSMutableDictionary *)) {
    int fd = open(RRRStateFilePath.UTF8String, O_RDWR | O_CREAT, 0644);
    if (fd < 0) {
        RRRLog(@"[state] open failed: %s", strerror(errno));
        return NO;
    }

    flock(fd, LOCK_EX);
    NSFileHandle *handle = [[NSFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:NO];
    NSData *data = [handle readDataToEndOfFile];
    NSDictionary *parsed = data.length
        ? [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL]
        : nil;
    NSMutableDictionary *dict = [parsed isKindOfClass:NSDictionary.class]
        ? [parsed mutableCopy]
        : [NSMutableDictionary dictionary];

    NSDictionary *result = block(dict);
    BOOL ok = NO;
    if (result) {
        NSData *outData = [NSPropertyListSerialization dataWithPropertyList:result
                                                                        format:NSPropertyListXMLFormat_v1_0
                                                                       options:0
                                                                         error:NULL];
        if (outData) {
            NSString *tmpPath = [RRRStateFilePath stringByAppendingString:@".tmp"];
            if ([outData writeToFile:tmpPath atomically:YES]
                && rename(tmpPath.UTF8String, RRRStateFilePath.UTF8String) == 0) {
                ok = YES;
            } else {
                RRRLog(@"[state] write failed: %s", strerror(errno));
            }
        }
    }

    flock(fd, LOCK_UN);
    close(fd);
    return ok;
}

@implementation RRRState

+ (nullable NSString *)nowPlayingBundleID {
    NSString *value = readFile()[KNowPlayingBundleIDKey];
    return [value isKindOfClass:NSString.class] && value.length ? value : nil;
}

+ (int)nowPlayingPID {
    NSNumber *value = readFile()[KNowPlayingPIDKey];
    return [value isKindOfClass:NSNumber.class] ? value.intValue : 0;
}

+ (uint64_t)nowPlayingStartIdentity {
    NSNumber *value = readFile()[KNowPlayingStartIdentityKey];
    return [value isKindOfClass:NSNumber.class] ? value.unsignedLongLongValue : 0;
}

+ (void)setNowPlayingBundleID:(nullable NSString *)bundleID pid:(int)pid startIdentity:(uint64_t)startIdentity {
    mutateFile(^NSDictionary *(NSMutableDictionary *dict) {
        if (bundleID.length && pid > 0) {
            dict[KNowPlayingBundleIDKey] = bundleID;
            dict[KNowPlayingPIDKey] = @(pid);
            if (startIdentity > 0) dict[KNowPlayingStartIdentityKey] = @(startIdentity);
            else [dict removeObjectForKey:KNowPlayingStartIdentityKey];
        } else {
            [dict removeObjectForKey:KNowPlayingBundleIDKey];
            [dict removeObjectForKey:KNowPlayingPIDKey];
            [dict removeObjectForKey:KNowPlayingStartIdentityKey];
        }
        return dict;
    });
}

@end
