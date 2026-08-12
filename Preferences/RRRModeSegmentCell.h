#import <Preferences/PSTableCell.h>

// Self-contained segmented-control cell for the whitelist/blacklist Mode row.
// Renders a UISegmentedControl from the specifier's validTitles/validValues
// and drives the preference through the specifier's get/set actions. Does not
// depend on PSSegmentTableCell internals, which do not populate from plist
// keys on iOS 15-17.
@interface RRRModeSegmentCell : PSTableCell
@end
