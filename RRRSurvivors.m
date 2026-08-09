#import "RRRSurvivors.h"
#import "RRRIdentity.h"
#import <notify.h>
#import <unistd.h>

NSString *const RRRSurvivorsFilePath = @"/tmp/roadrunnerreborn-survivors.plist";
NSString *const RRRSpringBoardReadyNotification = @"com.nicksworks.roadrunnerreborn.springboard-ready";
NSString *const RRRSurvivorsReadyNotification = @"com.nicksworks.roadrunnerreborn.survivors-ready";
NSString *const RRRSurvivorsConsumedNotification = @"com.nicksworks.roadrunnerreborn.survivors-consumed";

static dispatch_queue_t RRRSurvivorQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ queue = dispatch_queue_create("com.nicksworks.roadrunnerreborn.survivors", DISPATCH_QUEUE_SERIAL); });
    return queue;
}

static uint64_t RRRGeneration;

static BOOL RRRValidBundleID(NSString *value) {
    if (![value isKindOfClass:NSString.class] || value.length == 0 || value.length > 255) return NO;
    NSArray *parts = [value componentsSeparatedByString:@"."];
    if (parts.count < 2) return NO;
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"];
    for (NSString *part in parts) {
        if (part.length == 0 || [part rangeOfCharacterFromSet:[allowed invertedSet]].location != NSNotFound) return NO;
    }
    return YES;
}

NSDictionary *RRRMakeSurvivorRecord(int pid, uint64_t startIdentity, NSString *bundleID, int hostPID,
                                     uint64_t hostStartIdentity, NSString *rootBundleID, NSString *role) {
    if (pid <= 0 || bundleID.length == 0 || rootBundleID.length == 0) return @{};
    return @{ @"pid": @(pid), @"startIdentity": @(startIdentity), @"bundleID": bundleID,
              @"hostPID": @(hostPID), @"hostStartIdentity": @(hostStartIdentity),
              @"rootBundleID": rootBundleID, @"role": role ?: @"root" };
}

static void RRRWriteLocked(NSArray *records, uint64_t generation) {
    NSDictionary *payload = @{ @"generation": @(generation), @"records": records ?: @[] };
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:payload format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];
    if (!data) return;
    NSString *tmp = [RRRSurvivorsFilePath stringByAppendingString:@".tmp"];
    if ([data writeToFile:tmp atomically:YES]) rename(tmp.UTF8String, RRRSurvivorsFilePath.UTF8String);
}

void RRRCaptureSurvivorAsync(NSDictionary *record) {
    if (![record isKindOfClass:NSDictionary.class] || record.count == 0) return;
    dispatch_async(RRRSurvivorQueue(), ^{
        if (RRRGeneration == 0) {
            RRRGeneration = (uint64_t)([[NSDate date] timeIntervalSince1970] * 1000000.0) ^ (uint64_t)getpid();
            RRRWriteLocked(@[], RRRGeneration);
        }
        NSDictionary *payload = [NSDictionary dictionaryWithContentsOfFile:RRRSurvivorsFilePath];
        NSArray *old = [payload[@"records"] isKindOfClass:NSArray.class] ? payload[@"records"] : @[];
        NSMutableArray *records = [old mutableCopy];
        BOOL duplicate = NO;
        for (NSDictionary *item in records) {
            if ([item[@"pid"] integerValue] == [record[@"pid"] integerValue] &&
                [item[@"startIdentity"] unsignedLongLongValue] == [record[@"startIdentity"] unsignedLongLongValue] &&
                [item[@"bundleID"] isEqual:record[@"bundleID"]]) { duplicate = YES; break; }
        }
        if (!duplicate) [records addObject:record];
        RRRWriteLocked(records, RRRGeneration);
    });
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
                unlink(RRRSurvivorsFilePath.UTF8String);
                RRRGeneration = 0;
            });
        });
    });
}

NSArray<NSDictionary *> *RRRReadSurvivorRecords(uint64_t *generation) {
    NSDictionary *payload = [NSDictionary dictionaryWithContentsOfFile:RRRSurvivorsFilePath];
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
