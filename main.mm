#include <CoreFoundation/CoreFoundation.h>
#include <Foundation/Foundation.h>

extern "C" CFNotificationCenterRef CFNotificationCenterGetDistributedCenter();

void receiveAppInstallResponseNotification(CFNotificationCenterRef center,
    void *observer, CFStringRef name, const void *object,
    CFDictionaryRef userInfo) {
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
    // Register function `receiveAppInstallResponseNotification` for
    // notification `com.clayfreeman.appstash.installrespose` in the Darwin
    // notification center
    CFNotificationCenterAddObserver(CFNotificationCenterGetDistributedCenter(),
      NULL, receiveAppInstallResponseNotification,
      CFSTR("com.clayfreeman.appstash.installresponse"), NULL,
      CFNotificationSuspensionBehaviorDeliverImmediately);
    NSString*     path = [NSString stringWithCString:argv[1]
      encoding:NSASCIIStringEncoding];
    NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:
      path, @"application-path", nil];
    fprintf(stderr, "Posting install request notification...\n");
    CFNotificationCenterPostNotification(
      CFNotificationCenterGetDistributedCenter(),
      CFSTR("com.clayfreeman.appstash.install"), NULL,
      (CFDictionaryRef)info, true);
    CFRunLoopRun();
  } fprintf(stderr, "Please specify the path to the staged application.\n");
  return 1;
}

// vim:ft=objc
