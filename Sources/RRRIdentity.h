#import <Foundation/Foundation.h>

// Returns a stable process-generation token, or 0 when the runtime cannot
// provide one. Callers must fail open when this returns 0.
FOUNDATION_EXPORT uint64_t RRRProcessStartIdentity(int pid, id _Nullable processObject);
