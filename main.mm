// MIUninstaller

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <Foundation/NSTask.h>

extern "C" CFNotificationCenterRef CFNotificationCenterGetDistributedCenter();

int runProcess(NSString* path, NSArray* args) {
  // Setup the NSTask instance as specified
  NSTask* launch = [[NSTask alloc] init];
  launch.launchPath = path;
  launch.arguments  = args;
  [launch launch];
  // Wait until the process exits and retrieve its exit status
  [launch waitUntilExit];
  return [launch terminationStatus];
}

NSMutableDictionary* loadStashDB() {
  // Attempt to load the stash database
  NSMutableDictionary *stash = [NSJSONSerialization
    JSONObjectWithData:[NSData
      dataWithContentsOfFile: @"/private/var/db/stash/apps.json"]
    options:           NSJSONReadingMutableContainers
    error:             nil];
  // Ensure that the stash database contains the appropriate structure
  if (![stash isKindOfClass:[NSMutableDictionary class]] ||
       [stash objectForKey:@"apps"] == nil)
    fprintf(stderr, "ERROR: Unable to load apps.json\n"), exit(1);
  return stash;
}

void saveStashDB(NSDictionary* stash) {
  // Attempt to write the stash to disk
  if (![[NSJSONSerialization
        dataWithJSONObject: stash
        options:            nil
        error:              nil]
      writeToFile:@"/private/var/db/stash/apps.json" atomically:YES])
    fprintf(stderr, "ERROR: Unable to save apps.json\n"), exit(1);
}

void initializeApplicationStashDB() {
  // Setup some storage for reference return values and default structures
  BOOL    isDirectory = NO;
  NSData* defaultData = [NSJSONSerialization
    dataWithJSONObject: [NSDictionary dictionaryWithObjectsAndKeys:
      [NSDictionary dictionary], @"apps", nil]
    options:            nil
    error:              nil];
  // Ensure that `/private/var/db/stash` is a directory
  if (![[NSFileManager defaultManager]
      fileExistsAtPath: @"/private/var/db/stash"
      isDirectory:      &isDirectory] || !isDirectory)
    if (![[NSFileManager defaultManager]
        createDirectoryAtPath:       @"/private/var/db/stash"
        withIntermediateDirectories: YES
        attributes:                  nil
        error:                       nil])
      fprintf(stderr, "ERROR: Could not initialize stash dir\n"), exit(1);
  // Ensure that `/private/var/db/stash/apps.json` is a file
  if (![[NSFileManager defaultManager]
      fileExistsAtPath: @"/private/var/db/stash/apps.json"
      isDirectory:      &isDirectory] || isDirectory)
    if (![[NSFileManager defaultManager]
        createFileAtPath: @"/private/var/db/stash/apps.json"
        contents:         defaultData
        attributes:       [NSDictionary dictionaryWithObjectsAndKeys:
          @"root",                          NSFileOwnerAccountName,
          @"wheel",                         NSFileGroupOwnerAccountName,
          [NSNumber numberWithShort: 0660], NSFilePosixPermissions, nil]])
      fprintf(stderr, "ERROR: Could not initialize stash db\n"), exit(1);
  // Ensure that `/usr/libexec/cydia/setnsfpn` is called successfully for
  // `/private/var/db/stash` and `/private/var/containers/Bundle/Application`
  for (NSString* path in @[@"/private/var/db/stash",
                           @"/private/var/containers/Bundle/Application"]) {
    // Require the termination status of the task to be successful
    if (runProcess(@"/usr/libexec/cydia/setnsfpn", @[path]) != 0)
      fprintf(stderr, "ERROR: setnsfpn failed for %s\n",
        [path UTF8String]), exit(1);
   }
}

void addApplicationStashDB(NSString* ident, NSString* oldPath,
    NSString* newPath) {
  // Attempt to load the stash database
  NSMutableDictionary* stash = loadStashDB();
  // Add the requested entry
  [[stash objectForKey:@"apps"]
    setObject: [NSDictionary dictionaryWithObjectsAndKeys:
      oldPath, @"old-path",
      newPath, @"new-path", nil]
    forKey:    ident];
  // Serialize the changes back to disk
  saveStashDB(stash);
}

void delApplicationStashDB(NSString* ident) {
  // Attempt to load the stash database
  NSMutableDictionary* stash = loadStashDB();
  // Remove the requested entry
  [[stash objectForKey:@"apps"] setObject:[NSNull null] forKey:ident];
  [[stash objectForKey:@"apps"] removeObjectForKey:ident];
  // Serialize the changes back to disk
  saveStashDB(stash);
}

NSArray* listApplicationsStashDB() {
  // Attempt to load the stash database
  NSDictionary* stash = loadStashDB();
  // Return a list of all keys
  return [[stash objectForKey:@"apps"] allKeys];
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
    [[NSFileManager defaultManager] removeItemAtPath:oldPath error:nil];
    fprintf(stderr, "\rInstalled %s to %s\n", [ident UTF8String],
      [newPath UTF8String]);
    addApplicationStashDB(ident, oldPath, newPath);
    exit(0);
  }
}

NSString* copyPath(NSString* src, NSString* dst) {
  BOOL isDirectory = NO;
  // Ensure that `dst` is a directory
  if (![[NSFileManager defaultManager]
      fileExistsAtPath: dst
      isDirectory:      &isDirectory] || !isDirectory)
    if (![[NSFileManager defaultManager]
        createDirectoryAtPath:       dst
        withIntermediateDirectories: YES
        attributes:                  nil
        error:                       nil])
      fprintf(stderr, "ERROR: Could not initialize destination\n"), exit(1);
  // Attempt to copy the source path to the destination path
  if (![[NSFileManager defaultManager]
      fileExistsAtPath: src
      isDirectory:      &isDirectory])
    fprintf(stderr, "ERROR: Could not find '%s'\n", [src UTF8String]), exit(1);
  NSError* err = nil;
  // Build the destination path from the last component of `src`
  dst = [dst stringByAppendingPathComponent:[src lastPathComponent]];
  if (![[NSFileManager defaultManager]
      copyItemAtPath: src
      toPath:         dst
      error:          &err])
    fprintf(stderr, "ERROR: %s, %s, %s\n", [src UTF8String], [dst UTF8String],
      [[err localizedDescription] UTF8String]), exit(1);
  return dst;
}

