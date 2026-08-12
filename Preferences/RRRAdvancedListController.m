#import "RRRAdvancedListController.h"

@implementation RRRAdvancedListController

- (instancetype)init {
    if ((self = [super init])) {
        self.title = @"Advanced";
    }
    return self;
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Advanced" target:self];
    }
    return _specifiers;
}

@end
