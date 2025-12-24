#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

@interface UROSWMApplication : NSApplication <NSApplicationDelegate>

+ (UROSWMApplication *)sharedApplication;

@end