NSString* movePath(NSString* src, NSString* dst) {
  BOOL isDirectory = NO;
  // Ensure that `dst` is a directory
  if (![[NSFileManager defaultManager]
      fileExistsAtPath: dst
      isDirectory:      &isDirectory] || !isDirectory)
    if (![[NSFileManager defaultManager]
        createDirectoryAtPath:       dst
        withIntermediateDirectories: YES
        attributes:                  nil
        error:                       nil])
      fprintf(stderr, "ERROR: Could not initialize destination\n"), exit(1);
  // Attempt to move the source path to the destination path
  if (![[NSFileManager defaultManager]
      fileExistsAtPath: src
      isDirectory:      &isDirectory])
    fprintf(stderr, "ERROR: Could not find '%s'\n", [src UTF8String]), exit(1);
  NSError* err = nil;
  // Build the destination path from the last component of `src`
  dst = [dst stringByAppendingPathComponent:[src lastPathComponent]];
  if (![[NSFileManager defaultManager]
      moveItemAtPath: src
      toPath:         dst
      error:          &err])
    fprintf(stderr, "ERROR: %s, %s, %s\n", [src UTF8String], [dst UTF8String],
      [[err localizedDescription] UTF8String]), exit(1);
  return dst;
}

void stashPath(NSString* path) {
  if (![path hasPrefix:@"/"])
    fprintf(stderr, "ERROR: Expecting absolute path\n"), exit(1);
  // Register function `receiveAppInstallResponseNotification` for
  // notification `com.clayfreeman.appstash.installrespose` in the Darwin
  // notification center
  CFNotificationCenterAddObserver(
    CFNotificationCenterGetDistributedCenter(),
    NULL, receiveAppInstallResponseNotification,
    CFSTR("com.clayfreeman.appstash.installresponse"), NULL,
    CFNotificationSuspensionBehaviorDeliverImmediately);
  fprintf(stderr, "Stashing %s ...\n", [path UTF8String]);
  // Copy the provided path to the staging area
  NSString* stagePath = copyPath(path,
    @"/private/var/mobile/Media/PublicStaging");
  // Build an NSDictionary from the user-provided path
  NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:
    stagePath, @"application-path",
    path,      @"old-path",         nil];
  // Dispatch the install request notification with the user info
  CFNotificationCenterPostNotification(
    CFNotificationCenterGetDistributedCenter(),
    CFSTR("com.clayfreeman.appstash.install"), NULL,
    (__bridge CFDictionaryRef)info, true);
  // Continue in a CF run loop while waiting for a response
  fprintf(stderr, "waiting");
  CFRunLoopRun();
}

void unstashIdent(NSString* ident) {
  // Load the stash database
  NSDictionary* stash = loadStashDB();
  // Find the requested identifier
  NSDictionary* app   = [[stash objectForKey:@"apps"] objectForKey:ident];
  if (app == nil) fprintf(stderr, "ERROR: Could not find stashed app "
    "identifier (case sensitive)\n"), exit(1);
  // Move the `new-path` to the `old-path`
  NSString* src =  [app objectForKey:@"new-path"];
  NSString* dst = [[app objectForKey:@"old-path"]
    stringByDeletingLastPathComponent];
  NSString* res = movePath(src, dst);
  // Remove the app identifier from the stash database
  delApplicationStashDB(ident);
  fprintf(stderr, "Moved %s to %s\n", [ident UTF8String],
    [res UTF8String]), exit(0);
}

int main(int argc, char **argv) {
  if (argc > 1) {
    // Use launchctl to start com.apple.mobile.installd
    if (runProcess( @"/bin/launchctl",
        @[@"start", @"com.apple.mobile.installd"]) == 0) {
      // Initialize the stash database
      initializeApplicationStashDB();
      // Determine the requested action
      NSString* action = [NSString stringWithCString:argv[1]
        encoding:NSASCIIStringEncoding];
      if ([action isEqualToString:@"-a"]) {
        if (argc > 2) {
          // Get the second argument
          NSString* path = [NSString stringWithCString:argv[2]
            encoding:NSASCIIStringEncoding];
          // Run the action
          stashPath(path);
        } else fprintf(stderr, "Missing application path argument\n"), exit(1);
      } else if ([action isEqualToString:@"-l"]) {
        NSArray* list = [listApplicationsStashDB()
          sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
        for (NSString* ident in list)
          fprintf(stderr, "%s\n", [ident UTF8String]);
        exit(0);
      } else if ([action isEqualToString:@"-r"]) {
        // Get the second argument
        NSString* ident = [NSString stringWithCString:argv[2]
          encoding:NSASCIIStringEncoding];
        // Run the action
        unstashIdent(ident);
      } else fprintf(stderr, "Unknown action '%s'\n", argv[1]);
    } else fprintf(stderr, "Could not start com.apple.mobile.installd\n");
  } else if (argc > 0)
    fprintf(stderr, "Please specify an action:\n"
      "  %s\n"
      "    -a /path/to/app    # Add app to stash\n"
      "    -l                 # List stashed apps\n"
      "    -r com.example.app # Restore stashed app\n", argv[0]);
  return 1;
}

// vim:ft=objc
