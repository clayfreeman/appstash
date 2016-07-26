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
