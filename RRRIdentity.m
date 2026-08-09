#import "RRRIdentity.h"

// RunningBoard/FrontBoard expose a process-generation value on the private
// process objects, but its selector name differs across iOS releases. We use
// only object-provided values and fail closed when none is available. The
// public proc_pidinfo BSD structure does not contain a portable start-time
// field; guessing an offset would turn PID reuse into a safety bug.

static uint64_t RRRNumberAsStartIdentity(NSNumber *number) {
    if (![number isKindOfClass:NSNumber.class]) return 0;
    double value = number.doubleValue;
    if (value <= 0) return 0;
    // Private APIs may expose seconds, microseconds, or nanoseconds. Seconds
    // are currently below 1e11; larger values are already generation tokens.
    if (value < 100000000000.0) value *= 1000000.0;
    if (value > (double)UINT64_MAX) return 0;
    return (uint64_t)value;
}

uint64_t RRRProcessStartIdentity(int pid, id object) {
    if (pid <= 0 || !object) return 0;
    for (NSString *key in @[@"startTime", @"launchDate", @"startDate", @"processStartTime", @"launchTime"]) {
        @try {
            id value = [object valueForKey:key];
            if ([value isKindOfClass:NSDate.class]) {
                NSTimeInterval seconds = [(NSDate *)value timeIntervalSince1970];
                if (seconds > 0) return RRRNumberAsStartIdentity(@(seconds));
            } else {
                uint64_t identity = RRRNumberAsStartIdentity(value);
                if (identity != 0) return identity;
            }
        } @catch (__unused NSException *exception) {
            // One unavailable iOS-version-specific key must not prevent the
            // remaining candidates from being tried.
        }
    }
    return 0;
}
