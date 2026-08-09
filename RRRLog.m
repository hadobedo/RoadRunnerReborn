#import "RRRLog.h"

void RRRLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSLog(@"[RRR] %@", message);

    NSString *line = [NSString stringWithFormat:@"%@ [%@] %@\n",
        [NSDate date], [NSProcessInfo processInfo].processName, message];

    // runningboardd's sandbox may block /var/mobile; /tmp is scratch space any
    // daemon can use, so write both and read whichever survives.
    NSArray<NSString *> *paths = @[@"/var/mobile/roadrunnerreborn.log", @"/tmp/roadrunnerreborn.log"];
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
