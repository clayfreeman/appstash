#import <CoreFoundation/CoreFoundation.h>

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

@interface MIUninstaller : NSObject
@property(readonly) NSDictionary *receipt;
+(MIUninstaller*) uninstallerForIdentifiers: (NSArray*)            url
                  withOptions:               (NSDictionary*)       options
                  forClient:                 (MIClientConnection*) client;
-(bool) performUninstallationWithError:(NSError**)err;
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

@interface MICodeSigningVerifier : NSObject
@property(readonly) MICodeSigningInfo* signingInfo;
@end

void receiveAppInstallNotification(CFNotificationCenterRef, void*, CFStringRef,
    const void*, CFDictionaryRef userInfo) {
  // Log when receiving a notification
  NSLog(@"Received notification 'com.clayfreeman.appstash.install'");
  // Instantiate the MIInstaller class with the provided application path
  NSString* oldPath = [(__bridge NSDictionary*)userInfo
    objectForKey:@"old-path"];
  NSString* stagePath = [(__bridge NSDictionary*)userInfo
    objectForKey:@"application-path"];
  MIInstaller* installer = [NSClassFromString(@"MIInstaller")
    installerForURL: [NSURL fileURLWithPath:stagePath]
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
    oldPath, @"old-path",
    error,   @"error",   nil];
  CFNotificationCenterPostNotification(
    CFNotificationCenterGetDistributedCenter(),
    CFSTR("com.clayfreeman.appstash.installresponse"), NULL,
    (__bridge CFDictionaryRef)info, true);
  NSLog(@"Posted notification 'com.clayfreeman.appstash.installresponse'");
}

void receiveAppUninstallNotification(CFNotificationCenterRef, void*,
    CFStringRef, const void*, CFDictionaryRef userInfo) {
  // Log when receiving a notification
  NSLog(@"Received notification 'com.clayfreeman.appstash.uninstall'");
  // Instantiate the MIUninstaller class with the provided app identifier
  NSString* oldPath = [(__bridge NSDictionary*)userInfo
    objectForKey:@"old-path"];
  NSString* newPath = [(__bridge NSDictionary*)userInfo
    objectForKey:@"new-path"];
  NSString* ident   = [(__bridge NSDictionary*)userInfo
    objectForKey:@"application-identifier"];
  MIUninstaller* uninstaller = [NSClassFromString(@"MIUninstaller")
    uninstallerForIdentifiers: @[ident]
    withOptions:               [NSDictionary dictionary]
    forClient:                 nil];
  NSError*      err     = nil;
  // Attempt the uninstallation, expect a success indicator and potentially
  // populated `NSError` instance
  NSNumber*     success =
    [NSNumber numberWithBool:[uninstaller performUninstallationWithError:&err]];
  NSString*     error   =
    [err isKindOfClass:[NSError class]] ? [err localizedDescription] : @"";
  // Trigger response notification and pass through userInfo path
  NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:
    ident,   @"application-identifier",
    success, @"success",
    oldPath, @"old-path",
    newPath, @"new-path",
    error,   @"error",   nil];
  CFNotificationCenterPostNotification(
    CFNotificationCenterGetDistributedCenter(),
    CFSTR("com.clayfreeman.appstash.uninstallresponse"), NULL,
    (__bridge CFDictionaryRef)info, true);
  NSLog(@"Posted notification 'com.clayfreeman.appstash.uninstallresponse'");
}

%ctor {
  // Register function `receiveAppInstallNotification` for notification
  // `com.clayfreeman.appstash.install` in the Darwin notification center
  CFNotificationCenterAddObserver(CFNotificationCenterGetDistributedCenter(),
    NULL, receiveAppInstallNotification,
    CFSTR("com.clayfreeman.appstash.install"), NULL,
    CFNotificationSuspensionBehaviorDeliverImmediately);
  NSLog(@"Registered for notification 'com.clayfreeman.appstash.install'");
  // Register function `receiveAppUninstallNotification` for notification
  // `com.clayfreeman.appstash.uninstall` in the Darwin notification center
  CFNotificationCenterAddObserver(CFNotificationCenterGetDistributedCenter(),
    NULL, receiveAppUninstallNotification,
    CFSTR("com.clayfreeman.appstash.uninstall"), NULL,
    CFNotificationSuspensionBehaviorDeliverImmediately);
  NSLog(@"Registered for notification 'com.clayfreeman.appstash.uninstall'");
}

%hook MICodeSigningVerifier
NSString*     identifier   = nil;
NSDictionary* entitlements = nil;
-(bool) performValidationWithError:(NSError**)err {
  // Fetch the `_bundle` property from the `MICodeSigningVerifier` instance to
  // fake the entitlements and signer identity
  MIExecutableBundle* _bundle =
    MSHookIvar<MIExecutableBundle*>(self, "_bundle");
  // Fetch the bundle identifier from the `MIExecutableBundle` instance
  identifier   = [_bundle identifier];
  entitlements = [NSDictionary dictionaryWithObjectsAndKeys:
    identifier, @"application-identifier", nil];
  // Create a fake `MICodeSigningInfo` to placate `installd`
  MSHookIvar<MIExecutableBundle*>(self, "_signingInfo") =
  [[NSClassFromString(@"MICodeSigningInfo") alloc]
    initWithSignerIdentity: identifier // Use the fake identifier for both the
    codeInfoIdentifier:     identifier // signer identity and code info
    // Create an entitlements dictionary with only `application-identifier`
    entitlements:           entitlements
    // Initialize the remaining properties of `MICodeSigningInfo` with
    // potentially insane values
    validatedByProfile:     NO
    validatedByUPP:         NO
    isAdHocSigned:          NO
    validatedByFreeProfile: NO];
  // Override the `_signingInfo` property of `MICodeSigningVerifier` with the
  // faked codesigning information
  NSLog(@"OVERRIDING CODE SIGN CHECK for %@: Important for using installd to "
    "stash system applications (via @clayfreeman1, "
    "appstash_helper.dylib).", identifier);
  // Ensure the NSError is set to `nil`
  *err = nil;
  // Return `YES` to convey success
  return YES;
} %end

%hook MIInstallableBundle
-(bool) _checkCanInstallWithError:(NSError**)err {
  bool retVal = %orig;
  // Pass through all errors not relating to being already installed
  if (err != nil && *err != nil && [*err code] == 34)
    *err = nil, retVal = YES;
  return retVal;
}
%end
