#include <CoreFoundation/CoreFoundation.h>
#include <Foundation/Foundation.h>

int main(int argc, char **argv) {
  if (argc > 1) {
    NSString*     path = [NSString stringWithCString:argv[0]
      encoding:NSASCIIStringEncoding];
    NSDictionary* info = [NSDictionary dictionaryWithObjectsAndKeys:
      path, @"application-path", nil];
    fprintf(stderr, "Posting install request notification...");
    CFNotificationCenterPostNotification(
      CFNotificationCenterGetDarwinNotifyCenter(),
      CFSTR("com.clayfreeman.appstash.install"), NULL,
      (CFDictionaryRef)info, true);
    return 0;
  }
  return 1;
}

// vim:ft=objc
