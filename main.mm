#include <CoreFoundation/CoreFoundation.h>
#include <Foundation/Foundation.h>

extern "C" CFNotificationCenterRef CFNotificationCenterGetDistributedCenter();

void receiveAppInstallResponseNotification(CFNotificationCenterRef center,
    void *observer, CFStringRef name, const void *object,
    CFDictionaryRef userInfo) {
  // Log when receiving a notification
  fprintf(stderr, "Received notification "
    "'com.clayfreeman.appstash.installresponse'\n");
  exit(0);
}

int main(int argc, char **argv) {
  if (argc > 1) {
    // Register function `receiveAppInstallResponseNotification` for
    // notification `com.clayfreeman.appstash.install-respose` in the Darwin
    // notification center
    CFNotificationCenterAddObserver(CFNotificationCenterGetDistributedCenter(),
      NULL, receiveAppInstallResponseNotification,
      CFSTR("com.clayfreeman.appstash.installresponse"), NULL,
      CFNotificationSuspensionBehaviorDeliverImmediately);
    NSString*     path = [NSString stringWithCString:argv[0]
      encoding:NSASCIIStringEncoding];
    NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:
      path, @"application-path", nil];
    fprintf(stderr, "Posting install request notification...\n");
    CFNotificationCenterPostNotification(
      CFNotificationCenterGetDistributedCenter(),
      CFSTR("com.clayfreeman.appstash.install"), NULL,
      (CFDictionaryRef)info, true);
    CFRunLoopRun();
    return 0;
  }
  return 1;
}

// vim:ft=objc
