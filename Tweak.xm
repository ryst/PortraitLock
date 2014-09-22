#include <UIKit/UIKit.h>

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

@interface SpringBoard : UIApplication;
-(id)_accessibilityFrontMostApplication;
@end

@interface MPInlineVideoController
@property(nonatomic, getter=isFullscreen) BOOL fullscreen;
@end

%group SpringBoardHooks

static bool enabled = NO;
static bool enabledVideo = NO;
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
	value = [settings valueForKey:@"springboard-lock"];
	if (value != nil) {
		springboardLockSetting = [value intValue];
	}
}

static void setFullScreenVideo(bool isFullScreen) {
	SpringBoard* springBoard = (SpringBoard*)[%c(SpringBoard) sharedApplication];
	SBApplication* frontMostApp = [springBoard _accessibilityFrontMostApplication];
	NSString* identifier = [frontMostApp bundleIdentifier];

	if (enabled && enabledVideo && [lockIdentifier isEqualToString:identifier]) {

		SBOrientationLockManager* manager = [%c(SBOrientationLockManager) sharedInstance];
		if (isFullScreen) {
			// Unlock
			[manager unlock];
		} else {
			// Re-lock
			NSNumber* value = [appsToLock valueForKey:identifier];

			if ([value intValue] != 0) {
				[manager lock:[value intValue]];
			}
		}
	}
}

static void receivedNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	NSString* notificationName = (NSString*)name;

	if ([notificationName isEqualToString:@"com.ryst.portraitlock/settingschanged"]) {
		loadPreferences();
	} else if ([notificationName isEqualToString:@"com.ryst.portraitlock/tofullscreenvideo"]) {
		setFullScreenVideo(YES);
	} else if ([notificationName isEqualToString:@"com.ryst.portraitlock/fromfullscreenvideo"]) {
		setFullScreenVideo(NO);
	} 
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
	[self PL_restoreSavedOrientation];
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
%end

%hook SpringBoard
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
%end

%end // group SpringBoardHooks

%hook MPInlineVideoController
- (void)displayVideoView {
	%orig;

	if ([self isFullscreen]) {
		// Post notification of change
		CFNotificationCenterPostNotification(
			CFNotificationCenterGetDarwinNotifyCenter(),
			CFSTR("com.ryst.portraitlock/tofullscreenvideo"),
			NULL, // object
			NULL, // userInfo,
			false);
	}
}

-(void)_transitionToFullscreenDidEnd {
	// Post notification of change
	CFNotificationCenterPostNotification(
		CFNotificationCenterGetDarwinNotifyCenter(),
		CFSTR("com.ryst.portraitlock/tofullscreenvideo"),
		NULL, // object
		NULL, // userInfo,
		false);

	%orig;
}

-(void)_transitionFromFullscreenDidEnd {
	%orig;

	// Post notification of change
	CFNotificationCenterPostNotification(
		CFNotificationCenterGetDarwinNotifyCenter(),
		CFSTR("com.ryst.portraitlock/fromfullscreenvideo"),
		NULL, // object
		NULL, // userInfo,
		false);
}
%end

%ctor {
	// Load hooks for SpringBoard
	if (%c(SpringBoard)) {
		%init(SpringBoardHooks);

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
			CFSTR("com.ryst.portraitlock/tofullscreenvideo"),
			NULL,
			CFNotificationSuspensionBehaviorCoalesce);

		CFNotificationCenterAddObserver(
			CFNotificationCenterGetDarwinNotifyCenter(),
			NULL,
			receivedNotification,
			CFSTR("com.ryst.portraitlock/fromfullscreenvideo"),
			NULL,
			CFNotificationSuspensionBehaviorCoalesce);

		appsToLock = [NSMutableDictionary dictionaryWithCapacity:10];

		loadPreferences();

		springboardLockActive = springboardLockSetting;
	}

	// Load hooks for other apps
	%init;
}

