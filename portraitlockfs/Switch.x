#import "FSSwitchDataSource.h"
#import "FSSwitchPanel.h"

@interface PortraitLockFSSwitch : NSObject <FSSwitchDataSource>
@end

@implementation PortraitLockFSSwitch

-(FSSwitchState)stateForSwitchIdentifier:(NSString*)switchIdentifier {
	NSString* plist = @"/var/mobile/Library/Preferences/com.ryst.portraitlock.plist";
	NSDictionary* settings = [NSDictionary dictionaryWithContentsOfFile:plist];

	NSNumber* value = [settings valueForKey:@"enabled"];
	bool enabled = value ? [value boolValue] : NO;

	return enabled ? FSSwitchStateOn : FSSwitchStateOff;
}

-(void)applyState:(FSSwitchState)newState forSwitchIdentifier:(NSString*)switchIdentifier {
	if (newState == FSSwitchStateIndeterminate)
		return;

	NSString* plist = @"/var/mobile/Library/Preferences/com.ryst.portraitlock.plist";
	NSMutableDictionary* settings = [NSMutableDictionary dictionaryWithContentsOfFile:plist] ?: [NSMutableDictionary dictionary];;

	if (newState == FSSwitchStateOn) {
		[settings setObject:[NSNumber numberWithBool:YES] forKey:@"enabled"];
	} else if (newState == FSSwitchStateOff) {
		[settings setObject:[NSNumber numberWithBool:NO] forKey:@"enabled"];
	} else {
		return;
	}

	[settings writeToFile:plist atomically:YES];
	
	// Post notification of change
	CFNotificationCenterPostNotification(
		CFNotificationCenterGetDarwinNotifyCenter(),
		CFSTR("com.ryst.portraitlock/settingschanged"),
		NULL, // object
		NULL, // userInfo,
		false);
}

-(NSString*)titleForSwitchIdentifier:(NSString*)switchIdentifier {
	return @"Portrait Lock";
}

@end
