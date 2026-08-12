#import "RRRModeSegmentCell.h"
#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

@implementation RRRModeSegmentCell {
    UISegmentedControl *_segmentControl;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier])) {
        _segmentControl = [[UISegmentedControl alloc] initWithItems:@[]];
        [_segmentControl addTarget:self action:@selector(segmentValueChanged:) forControlEvents:UIControlEventValueChanged];
        [self.contentView addSubview:_segmentControl];
    }
    return self;
}

- (id)currentPreferenceValue {
    id target = self.specifier.target;
    NSString *getterName = [self.specifier propertyForKey:@"get"];
    if (!target || !getterName.length) return [self.specifier propertyForKey:@"default"];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    return [target performSelector:NSSelectorFromString(getterName) withObject:self.specifier];
#pragma clang diagnostic pop
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
    [super refreshCellContentsWithSpecifier:specifier];
    self.accessoryType = UITableViewCellAccessoryNone;
    NSArray *titles = [specifier propertyForKey:@"validTitles"];
    NSArray *values = [specifier propertyForKey:@"validValues"];
    [_segmentControl removeAllSegments];
    for (NSUInteger index = 0; index < titles.count; index++) {
        [_segmentControl insertSegmentWithTitle:titles[index] atIndex:index animated:NO];
    }
    NSUInteger selected = [values indexOfObject:[self currentPreferenceValue]];
    _segmentControl.selectedSegmentIndex = selected == NSNotFound ? UISegmentedControlNoSegment : (NSInteger)selected;
    _segmentControl.enabled = self.cellEnabled;
    [_segmentControl sizeToFit];
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect bounds = self.contentView.bounds;
    CGFloat width = _segmentControl.frame.size.width;
    CGFloat height = _segmentControl.frame.size.height;
    _segmentControl.frame = CGRectMake(CGRectGetMaxX(bounds) - width - 15.0,
                                       CGRectGetMidY(bounds) - height / 2.0,
                                       width, height);
}

- (void)segmentValueChanged:(UISegmentedControl *)control {
    NSArray *values = [self.specifier propertyForKey:@"validValues"];
    id value = (control.selectedSegmentIndex == UISegmentedControlNoSegment || !values ||
                control.selectedSegmentIndex >= values.count)
        ? nil : values[control.selectedSegmentIndex];
    id target = self.specifier.target;
    NSString *setterName = [self.specifier propertyForKey:@"set"];
    if (target && setterName.length && value) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [target performSelector:NSSelectorFromString(setterName) withObject:value withObject:self.specifier];
#pragma clang diagnostic pop
    }
}

- (void)setCellEnabled:(BOOL)cellEnabled {
    [super setCellEnabled:cellEnabled];
    _segmentControl.enabled = cellEnabled;
}

@end
