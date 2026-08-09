#import "RRRLinksListController.h"
#import <UIKit/UIKit.h>

static NSString *const RRRXURL = @"https://twitter.com/Nicks_Works";
static NSString *const RRRInstagramURL = @"https://instagram.com/Nicks_Works";
static NSString *const RRRYouTubeURL = @"https://www.youtube.com/@NicksWorks";
static NSString *const RRRKoFiURL = @"https://ko-fi.com/nicksworks";

@implementation RRRLinksListController

- (NSArray *)specifiers {
    if (_specifiers) return _specifiers;

    _specifiers = [NSMutableArray array];
    NSString *menu = [[self specifier] propertyForKey:@"key"];
    if ([menu isEqualToString:@"nicksWorksMenu"]) {
        self.title = @"Nick's Works";
        PSSpecifier *support = [PSSpecifier groupSpecifierWithName:@"Support"];
        [support setProperty:@"Have a tweak request or an older tweak you would like to see updated? Get in touch through one of the links below." forKey:PSFooterTextGroupKey];
        [_specifiers addObject:support];
        [_specifiers addObject:[self linkSpecifierNamed:@"Support on Ko-fi" key:@"kofi" icon:@"icon_kofi.png"]];
        [_specifiers addObject:[PSSpecifier groupSpecifierWithName:@"Social Links"]];
        [_specifiers addObject:[self linkSpecifierNamed:@"X (Twitter)" key:@"x" icon:@"icon_x.png"]];
        [_specifiers addObject:[self linkSpecifierNamed:@"Instagram" key:@"instagram" icon:@"icon_instagram.png"]];
        [_specifiers addObject:[self linkSpecifierNamed:@"YouTube" key:@"youtube" icon:@"icon_youtube.png"]];
    }
    return _specifiers;
}

- (PSSpecifier *)linkSpecifierNamed:(NSString *)name key:(NSString *)key icon:(NSString *)iconName {
    PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:name
                                                            target:self
                                                               set:NULL
                                                               get:NULL
                                                            detail:nil
                                                              cell:PSLinkCell
                                                              edit:nil];
    [specifier setProperty:key forKey:@"key"];
    UIImage *icon = [self brandIconNamed:iconName];
    if (icon) [specifier setProperty:icon forKey:PSIconImageKey];
    return specifier;
}

- (UIImage *)brandIconNamed:(NSString *)name {
    UIImage *image = [UIImage imageNamed:name
                                 inBundle:[NSBundle bundleForClass:self.class]
            compatibleWithTraitCollection:nil];
    if (!image) return nil;

    const CGFloat iconSize = 20.0;
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
    NSString *key = [specifier propertyForKey:@"key"];
    NSDictionary *urls = @{
        @"kofi": RRRKoFiURL,
        @"x": RRRXURL,
        @"instagram": RRRInstagramURL,
        @"youtube": RRRYouTubeURL
    };
    NSString *urlString = urls[key];
    if (!urlString) {
        [super tableView:tableView didSelectRowAtIndexPath:indexPath];
        return;
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString] options:@{} completionHandler:nil];
}

@end
