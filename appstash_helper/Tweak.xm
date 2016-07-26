#include <CoreFoundation/CoreFoundation.h>

extern "C" CFNotificationCenterRef CFNotificationCenterGetDistributedCenter();

@interface MIContainer : NSObject
@end

@interface MIExecutableBundle : NSObject
@property(readonly, copy) NSString *identifier;
@end

@interface MICodeSigningInfo : NSObject
-(MICodeSigningInfo*)
  initWithSignerIdentity: (NSString*)     signerIdentity
  codeInfoIdentifier:     (NSString*)     codeInfoIdentifier
  entitlements:           (NSDictionary*) entitlements
  validatedByProfile:     (bool)          validatedByProfile
  validatedByUPP:         (bool)          validatedByUPP
  isAdHocSigned:          (bool)          isAdHocSigned
  validatedByFreeProfile: (bool)          validatedByFreeProfile;
@end

void receiveAppInstallNotification(CFNotificationCenterRef center,
    void *observer, CFStringRef name, const void *object,
    CFDictionaryRef userInfo) {
  // Log when receiving a notification
  NSLog(@"Received notification 'com.clayfreeman.appstash.install'");
  // Trigger response notification
  NSLog(@"Posting install response notification...\n");
  CFNotificationCenterPostNotification(
    CFNotificationCenterGetDistributedCenter(),
    CFSTR("com.clayfreeman.appstash.installresponse"), NULL,
    NULL, true);
}

%ctor {
  // Register function `receiveAppInstallNotification` for notification
  // `com.clayfreeman.appstash.install` in the Darwin notification center
  CFNotificationCenterAddObserver(CFNotificationCenterGetDistributedCenter(),
    NULL, receiveAppInstallNotification,
    CFSTR("com.clayfreeman.appstash.install"), NULL,
    CFNotificationSuspensionBehaviorDeliverImmediately);
  NSLog(@"Registered for notification 'com.clayfreeman.appstash.install'");
}

%hook MICodeSigningVerifier
-(bool) performValidationWithError:(NSError**)err {
  // Fetch the `_bundle` property from the `MICodeSigningVerifier` instance to
  // fake the entitlements and signer identity
  MIExecutableBundle* _bundle = nil;
  object_getInstanceVariable(self, "_bundle", (void **)&_bundle);
  // Fetch the bundle identifier from the `MIExecutableBundle` instance
  NSString* identifier = [_bundle identifier];
  // Create a fake `MICodeSigningInfo` to placate `installd`
  MICodeSigningInfo* _signingInfo =
  [[NSClassFromString(@"MICodeSigningInfo") alloc]
    initWithSignerIdentity: identifier // Use the fake identifier for both the
    codeInfoIdentifier:     identifier // signer identity and code info
    // Create an entitlements dictionary with only `application-identifier`
    entitlements:           [NSDictionary dictionaryWithObjectsAndKeys:
      identifier, @"application-identifier", nil]
    // Initialize the remaining properties of `MICodeSigningInfo` with
    // potentially insane values
    validatedByProfile:     NO
    validatedByUPP:         NO
    isAdHocSigned:          NO
    validatedByFreeProfile: NO];
  // Override the `_signingInfo` property of `MICodeSigningVerifier` with the
  // faked codesigning information
  NSLog(@"OVERRIDING CODE SIGN CHECK: Important for using installd to stash "
    "system applications (via @clayfreeman1).");
  object_setIvar(self, class_getInstanceVariable([self class], "_signingInfo"),
    _signingInfo);
  // Ensure the NSError is set to `nil`
  *err = nil;
  // Return `YES` to convey success
  return YES;
} %end
