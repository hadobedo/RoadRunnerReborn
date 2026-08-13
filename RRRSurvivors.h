#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Secure shared transport under the mobile preferences directory. The
// rootless-aware and unprefixed paths are attempted; legacy /tmp payloads are
// intentionally ignored and never imported.
extern NSString *const RRRSurvivorsFilePath;
extern NSString *const RRRSpringBoardReadyNotification;
extern NSString *const RRRSurvivorsReadyNotification;
extern NSString *const RRRSurvivorsConsumedNotification;

FOUNDATION_EXPORT NSDictionary *RRRMakeSurvivorRecord(int pid, uint64_t startIdentity,
                                                        NSString *bundleID, int hostPID,
                                                        uint64_t hostStartIdentity,
                                                        NSString *rootBundleID, NSString *role);
// Persists the record synchronously on the survivor serial queue. Returns NO
// when the record is invalid or the write fails; callers must then terminate
// normally rather than create an untracked survivor.
FOUNDATION_EXPORT BOOL RRRCaptureSurvivorSync(NSDictionary *record);
// Replaces the stored records (same generation) after a restore pass, so
// failed records are not replayed by a later SpringBoard launch.
FOUNDATION_EXPORT BOOL RRRReplaceSurvivorRecords(NSArray<NSDictionary *> *records, uint64_t generation);
FOUNDATION_EXPORT NSArray<NSDictionary *> *RRRReadSurvivorRecords(uint64_t * _Nullable generation);
FOUNDATION_EXPORT void RRRInitializeSurvivorTransport(void);

NS_ASSUME_NONNULL_END
