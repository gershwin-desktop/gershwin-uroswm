#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

@interface Application : NSApplication <NSApplicationDelegate>

+ (Application *)sharedApplication;

@end