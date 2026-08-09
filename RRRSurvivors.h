#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const RRRSurvivorsFilePath;
extern NSString *const RRRSpringBoardReadyNotification;
extern NSString *const RRRSurvivorsReadyNotification;
extern NSString *const RRRSurvivorsConsumedNotification;

FOUNDATION_EXPORT NSDictionary *RRRMakeSurvivorRecord(int pid, uint64_t startIdentity,
                                                        NSString *bundleID, int hostPID,
                                                        uint64_t hostStartIdentity,
                                                        NSString *rootBundleID, NSString *role);
FOUNDATION_EXPORT void RRRCaptureSurvivorAsync(NSDictionary *record);
FOUNDATION_EXPORT NSArray<NSDictionary *> *RRRReadSurvivorRecords(uint64_t * _Nullable generation);
FOUNDATION_EXPORT void RRRInitializeSurvivorTransport(void);

NS_ASSUME_NONNULL_END
