#include <UIKit/UIKit.h>

@interface SBOrientationLockManager
+(id)sharedInstance;
-(void)unlock;
-(void)lock:(long long)orientation;
-(void)lock;
-(long long)userLockOrientation;
-(bool)isLocked;
@end

@interface BKSApplicationLaunchSettings
@property(nonatomic) int interfaceOrientation;
@end

static bool enabled = NO;
static NSMutableDictionary* appsToLock = nil;

static NSString* lockIdentifier = @"";
static long long savedOrientation = 0;

static void loadPreferences() {
	NSString* plist = @"/var/mobile/Library/Preferences/com.ryst.portraitlock.plist";
	NSDictionary* settings = [NSDictionary dictionaryWithContentsOfFile:plist];

	[appsToLock removeAllObjects];

	NSNumber* value = [settings valueForKey:@"enabled"];
	if (value != nil) {
		enabled = [value boolValue];
	} else {
		enabled = YES;
	}

	if (!enabled) {
		return;
	}

	NSRange prefix;
	NSString* identifier;

	NSDictionary* types = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt:1], @"lock-",
		[NSNumber numberWithInt:3], @"lock3-",
		[NSNumber numberWithInt:4], @"lock4-",
		[NSNumber numberWithInt:0], @"lock0-",
		nil];

	for (NSString* key in [settings allKeys]) {
		if ([[settings valueForKey:key] boolValue]) {
			for (NSString* type in [types allKeys]) {
				prefix = [key rangeOfString:type];
				if (prefix.location == 0) { // key starts with desired prefix
					identifier = [key stringByReplacingCharactersInRange:prefix withString:@""];
					if ([appsToLock valueForKey:identifier] == nil) {
						[appsToLock setValue:[types valueForKey:type] forKey:identifier];
					}
					continue;
				}
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
		NSNumber* value = [appsToLock valueForKey:identifier];

		if (value != nil) {
			SBOrientationLockManager* manager = [%c(SBOrientationLockManager) sharedInstance];

			if ([lockIdentifier length] == 0) {
				// remember the old lock orientation so we can restore it later
				savedOrientation = [manager isLocked] ? [manager userLockOrientation] : 0;
			}

			// Lock or unlock orientation
			if ([value intValue] == 0) {
				[manager unlock];
			} else {
				[manager lock:[value intValue]];
			}

			lockIdentifier = identifier;
		}
	}
	%orig;
}

- (id)activationSettings {
	id r = %orig;

	if (enabled && ![self isRunning]) {
		NSString* identifier = [self bundleIdentifier];
		NSNumber* value = [appsToLock valueForKey:identifier];

		if (value != nil) {
			SBOrientationLockManager* manager = [%c(SBOrientationLockManager) sharedInstance];

			if ([lockIdentifier length] == 0) {
				// remember the old lock orientation so we can restore it later
				savedOrientation = [manager isLocked] ? [manager userLockOrientation] : 0;
			}

			// Lock or unlock orientation
			if ([value intValue] == 0) {
				[manager unlock];
			} else {
				BKSApplicationLaunchSettings* settings = (BKSApplicationLaunchSettings*)r;
				[settings setInterfaceOrientation:[value intValue]];
			}

			lockIdentifier = identifier;
		}
	}

	return r;
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

	appsToLock = [NSMutableDictionary dictionaryWithCapacity:10];

	loadPreferences();
}

