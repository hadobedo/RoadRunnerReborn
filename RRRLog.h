#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

// Appends a timestamped line to /var/mobile/roadrunnerreborn.log and NSLogs it.
// From the SSH side (chrooted into /var/jb) read it at /rootfs/private/var/mobile/roadrunnerreborn.log.
void RRRLog(NSString *format, ...);

#ifdef __cplusplus
}
#endif
