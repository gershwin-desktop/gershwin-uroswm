//
//  UROSCompositor.h
//  uroswm - Built-in Compositing Window Manager
//
//  Provides compositing for ARGB frame windows with shadows and rounded corners.
//  Uses Manual redirect mode to composite windows properly.
//

#import <Foundation/Foundation.h>
#import <XCBKit/XCBConnection.h>
#import <XCBKit/XCBScreen.h>
#import <XCBKit/XCBWindow.h>
#import <cairo/cairo.h>
#import <cairo/cairo-xcb.h>

// Shadow configuration
#define SHADOW_RADIUS 12
#define SHADOW_OFFSET_X 0
#define SHADOW_OFFSET_Y 5
#define SHADOW_OPACITY 0.35
#define CORNER_RADIUS 14

@interface UROSCompositor : NSObject
{
    XCBConnection *connection;
    XCBScreen *screen;

    // Extension support
    BOOL compositeSupported;
    BOOL damageSupported;
    uint8_t damageEventBase;

    // ARGB visual for transparent windows
    xcb_visualtype_t *argbVisual;
    xcb_colormap_t argbColormap;
    uint8_t argbDepth;

    // Compositing resources
    xcb_pixmap_t backBuffer;
    cairo_surface_t *backSurface;
    cairo_t *backContext;

    // Window tracking - only track windows we care about
    NSMutableSet *trackedWindows;
    NSMutableDictionary *windowDamage;

    // Prevent re-entrancy and throttling
    BOOL isCompositing;
    NSTimeInterval lastCompositeTime;
}

@property (nonatomic, readonly) BOOL isActive;
@property (nonatomic, readonly) xcb_visualtype_t *argbVisual;
@property (nonatomic, readonly) xcb_colormap_t argbColormap;
@property (nonatomic, readonly) uint8_t argbDepth;
@property (nonatomic, readonly) XCBConnection *connection;
@property (nonatomic, readonly) uint8_t damageEventBase;

// Initialization
- (instancetype)initWithConnection:(XCBConnection *)conn screen:(XCBScreen *)scr;

// Setup
- (BOOL)checkExtensions;
- (BOOL)findARGBVisual;
- (void)start;
- (void)stop;

// Window management - call these for windows that need compositing
- (void)trackWindow:(xcb_window_t)window;
- (void)untrackWindow:(xcb_window_t)window;
- (BOOL)isWindowTracked:(xcb_window_t)window;

// Damage handling
- (void)handleDamageEvent:(xcb_window_t)window
                        x:(int16_t)x y:(int16_t)y
                    width:(uint16_t)width height:(uint16_t)height;

// Compositing
- (void)compositeScreen;

@end
