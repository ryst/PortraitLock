#include <UIKit/UIKit.h>

@interface SBOrientationLockManager
+(id)sharedInstance;
-(void)unlock;
-(void)lock:(long long)orientation;
-(void)lock;
-(long long)userLockOrientation;
-(bool)isLocked;
@end

static bool enabled = NO;
static NSMutableArray* appsToLock = nil;

static NSString* lockIdentifier = @"";
static long long savedOrientation = 0;

static void loadPreferences() {
	NSString* plist = @"/var/mobile/Library/Preferences/com.ryst.portraitlock.plist";
	NSDictionary* settings = [NSDictionary dictionaryWithContentsOfFile:plist];

	[appsToLock removeAllObjects];

	id object = [settings objectForKey:@"enabled"];
	enabled = (object != nil) ? [object boolValue] : YES;

	if (!enabled) {
		return;
	}

	for (NSString* key in [settings allKeys]) {
		if ([[settings valueForKey:key] boolValue]) {
			NSRange prefix = [key rangeOfString:@"lock-"];
			if (prefix.location == 0) { // key starts with desired prefix
				[appsToLock addObject:[key stringByReplacingCharactersInRange:prefix withString:@""]];
			}
		}
	}

	if ([appsToLock count] == 0) {
		enabled = NO;
	}
}

static void receivedNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	loadPreferences();
}

%hook SBApplication
-(void)willActivate {
	if (enabled) {
		NSString* identifier = [self bundleIdentifier];
		if ([appsToLock containsObject:identifier]) {
			SBOrientationLockManager* manager = [%c(SBOrientationLockManager) sharedInstance];

			if ([lockIdentifier length] == 0) {
				// remember the old lock orientation so we can restore it later
				savedOrientation = [manager isLocked] ? [manager userLockOrientation] : 0;
			}

			// Lock orientation to portrait
			[manager lock:UIInterfaceOrientationPortrait];

			lockIdentifier = identifier;
		}
	}
	%orig;
}

-(void)didSuspend {
	NSString* identifier = [self bundleIdentifier];
	if (enabled && [lockIdentifier isEqualToString:identifier]) {

		lockIdentifier = @"";

		// Restore previous lock state
		SBOrientationLockManager* manager = [%c(SBOrientationLockManager) sharedInstance];
		if (savedOrientation != 0) {
			[manager lock:savedOrientation];
		} else {
			[manager unlock];
		}
	}
	%orig;
}
%end

%ctor {
	CFNotificationCenterAddObserver(
		CFNotificationCenterGetDarwinNotifyCenter(),
		NULL,
		receivedNotification,
		CFSTR("com.ryst.portraitlock/settingschanged"),
		NULL,
		CFNotificationSuspensionBehaviorCoalesce);

	appsToLock = [NSMutableArray arrayWithCapacity:10];

	loadPreferences();
}

