#import "UROSWMApplication.h"

@implementation UROSWMApplication

+ (UROSWMApplication *)sharedApplication
{
    static UROSWMApplication *sharedInstance = nil;

    if (sharedInstance == nil) {
        if (NSApp == nil) {
            sharedInstance = [[UROSWMApplication alloc] init];
            // Set ourselves as the global NSApp
            NSApp = sharedInstance;
        } else {
            // NSApp already exists, cast it to our type
            sharedInstance = (UROSWMApplication *)NSApp;
        }
    }

    return sharedInstance;
}

- (void)finishLaunching
{
    // DON'T call super finishLaunching to prevent dock icon appearance
    // This is the key trick used by Menu.app
    // [super finishLaunching];

    // Set up our window manager without showing in dock
    // The delegate will handle the actual window manager setup
}

@end