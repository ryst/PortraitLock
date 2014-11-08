#include <UIKit/UIKit.h>

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

@interface SpringBoard
-(void)_relaunchSpringBoardNow;
@end

@interface SBOrientationLockManager
+(id)sharedInstance;
-(void)unlock;
-(void)lock:(long long)orientation;
-(void)lock;
-(long long)userLockOrientation;
-(bool)isLocked;
@end

@interface SBApplication
-(id)bundleIdentifier;
-(bool)isRunning;
-(void)PL_restoreSavedOrientation;
@end

@interface BKSApplicationLaunchSettings
@property(nonatomic) int interfaceOrientation;
@end

static bool enabled = NO;
static NSMutableDictionary* appsToLock = nil;

static NSString* lockIdentifier = @"";
static long long savedOrientation = 0;

static int springboardLockActive = 0;
static int springboardLockSetting = 0;

static void loadPreferences() {
	NSString* plist = @"/var/mobile/Library/Preferences/com.ryst.portraitlock.plist";
	NSDictionary* settings = [NSDictionary dictionaryWithContentsOfFile:plist];

	[appsToLock removeAllObjects];

	NSNumber* value = [settings valueForKey:@"enabled"];
	if (value != nil) {
		enabled = [value boolValue];
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

	// Get springboard orientation lock setting
	int lockSetting = 0;
	if (isiOS8) {
		value = [settings valueForKey:@"springboard-lock-ios8"];
		if (value != nil) {
			lockSetting = [value boolValue] ? 1 : 0;
		} else {
			value = [settings valueForKey:@"springboard-lock"];
			if (value != nil) {
				lockSetting = [value intValue];
			}
		}
	} else {
		value = [settings valueForKey:@"springboard-lock"];
		if (value != nil) {
			lockSetting = [value intValue];
		}
	}

	springboardLockSetting = lockSetting;
}

static void receivedNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	NSString* notificationName = (NSString*)name;

	if ([notificationName isEqualToString:@"com.ryst.portraitlock/settingschanged"]) {
		loadPreferences();
	} else if ([notificationName isEqualToString:@"com.ryst.portraitlock/respring"]) {
		[(SpringBoard*)[UIApplication sharedApplication] _relaunchSpringBoardNow];
	} 
}

%hook SBApplication
%group HookSBApplication7
-(id)activationSettings {
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
%end // group HookSBApplication7

%group HookSBApplication8
-(long long)launchingInterfaceOrientationForCurrentOrientation {
	if (enabled) {
		NSString* identifier = [self bundleIdentifier];
		NSNumber* value = [appsToLock valueForKey:identifier];

		if (value != nil) {
			if ([value intValue] != 0) {
				return [value longLongValue];
			}
		}
	}

	return %orig;
}
%end // group HookSBApplication8

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

-(void)didDeactivateForEventsOnly:(bool)arg1 {
	[self PL_restoreSavedOrientation];
	%orig;
}

%new
-(void)PL_restoreSavedOrientation {
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
}
%end // hook SBApplication

%hook SpringBoard
%group HookSpringBoard7
-(long long)interfaceOrientationForCurrentDeviceOrientation {
	if (enabled && springboardLockActive) {
		return springboardLockActive;
	} else {
		return %orig;
	}
}

- (void)setWantsOrientationEvents:(bool)wants {
	if (!wants) {
		%orig;

		springboardLockActive = springboardLockSetting;
	} else if (!enabled || springboardLockActive == 0) {
		%orig;
	} else {
		%orig(NO);
	}
}
%end // group HookSpringBoard7

%group HookSpringBoard8
-(long long)homeScreenRotationStyle {
	if (springboardLockActive != 0) {
		return 0;
	} else {
		return %orig;
	}
}
%end // group HookSpringBoard8
%end // hook SpringBoard

%ctor {
	CFNotificationCenterAddObserver(
		CFNotificationCenterGetDarwinNotifyCenter(),
		NULL,
		receivedNotification,
		CFSTR("com.ryst.portraitlock/settingschanged"),
		NULL,
		CFNotificationSuspensionBehaviorCoalesce);

	CFNotificationCenterAddObserver(
		CFNotificationCenterGetDarwinNotifyCenter(),
		NULL,
		receivedNotification,
		CFSTR("com.ryst.portraitlock/respring"),
		NULL,
		CFNotificationSuspensionBehaviorCoalesce);

	appsToLock = [NSMutableDictionary dictionaryWithCapacity:10];

	loadPreferences();

	springboardLockActive = springboardLockSetting;

	if (isiOS8) {
		%init(HookSBApplication8);
		%init(HookSpringBoard8);
	} else {
		%init(HookSBApplication7);
		%init(HookSpringBoard7);
	}

	%init;
}

