#import "RRRApplicationListController.h"
#import "../RRRPreferences.h"

@implementation RRRApplicationListController

- (void)loadPreferences {
    RRRPreferencesSnapshot *settings = RRRPreferencesLoad();
    _selectedApplications = [settings.listedApps mutableCopy] ?: [NSMutableSet set];
}

- (void)savePreferences {
    RRRPreferencesSnapshot *settings = RRRPreferencesLoad();
    RRRPreferencesWrite(settings.enabled,
                        settings.preserveNowPlaying,
                        settings.preserveOtherApps,
                        settings.whitelist,
                        _selectedApplications.allObjects);
}

@end
