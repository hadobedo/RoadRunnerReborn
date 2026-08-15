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

static id RRRSafeProcessGetterValue(id object, NSString *key) {
    SEL selector = NSSelectorFromString(key);
    @try {
        // Do not use valueForKey: here. Undefined private keys have caused an
        // uncaught NSUnknownKeyException in SpringBoard even though the probe
        // was inside an Objective-C exception boundary on the device.
        if (![object respondsToSelector:selector]) return nil;
        NSMethodSignature *signature = [object methodSignatureForSelector:selector];
        if (!signature || signature.numberOfArguments != 2) return nil;

        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        invocation.target = object;
        invocation.selector = selector;
        [invocation invoke];

        const char *type = signature.methodReturnType;
        while (*type == 'r' || *type == 'n' || *type == 'N' || *type == 'o' ||
               *type == 'O' || *type == 'R' || *type == 'V') type++;
        switch (*type) {
            case '@':
            case '#': {
                __unsafe_unretained id value = nil;
                [invocation getReturnValue:&value];
                return value;
            }
            case 'c': { char value; [invocation getReturnValue:&value]; return @(value); }
            case 'C': { unsigned char value; [invocation getReturnValue:&value]; return @(value); }
            case 's': { short value; [invocation getReturnValue:&value]; return @(value); }
            case 'S': { unsigned short value; [invocation getReturnValue:&value]; return @(value); }
            case 'i': { int value; [invocation getReturnValue:&value]; return @(value); }
            case 'I': { unsigned int value; [invocation getReturnValue:&value]; return @(value); }
            case 'l': { long value; [invocation getReturnValue:&value]; return @(value); }
            case 'L': { unsigned long value; [invocation getReturnValue:&value]; return @(value); }
            case 'q': { long long value; [invocation getReturnValue:&value]; return @(value); }
            case 'Q': { unsigned long long value; [invocation getReturnValue:&value]; return @(value); }
            case 'B': { unsigned char value; [invocation getReturnValue:&value]; return @(value != 0); }
            case 'f': { float value; [invocation getReturnValue:&value]; return @(value); }
            case 'd': { double value; [invocation getReturnValue:&value]; return @(value); }
            default: return nil;
        }
    } @catch (__unused NSException *exception) {
        // A private getter can still disappear or reject invocation on a new
        // iOS release; process identity is optional, so fail open to 0.
        return nil;
    }
}

uint64_t RRRProcessStartIdentity(int pid, id object) {
    if (pid <= 0 || !object) return 0;
    for (NSString *key in @[@"startTime", @"launchDate", @"startDate", @"processStartTime", @"launchTime"]) {
        id value = RRRSafeProcessGetterValue(object, key);
        if ([value isKindOfClass:NSDate.class]) {
            NSTimeInterval seconds = [(NSDate *)value timeIntervalSince1970];
            if (seconds > 0) return RRRNumberAsStartIdentity(@(seconds));
        } else {
            uint64_t identity = RRRNumberAsStartIdentity(value);
            if (identity != 0) return identity;
        }
    }
    return 0;
}
