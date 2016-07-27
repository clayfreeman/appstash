#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <Foundation/NSTask.h>

extern "C" CFNotificationCenterRef CFNotificationCenterGetDistributedCenter();

void initializeApplicationStashDB() {
  // Setup some storage for reference return values and default structures
  BOOL    isDirectory = NO;
  NSData* defaultData = [NSJSONSerialization
    dataWithJSONObject: [NSDictionary dictionaryWithObjectsAndKeys:
      [NSDictionary dictionary], @"apps", nil]
    options:            nil
    error:              nil];
  // Ensure that `/var/db/stash` is a directory
  if (![[NSFileManager defaultManager]
      fileExistsAtPath: @"/var/db/stash"
      isDirectory:      &isDirectory] || !isDirectory)
    if (![[NSFileManager defaultManager]
        createDirectoryAtPath:       @"/var/db/stash"
        withIntermediateDirectories: YES
        attributes:                  nil
        error:                       nil])
      fprintf(stderr, "ERROR: Could not initialize stash dir\n"), exit(1);
  // Ensure that `/var/db/stash/apps.json` is a file
  if (![[NSFileManager defaultManager]
      fileExistsAtPath: @"/var/db/stash/apps.json"
      isDirectory:      &isDirectory] || isDirectory)
    if (![[NSFileManager defaultManager]
        createFileAtPath: @"/var/db/stash/apps.json"
        contents:         defaultData
        attributes:       [NSDictionary dictionaryWithObjectsAndKeys:
          @"root",                          NSFileOwnerAccountName,
          @"wheel",                         NSFileGroupOwnerAccountName,
          [NSNumber numberWithShort: 0660], NSFilePosixPermissions, nil]])
      fprintf(stderr, "ERROR: Could not initialize stash db\n"), exit(1);
  // Attempt to unserialize the contents of `/var/db/stash/apps.json`
  NSDictionary *stash = [NSJSONSerialization
    JSONObjectWithData:[NSData
      dataWithContentsOfFile: @"/var/db/stash/apps.json"]
    options:           nil
    error:             nil];
  // Ensure that `/var/db/stash/apps.json` contains the appropriate structure
  if (![stash isKindOfClass:[NSDictionary class]] ||
       [stash objectForKey:@"apps"] == nil)
    if (![defaultData writeToFile:@"/var/db/stash/apps.json" atomically:YES])
      fprintf(stderr, "ERROR: Could not re-initialize stash db\n"), exit(1);
  // Ensure that `/usr/libexec/cydia/setnsfpn` is called successfully for
  // `/var/db/stash` and `/var/containers/Bundle/Application`
  for (NSString* path in @[@"/var/db/stash",
                           @"/var/containers/Bundle/Application"]) {
    NSTask* launch    = [[NSTask alloc] init];
    launch.launchPath = @"/usr/libexec/cydia/setnsfpn";
    launch.arguments  = @[path];
    [launch launch];
    [launch waitUntilExit];
    // Require the termination status of the task to be successful
    if ([launch terminationStatus] != 0)
      fprintf(stderr, "ERROR: setnsfpn failed for %s",
        [path UTF8String]), exit(1);
   }
}

void addApplicationStashDB(NSString* ident, NSString* oldPath,
    NSString* newPath) {
  // Attempt to load the stash database
  NSMutableDictionary *stash = [NSJSONSerialization
    JSONObjectWithData:[NSData
      dataWithContentsOfFile: @"/var/db/stash/apps.json"]
    options:           NSJSONReadingMutableContainers
    error:             nil];
  // Ensure that the stash database contains the appropriate structure
  if (![stash isKindOfClass:[NSMutableDictionary class]] ||
       [stash objectForKey:@"apps"] == nil)
    fprintf(stderr, "ERROR: Unable to load /var/db/stash/apps.json\n"), exit(1);
  // Add the requested entry
  [[stash objectForKey:@"apps"]
    setObject: [NSDictionary dictionaryWithObjectsAndKeys:
      oldPath, @"old-path",
      newPath, @"new-path", nil]
    forKey:    ident];
  // Serialize the changes back to disk
  [[NSJSONSerialization
      dataWithJSONObject: stash
      options:            nil
      error:              nil]
    writeToFile:@"/var/db/stash/apps.json" atomically:YES];
}

void receiveAppInstallResponseNotification(CFNotificationCenterRef, void*,
    CFStringRef, const void*, CFDictionaryRef userInfo) {
  // fprintf(stderr, "Received notification "
  //   "'com.clayfreeman.appstash.installresponse'\n");
  // Retreive the status and error information from the user info
  bool          success =
    [[(__bridge NSDictionary*)userInfo objectForKey:@"success"] boolValue];
  NSDictionary* receipt =
    [ (__bridge NSDictionary*)userInfo objectForKey:@"receipt"];
  NSDictionary* info    = [[receipt objectForKey:@"InstalledAppInfoArray"]
    objectAtIndex:0];
  NSString*     ident   = [info objectForKey:@"CFBundleIdentifier"];
  NSString*     oldPath =
    [ (__bridge NSDictionary*)userInfo objectForKey:@"old-path"];
  NSString*     newPath = [info objectForKey:@"Path"];
  NSString*     error   =
    [ (__bridge NSDictionary*)userInfo objectForKey:@"error"];
  if (success == NO) {
    fprintf(stderr, "\rERROR: %s\n", [error UTF8String]);
    exit(1);
  } else {
    fprintf(stderr, "\rInstalled %s to %s\n", [ident UTF8String],
      [newPath UTF8String]);
    addApplicationStashDB(ident, oldPath, newPath);
    exit(0);
  }
}

int main(int argc, char **argv) {
  if (argc > 1) {
    // Use launchctl to start com.apple.mobile.installd
    NSTask* launch = [[NSTask alloc] init];
    launch.launchPath =   @"/bin/launchctl";
    launch.arguments  = @[@"start", @"com.apple.mobile.installd"];
    [launch launch];
    // Wait until the process exits and retrieve its exit status
    [launch waitUntilExit];
    int status = [launch terminationStatus];
    // Only continue if launchctl was successful
    if (status == 0) {
      // Initialize the stash database
      initializeApplicationStashDB();
      // Register function `receiveAppInstallResponseNotification` for
      // notification `com.clayfreeman.appstash.installrespose` in the Darwin
      // notification center
      CFNotificationCenterAddObserver(
        CFNotificationCenterGetDistributedCenter(),
        NULL, receiveAppInstallResponseNotification,
        CFSTR("com.clayfreeman.appstash.installresponse"), NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately);
      // Make an NSString from the user-provided app path argument
      NSString*     path = [NSString stringWithCString:argv[1]
        encoding:NSASCIIStringEncoding];
      // Build an NSDictionary from the user-provided path
      NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:
        path, @"application-path", nil];
      fprintf(stderr, "Stashing %s ...\n", [path UTF8String]);
      // Dispatch the install request notification with the user info
      CFNotificationCenterPostNotification(
        CFNotificationCenterGetDistributedCenter(),
        CFSTR("com.clayfreeman.appstash.install"), NULL,
        (__bridge CFDictionaryRef)info, true);
      // Continue in a CF run loop while waiting for a response
      fprintf(stderr, "waiting");
      CFRunLoopRun();
    } else fprintf(stderr, "\rCould not start com.apple.mobile.installd\n");
  } else fprintf(stderr, "\rPlease specify the path to the staged "
    "application\n");
  return 1;
}

// vim:ft=objc
