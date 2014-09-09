#import <Preferences/Preferences.h>

@interface PortraitLockListController : PSListController <UIAlertViewDelegate> {
}
@end

@implementation PortraitLockListController
-(id)specifiers {
	if (_specifiers == nil) {
		_specifiers = [[self loadSpecifiersFromPlistName:@"PortraitLock" target:self] retain];
	}
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

		if (enabled != nil && springboard != nil) {
			settings = [NSDictionary dictionaryWithObjectsAndKeys:enabled, @"enabled", springboard, @"springboard-lock", nil];
		} else if (enabled != nil) {
			settings = [NSDictionary dictionaryWithObject:enabled forKey:@"enabled"];
		} else if (springboard != nil) {
			settings = [NSDictionary dictionaryWithObject:springboard forKey:@"springboard-lock"];
		} else {
			settings = [NSDictionary dictionary];
		}
		[settings writeToFile:plist atomically:YES];
	}
}
@end

// vim:ft=objc
