#import <Preferences/Preferences.h>

@interface PortraitLockListController: PSListController {
}
@end

@implementation PortraitLockListController
- (id)specifiers {
	if(_specifiers == nil) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"PortraitLock" target:self] retain];
	}
	return _specifiers;
}
@end

// vim:ft=objc
