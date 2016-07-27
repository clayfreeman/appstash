#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <Foundation/NSTask.h>

extern "C" CFNotificationCenterRef CFNotificationCenterGetDistributedCenter();

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
  NSString*     path    = [info objectForKey:@"Path"];
  NSString*     error   =
    [ (__bridge NSDictionary*)userInfo objectForKey:@"error"];
  if (success == NO) {
    fprintf(stderr, "\rERROR: %s\n", [error UTF8String]);
    exit(1);
  } else fprintf(stderr, "\rInstalled %s to %s\n", [ident UTF8String],
    [path UTF8String]), exit(0);
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
      // Dispatch the install request notification with the user info dictionary
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
