#import <Preferences/Preferences.h>

#ifndef kCFCoreFoundationVersionNumber_iOS_7_0
#define kCFCoreFoundationVersionNumber_iOS_7_0 847.20
#endif

#ifndef kCFCoreFoundationVersionNumber_iOS_8_0
#define kCFCoreFoundationVersionNumber_iOS_8_0 1140.10
#endif

#ifndef kCFCoreFoundationVersionNumber_iOS_8_1
#define kCFCoreFoundationVersionNumber_iOS_8_1 1141.14
#endif

#define isiOS7 kCFCoreFoundationVersionNumber >= 847.20
#define isiOS8 kCFCoreFoundationVersionNumber >= 1140.10

@interface PortraitLockListController : PSListController <UIAlertViewDelegate> {
}
@end

@implementation PortraitLockListController
-(id)specifiers {
	if (_specifiers == nil) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"PortraitLock" target:self] retain];
	}

	NSMutableArray* specs = [_specifiers mutableCopy];
	NSMutableIndexSet* set = [NSMutableIndexSet indexSet];

	for (int i = 0; i < specs.count; i++) {
		NSString* specifierID = [[[specs objectAtIndex:i] properties] objectForKey:@"id"];
		if (isiOS8) {
			if ([specifierID hasPrefix:@"iOS7-"]) {
				[set addIndex:i];
			}
		} else {
			if ([specifierID hasPrefix:@"iOS8-"]) {
				[set addIndex:i];
			}
		}
	}

	[specs removeObjectsAtIndexes:set];

	_specifiers = [specs copy];

	return _specifiers;
}

-(void)donate {
	NSURL* url = [[NSURL alloc] initWithString:@"https://www.paypal.com/cgi-bin/webscr?cmd=_donations&business=8PGP9PY65ZRX8&lc=US&item_name=ryst%20tweaks&currency_code=USD"];
	[[UIApplication sharedApplication] openURL:url];
}

-(void)resetSettings {
	UIAlertView* alert = [[UIAlertView alloc] initWithTitle:@"Reset settings"
		message:@"All selections will be lost. Are you sure?"
		delegate:self
		cancelButtonTitle:@"No"
		otherButtonTitles:@"Yes", nil];
	[alert show];
	[alert release];
}

-(void)alertView:(UIAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex == [alertView cancelButtonIndex]) {
		// Do nothing
	} else {
		NSString* plist = @"/var/mobile/Library/Preferences/com.ryst.portraitlock.plist";
		NSDictionary* settings = [NSDictionary dictionaryWithContentsOfFile:plist];

		NSNumber* enabled = [settings valueForKey:@"enabled"];
		NSNumber* springboard = [settings valueForKey:@"springboard-lock"];
		NSNumber* springboard8 = [settings valueForKey:@"springboard-lock-ios8"];

		NSMutableDictionary* settingsToSave = [NSMutableDictionary dictionaryWithCapacity:3];
		if (enabled != nil) {
			[settingsToSave setValue:enabled forKey:@"enabled"];
		}
		if (springboard != nil) {
			[settingsToSave setValue:springboard forKey:@"springboard-lock"];
		}
		if (springboard8 != nil) {
			[settingsToSave setValue:springboard8 forKey:@"springboard-lock-ios8"];
		}

		[settingsToSave writeToFile:plist atomically:YES];
	}
}

-(void)respring {
	CFNotificationCenterPostNotification(
		CFNotificationCenterGetDarwinNotifyCenter(), // center
		CFSTR("com.ryst.portraitlock/respring"), // event name
		NULL, // object
		NULL, // userInfo,
		false);
}
@end

// vim:ft=objc
