#import "RRRRootListController.h"
#import "../RRRPreferences.h"
#import <UIKit/UIKit.h>

static NSString *const RRREnabledKey = @"enabled";
static NSString *const RRRNowPlayingKey = @"preserveNowPlaying";
static NSString *const RRROtherAppsKey = @"preserveOtherApps";
static NSString *const RRRWhitelistKey = @"isWhitelist";
static NSString *const RRRLoggingKey = @"loggingEnabled";
static NSString *const RRRListKey = @"listedApps";

// The app-list row describes the effect of the list for the selected mode:
// whitelist rows are preserved, blacklist rows are killed on respring.
static NSString *const RRRWhitelistAppsTitle = @"Preserve Applications";
static NSString *const RRRBlacklistAppsTitle = @"Kill Applications";

@implementation RRRRootListController

- (NSMutableArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
        for (PSSpecifier *specifier in _specifiers) {
            NSString *key = [specifier propertyForKey:@"key"];
            if ([key isEqualToString:@"nicksWorksMenu"]) [specifier setProperty:[self symbolImageNamed:@"person.crop.circle"] forKey:PSIconImageKey];
            else if ([key isEqualToString:@"originalRoadRunner"]) [specifier setProperty:[self brandIconNamed:@"icon_github.png"] forKey:PSIconImageKey];
        }
        [self updateModeAvailability:NO];
        [self updateModeLabels];
    }
    return _specifiers;
}

// Swaps the app-list row title with the selected mode: "Preserve Applications"
// in whitelist mode, "Kill Applications" in blacklist mode. The mode
// explanations stay visible in the group footer regardless of the selection.
- (void)updateModeLabels {
    RRRPreferencesSnapshot *settings = RRRPreferencesLoad();
    PSSpecifier *apps = [self specifierForID:RRRListKey];
    if (apps) [apps setName:settings.whitelist ? RRRWhitelistAppsTitle : RRRBlacklistAppsTitle];
}

- (UIImage *)symbolImageNamed:(NSString *)name {
    UIImageSymbolConfiguration *configuration = [UIImageSymbolConfiguration configurationWithPointSize:28 weight:UIImageSymbolWeightRegular];
    UIImage *image = [UIImage systemImageNamed:name withConfiguration:configuration];
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

- (UIImage *)brandIconNamed:(NSString *)name {
    UIImage *image = [UIImage imageNamed:name
                                 inBundle:[NSBundle bundleForClass:self.class]
            compatibleWithTraitCollection:nil];
    if (!image) return nil;

    const CGFloat iconSize = 28.0;
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = UIScreen.mainScreen.scale;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc]
                                         initWithSize:CGSizeMake(iconSize, iconSize)
                                               format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        CGRect rect = CGRectMake(0, 0, iconSize, iconSize);
        [image drawInRect:rect];
        CGContextSetBlendMode(context.CGContext, kCGBlendModeSourceIn);
        [UIColor.systemBlueColor setFill];
        CGContextFillRect(context.CGContext, rect);
    }];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    PSSpecifier *specifier = [self specifierAtIndexPath:indexPath];
    if ([[specifier propertyForKey:@"key"] isEqualToString:@"originalRoadRunner"]) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        NSURL *url = [NSURL URLWithString:@"https://github.com/Nosskirneh/RoadRunner"];
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        return;
    }
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    RRRPreferencesSnapshot *settings = RRRPreferencesLoad();
    NSString *key = [specifier propertyForKey:@"key"];
    if ([key isEqualToString:RRREnabledKey]) return @(settings.enabled);
    if ([key isEqualToString:RRRNowPlayingKey]) return @(settings.preserveNowPlaying);
    if ([key isEqualToString:RRROtherAppsKey]) return @(settings.preserveOtherApps);
    if ([key isEqualToString:RRRWhitelistKey]) return @(settings.whitelist);
    if ([key isEqualToString:RRRLoggingKey]) return @(settings.loggingEnabled);
    return [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    RRRPreferencesSnapshot *settings = RRRPreferencesLoad();
    NSString *key = [specifier propertyForKey:@"key"];
    BOOL enabled = settings.enabled;
    BOOL nowPlaying = settings.preserveNowPlaying;
    BOOL otherApps = settings.preserveOtherApps;
    BOOL whitelist = settings.whitelist;
    BOOL loggingEnabled = settings.loggingEnabled;
    if ([key isEqualToString:RRREnabledKey] && [value respondsToSelector:@selector(boolValue)]) enabled = [value boolValue];
    else if ([key isEqualToString:RRRNowPlayingKey] && [value respondsToSelector:@selector(boolValue)]) nowPlaying = [value boolValue];
    else if ([key isEqualToString:RRROtherAppsKey] && [value respondsToSelector:@selector(boolValue)]) otherApps = [value boolValue];
    else if ([key isEqualToString:RRRWhitelistKey] && [value respondsToSelector:@selector(boolValue)]) whitelist = [value boolValue];
    else if ([key isEqualToString:RRRLoggingKey] && [value respondsToSelector:@selector(boolValue)]) loggingEnabled = [value boolValue];
    else return;
    if (RRRPreferencesWrite(enabled, nowPlaying, otherApps, whitelist, loggingEnabled, settings.listedApps.allObjects)) {
        [self updateModeLabels];
        [self updateModeAvailability:YES];
    }
}

- (void)updateModeAvailability:(BOOL)reload {
    BOOL enabled = RRRPreferencesLoad().preserveOtherApps;
    PSSpecifier *mode = [self specifierForID:RRRWhitelistKey];
    PSSpecifier *apps = [self specifierForID:RRRListKey];
    if (mode) [mode setProperty:@(enabled) forKey:@"enabled"];
    if (apps) [apps setProperty:@(enabled) forKey:@"enabled"];
    if (reload && [self respondsToSelector:@selector(reloadSpecifiers)]) [self reloadSpecifiers];
}

@end
