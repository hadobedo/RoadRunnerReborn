#import "RRRLog.h"
#import "RRRPreferences.h"
#import <rootless.h>

NSString *const RRRVersionString = @"1.1.1"; // keep in sync with control Version

void RRRLog(NSString *format, ...) {
    if (!RRRLoggingEnabled()) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSLog(@"[RRR] %@", message);

    NSString *line = [NSString stringWithFormat:@"%@ [%@] %@\n",
        [NSDate date], [NSProcessInfo processInfo].processName, message];

    // ROOT_PATH_NS resolves /var/mobile under the jailbreak root (e.g.
    // /var/jb/var/mobile on rootless jailbreaks), never the rootful path;
    // /tmp remains a fallback where a sandbox blocks the jbroot.
    NSArray<NSString *> *paths = @[
        ROOT_PATH_NS(@"/var/mobile/roadrunnerreborn.log"),
        @"/tmp/roadrunnerreborn.log",
    ];
    for (NSString *path in paths) {
        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
        if (!handle) {
            [line writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        } else {
            @try {
                [handle seekToEndOfFile];
                [handle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
            } @catch (NSException *exception) {
                // log file unavailable; NSLog output above is enough
            }
            [handle closeFile];
        }
    }
}
