#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <Foundation/NSTask.h>

extern "C" CFNotificationCenterRef CFNotificationCenterGetDistributedCenter();

void receiveAppInstallResponseNotification(CFNotificationCenterRef, void*,
    CFStringRef, const void*, CFDictionaryRef userInfo) {
  // Log when receiving a notification
  fprintf(stderr, "Received notification "
    "'com.clayfreeman.appstash.installresponse'\n");
  // Retreive the path supplied in the userInfo dictionary
  NSString* path = [(NSDictionary*)userInfo objectForKey:@"application-path"];
  fprintf(stderr, "path: %s\n", [path UTF8String]);
  exit(0);
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
      fprintf(stderr, "Posting install request notification...\n");
      // Dispatch the install request notification with the user info dictionary
      CFNotificationCenterPostNotification(
        CFNotificationCenterGetDistributedCenter(),
        CFSTR("com.clayfreeman.appstash.install"), NULL,
        (CFDictionaryRef)info, true);
      // Continue in a CF run loop while waiting for a response
      CFRunLoopRun();
    } else fprintf(stderr, "Could not start com.apple.mobile.installd\n");
  } else fprintf(stderr, "Please specify the path to the staged application\n");
  return 1;
}

// vim:ft=objc
