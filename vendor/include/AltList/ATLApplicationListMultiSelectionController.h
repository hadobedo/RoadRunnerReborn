#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface ATLApplicationListMultiSelectionController : PSListController
{
@protected
    NSMutableSet *_selectedApplications;
    BOOL _defaultApplicationSwitchValue;
}

- (void)loadPreferences;
- (void)savePreferences;
- (void)setApplicationEnabled:(NSNumber *)enabledNum specifier:(PSSpecifier *)specifier;
- (id)readApplicationEnabled:(PSSpecifier *)specifier;

@end
