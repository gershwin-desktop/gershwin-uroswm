//
//  URSThemeIntegration.h
//  uroswm - GSTheme Window Decoration for Titlebars
//
//  Renders actual GSTheme window decorations for X11 titlebars to match AppKit appearance.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSTheme.h>
#import <xcb/xcb.h>
#import "XCBWrapper.h"

// Titlebar button types
typedef NS_ENUM(NSInteger, GSThemeTitleBarButton) {
    GSThemeTitleBarButtonNone = 0,
    GSThemeTitleBarButtonClose = 1,
    GSThemeTitleBarButtonMiniaturize = 2,
    GSThemeTitleBarButtonZoom = 3
};

// Titlebar color states (from XCBKit)
typedef NS_ENUM(NSInteger, TitleBarColor) {
    TitleBarDownColor = 0,
    TitleBarUpColor = 1
};

@interface ThemeRenderer : NSObject

// Singleton access
+ (instancetype)sharedInstance;

// GSTheme initialization and management
+ (void)initializeGSTheme;
+ (GSTheme*)currentTheme;

// GSTheme titlebar rendering
+ (BOOL)renderGSThemeToWindow:(XCBWindow*)window
                        frame:(XCBFrame*)frame
                        title:(NSString*)title
                       active:(BOOL)isActive;


// Configuration
@property (assign, nonatomic) BOOL enabled;
@property (strong, nonatomic) NSMutableArray *managedTitlebars;

// Fixed-size window tracking (for hiding buttons except close)
+ (void)registerFixedSizeWindow:(xcb_window_t)windowId;
+ (void)unregisterFixedSizeWindow:(xcb_window_t)windowId;
+ (BOOL)isFixedSizeWindow:(xcb_window_t)windowId;

@end