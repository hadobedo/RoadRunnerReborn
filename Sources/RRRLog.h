#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

// Package version, kept in sync with the Version field in control. Logged at
// load time by the runningboardd dylib so stale injection is diagnosable.
extern NSString *const RRRVersionString;

// Appends a timestamped line to the rootless-resolved log path (e.g.
// /var/jb/var/mobile/roadrunnerreborn.log on rootless jailbreaks) and NSLogs
// it. No-op unless the Logging preference is enabled.
void RRRLog(NSString *format, ...);

#ifdef __cplusplus
}
#endif
