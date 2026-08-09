#import "RRRCreditCells.h"
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

static void RRRConfigureCreditCell(PSTableCell *cell, PSSpecifier *specifier) {
    cell.imageView.tintColor = UIColor.systemBlueColor;
    cell.imageView.contentMode = UIViewContentModeScaleAspectFit;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.detailTextLabel.text = [specifier propertyForKey:@"subtitle"];
    cell.detailTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.detailTextLabel.numberOfLines = 2;
}

@implementation RRRProfileLinkCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
                    specifier:(PSSpecifier *)specifier {
    if ((self = [super initWithStyle:UITableViewCellStyleSubtitle
                     reuseIdentifier:reuseIdentifier
                           specifier:specifier])) {
        RRRConfigureCreditCell(self, specifier);
    }
    return self;
}

@end

@implementation RRROriginalLinkCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
                    specifier:(PSSpecifier *)specifier {
    if ((self = [super initWithStyle:UITableViewCellStyleSubtitle
                     reuseIdentifier:reuseIdentifier
                           specifier:specifier])) {
        RRRConfigureCreditCell(self, specifier);
    }
    return self;
}

@end
