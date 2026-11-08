#import "RRRAudioApplicationListController.h"
#import "../Sources/RRRPreferences.h"

@implementation RRRAudioApplicationListController

- (void)loadPreferences {
    _selectedApplications = [RRRAudioListedApplications() mutableCopy] ?: [NSMutableSet set];
}

- (void)savePreferences {
    RRRPreferencesSetAudioListedApplications(_selectedApplications.allObjects);
}

@end
