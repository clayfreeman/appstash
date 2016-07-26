#include <CoreFoundation/CoreFoundation.h>

extern "C" CFNotificationCenterRef CFNotificationCenterGetDistributedCenter();

@interface MIClientConnection : NSObject
@end

@interface MIContainer : NSObject
@end

@interface MIExecutableBundle : NSObject
@property(readonly, copy) NSString *identifier;
@end

@interface MIInstaller : NSObject
@property(readonly) NSDictionary *receipt;
+(MIInstaller*) installerForURL: (NSURL*)              url
                withOptions:     (NSDictionary*)       options
                forClient:       (MIClientConnection*) client;
-(bool) performInstallationWithError:(NSError**)err;
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

void receiveAppInstallNotification(CFNotificationCenterRef, void*, CFStringRef,
    const void*, CFDictionaryRef userInfo) {
  // Log when receiving a notification
  NSLog(@"Received notification 'com.clayfreeman.appstash.install'");
  // Instantiate the MIInstaller class with the provided application path
  MIInstaller* installer = [NSClassFromString(@"MIInstaller")
    installerForURL: [NSURL fileURLWithPath:[(__bridge NSDictionary*)userInfo
      objectForKey:@"application-path"]]
    withOptions:     [NSDictionary dictionary]
    forClient:       nil];
  NSError*      err     = nil;
  // Attempt the installation, expect a success indicator and potentially
  // populated `NSError` instance
  NSNumber*     success =
    [NSNumber numberWithBool:[installer performInstallationWithError:&err]];
  NSDictionary* receipt =
    [installer.receipt isKindOfClass:[NSDictionary class]] ? installer.receipt :
    [NSDictionary dictionary];
  NSString*     error   =
    [err isKindOfClass:[NSError class]] ? [err localizedDescription] : @"";
  // Trigger response notification and pass through userInfo path
  NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:
    success, @"success",
    receipt, @"receipt",
    error,   @"error",   nil];
  NSLog(@"Posting install response notification...\n%@", info);
  CFNotificationCenterPostNotification(
    CFNotificationCenterGetDistributedCenter(),
    CFSTR("com.clayfreeman.appstash.installresponse"), NULL,
    (__bridge CFDictionaryRef)info, true);
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

%end

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
