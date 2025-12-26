//
//  UROSWindowDecorator.m
//  uroswm - Window Decoration with ARGB Frames
//
//  Creates window decorations using 32-bit ARGB visuals for smooth
//  anti-aliased rounded corners. Shadows are rendered by the compositor.
//

#import "UROSWindowDecorator.h"
#import <cairo/cairo.h>
#import <cairo/cairo-xcb.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// Frame configuration
static const int kTitlebarHeight = 25;
static const int kCornerRadius = CORNER_RADIUS;

// Storage
static NSMutableDictionary *windowTitlebars = nil;
static NSMutableDictionary *frameWindows = nil;  // clientWindow -> frameWindow
static NSMutableDictionary *clientWindows = nil; // frameWindow -> clientWindow
static NSMutableDictionary *frameSizes = nil;    // frameWindow -> NSValue(NSSize)
static UROSCompositor *sharedCompositor = nil;

@implementation UROSWindowDecorator

+ (void)initialize {
    if (self == [UROSWindowDecorator class]) {
        windowTitlebars = [[NSMutableDictionary alloc] init];
        frameWindows = [[NSMutableDictionary alloc] init];
        clientWindows = [[NSMutableDictionary alloc] init];
        frameSizes = [[NSMutableDictionary alloc] init];
    }
}

+ (void)setCompositor:(UROSCompositor*)compositor {
    sharedCompositor = compositor;
    if (compositor && compositor.isActive) {
        NSLog(@"UROSWindowDecorator: Using ARGB visual 0x%x for frame windows",
              compositor.argbVisual->visual_id);
    }
}

+ (void)decorateWindow:(xcb_window_t)clientWindow
        withConnection:(XCBConnection*)connection
                 title:(NSString*)title {

    NSLog(@"UROSWindowDecorator: Decorating window %u with ARGB frame", clientWindow);

    // Get client window geometry
    xcb_get_geometry_cookie_t geom_cookie = xcb_get_geometry([connection connection], clientWindow);
    xcb_get_geometry_reply_t *geom_reply = xcb_get_geometry_reply([connection connection], geom_cookie, NULL);

    if (!geom_reply) {
        NSLog(@"UROSWindowDecorator: Failed to get geometry for window %u", clientWindow);
        return;
    }

    // Create ARGB frame window
    xcb_window_t frameWindow = [self createARGBFrameWindow:connection
                                                  geometry:geom_reply
                                              clientWindow:clientWindow];

    if (frameWindow == XCB_NONE) {
        NSLog(@"UROSWindowDecorator: Failed to create ARGB frame");
        free(geom_reply);
        return;
    }

    // Store mappings
    NSString *clientKey = [NSString stringWithFormat:@"%u", clientWindow];
    NSString *frameKey = [NSString stringWithFormat:@"%u", frameWindow];
    frameWindows[clientKey] = @(frameWindow);
    clientWindows[frameKey] = @(clientWindow);

    // Calculate total frame size (no shadow padding needed - compositor handles shadows)
    uint16_t frameWidth = geom_reply->width;
    uint16_t frameHeight = geom_reply->height + kTitlebarHeight;
    frameSizes[frameKey] = [NSValue valueWithSize:NSMakeSize(frameWidth, frameHeight)];

    // Calculate titlebar position
    NSRect titlebarFrame = NSMakeRect(0, 0, geom_reply->width, kTitlebarHeight);

    // Create our independent titlebar with matching ARGB visual
    uint8_t depth = 24;
    xcb_visualtype_t *visual = NULL;
    xcb_colormap_t colormap = XCB_NONE;

    if (sharedCompositor && sharedCompositor.isActive && sharedCompositor.argbVisual) {
        depth = 32;
        visual = sharedCompositor.argbVisual;
        colormap = sharedCompositor.argbColormap;
    }

    UROSTitleBar *titlebar = [[UROSTitleBar alloc] initWithConnection:connection
                                                                frame:titlebarFrame
                                                         parentWindow:frameWindow
                                                                depth:depth
                                                               visual:visual
                                                             colormap:colormap];

    [titlebar setTitle:title];
    [titlebar show];

    // Reparent client window into frame, below titlebar
    [self reparentClientWindow:clientWindow
                     intoFrame:frameWindow
                    connection:connection
                   clientWidth:geom_reply->width
                  clientHeight:geom_reply->height];

    // Store titlebar for this client window
    windowTitlebars[clientKey] = titlebar;

    // Render the frame with rounded corners
    [self renderFrame:frameWindow];

    // Register frame with compositor for shadow tracking
    if (sharedCompositor && sharedCompositor.isActive) {
        [sharedCompositor trackWindow:frameWindow];
    }

    // Show the frame window
    xcb_map_window([connection connection], frameWindow);
    [connection flush];

    // Trigger compositor to render
    if (sharedCompositor && sharedCompositor.isActive) {
        [sharedCompositor compositeScreen];
    }

    free(geom_reply);

    NSLog(@"UROSWindowDecorator: Window %u decorated with ARGB frame %u", clientWindow, frameWindow);
}

+ (xcb_window_t)createARGBFrameWindow:(XCBConnection*)connection
                             geometry:(xcb_get_geometry_reply_t*)geom
                         clientWindow:(xcb_window_t)clientWindow {

    XCBScreen *screen = [[connection screens] objectAtIndex:0];
    xcb_connection_t *conn = [connection connection];

    // Frame size (no shadow padding - compositor draws shadows separately)
    uint16_t frameWidth = geom->width;
    uint16_t frameHeight = geom->height + kTitlebarHeight;

    // Position frame
    int16_t frameX = geom->x;
    int16_t frameY = geom->y - kTitlebarHeight;

    xcb_window_t frameWindow = xcb_generate_id(conn);

    // Check if we have ARGB visual available
    if (sharedCompositor && sharedCompositor.isActive && sharedCompositor.argbVisual) {
        // Create 32-bit ARGB frame window
        uint32_t mask = XCB_CW_BACK_PIXMAP | XCB_CW_BORDER_PIXEL | XCB_CW_COLORMAP | XCB_CW_EVENT_MASK;
        uint32_t values[4];
        values[0] = XCB_BACK_PIXMAP_NONE;  // No background - we paint everything
        values[1] = 0;  // No border
        values[2] = sharedCompositor.argbColormap;
        values[3] = XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT | XCB_EVENT_MASK_SUBSTRUCTURE_NOTIFY |
                    XCB_EVENT_MASK_EXPOSURE;

        xcb_create_window(conn,
                          32,  // 32-bit depth for ARGB
                          frameWindow,
                          [screen screen]->root,
                          frameX, frameY,
                          frameWidth, frameHeight,
                          0,  // No border
                          XCB_WINDOW_CLASS_INPUT_OUTPUT,
                          sharedCompositor.argbVisual->visual_id,
                          mask,
                          values);

        NSLog(@"UROSWindowDecorator: Created ARGB frame %u (%dx%d) with 32-bit visual",
              frameWindow, frameWidth, frameHeight);
    } else {
        // Fallback to standard visual
        uint32_t mask = XCB_CW_BACK_PIXEL | XCB_CW_EVENT_MASK;
        uint32_t values[2];
        values[0] = [screen screen]->white_pixel;
        values[1] = XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT | XCB_EVENT_MASK_SUBSTRUCTURE_NOTIFY |
                    XCB_EVENT_MASK_EXPOSURE;

        xcb_create_window(conn,
                          XCB_COPY_FROM_PARENT,
                          frameWindow,
                          [screen screen]->root,
                          frameX, frameY,
                          frameWidth, frameHeight,
                          1,
                          XCB_WINDOW_CLASS_INPUT_OUTPUT,
                          [screen screen]->root_visual,
                          mask,
                          values);

        NSLog(@"UROSWindowDecorator: Created fallback frame %u (%dx%d)",
              frameWindow, frameWidth, frameHeight);
    }

    return frameWindow;
}

+ (void)reparentClientWindow:(xcb_window_t)clientWindow
                   intoFrame:(xcb_window_t)frameWindow
                  connection:(XCBConnection*)connection
                 clientWidth:(uint16_t)clientWidth
                clientHeight:(uint16_t)clientHeight {

    // Position client window inside frame, below titlebar
    int16_t clientX = 0;
    int16_t clientY = kTitlebarHeight;

    xcb_reparent_window([connection connection],
                        clientWindow,
                        frameWindow,
                        clientX, clientY);

    NSLog(@"UROSWindowDecorator: Reparented client %u into frame %u at (%d, %d)",
          clientWindow, frameWindow, clientX, clientY);
}

+ (void)renderFrame:(xcb_window_t)frameWindow {
    if (!sharedCompositor || !sharedCompositor.isActive || !sharedCompositor.argbVisual) {
        return;
    }

    NSString *frameKey = [NSString stringWithFormat:@"%u", frameWindow];
    NSValue *sizeValue = frameSizes[frameKey];
    if (!sizeValue) return;

    NSSize frameSize = [sizeValue sizeValue];
    uint16_t width = (uint16_t)frameSize.width;
    uint16_t height = (uint16_t)frameSize.height;

    xcb_connection_t *conn = [sharedCompositor.connection connection];

    // Create Cairo surface for the frame window
    cairo_surface_t *surface = cairo_xcb_surface_create(
        conn,
        frameWindow,
        sharedCompositor.argbVisual,
        width,
        height
    );

    if (cairo_surface_status(surface) != CAIRO_STATUS_SUCCESS) {
        NSLog(@"UROSWindowDecorator: Failed to create Cairo surface for frame %u", frameWindow);
        cairo_surface_destroy(surface);
        return;
    }

    cairo_t *cr = cairo_create(surface);

    // Clear with full transparency
    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
    cairo_set_source_rgba(cr, 0, 0, 0, 0);
    cairo_paint(cr);

    // Draw frame background with rounded corners at top only
    cairo_set_operator(cr, CAIRO_OPERATOR_OVER);

    // Draw rounded rectangle (top corners rounded, bottom square)
    double r = kCornerRadius;
    cairo_new_path(cr);
    cairo_move_to(cr, r, 0);
    cairo_line_to(cr, width - r, 0);
    cairo_arc(cr, width - r, r, r, -M_PI / 2, 0);
    cairo_line_to(cr, width, height);
    cairo_line_to(cr, 0, height);
    cairo_line_to(cr, 0, r);
    cairo_arc(cr, r, r, r, M_PI, 3 * M_PI / 2);
    cairo_close_path(cr);

    // Fill with semi-opaque background (titlebar area will be overdrawn)
    cairo_set_source_rgba(cr, 0.9, 0.9, 0.9, 1.0);
    cairo_fill(cr);

    cairo_surface_flush(surface);
    cairo_destroy(cr);
    cairo_surface_destroy(surface);

    xcb_flush(conn);
}

+ (xcb_window_t)frameWindowForClient:(xcb_window_t)clientWindow {
    NSString *clientKey = [NSString stringWithFormat:@"%u", clientWindow];
    NSNumber *frameNum = frameWindows[clientKey];
    return frameNum ? [frameNum unsignedIntValue] : XCB_NONE;
}

+ (void)updateFrameForClient:(xcb_window_t)clientWindow
                  connection:(XCBConnection*)connection
                       width:(uint16_t)width
                      height:(uint16_t)height {

    NSString *clientKey = [NSString stringWithFormat:@"%u", clientWindow];
    NSNumber *frameWindowNum = frameWindows[clientKey];

    if (!frameWindowNum) return;

    xcb_window_t frameWindow = [frameWindowNum unsignedIntValue];
    NSString *frameKey = [NSString stringWithFormat:@"%u", frameWindow];

    // Calculate new frame size
    uint16_t frameWidth = width;
    uint16_t frameHeight = height + kTitlebarHeight;

    // Update stored size
    frameSizes[frameKey] = [NSValue valueWithSize:NSMakeSize(frameWidth, frameHeight)];

    // Resize frame window
    uint32_t values[2];
    values[0] = frameWidth;
    values[1] = frameHeight;
    xcb_configure_window([connection connection], frameWindow,
                         XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT, values);

    // Re-render frame
    [self renderFrame:frameWindow];

    // Update titlebar
    UROSTitleBar *titlebar = windowTitlebars[clientKey];
    if (titlebar) {
        NSRect newTitlebarFrame = NSMakeRect(0, 0, width, kTitlebarHeight);
        [titlebar updateFrame:newTitlebarFrame];
    }

    // Trigger compositor to re-render
    if (sharedCompositor && sharedCompositor.isActive) {
        [sharedCompositor compositeScreen];
    }

    NSLog(@"UROSWindowDecorator: Updated frame %u to %dx%d", frameWindow, frameWidth, frameHeight);
}

+ (void)updateWindowTitle:(xcb_window_t)clientWindow title:(NSString*)title {
    UROSTitleBar *titlebar = [self titlebarForWindow:clientWindow];
    if (titlebar) {
        [titlebar setTitle:title];
        NSLog(@"UROSWindowDecorator: Updated title for window %u: %@", clientWindow, title);
    }
}

+ (void)setWindowActive:(xcb_window_t)clientWindow active:(BOOL)active {
    UROSTitleBar *titlebar = [self titlebarForWindow:clientWindow];
    if (titlebar) {
        [titlebar setActive:active];
        NSLog(@"UROSWindowDecorator: Set window %u active: %d", clientWindow, active);
    }
}

+ (void)undecoateWindow:(xcb_window_t)clientWindow {
    NSString *clientKey = [NSString stringWithFormat:@"%u", clientWindow];

    // Untrack from compositor
    NSNumber *frameWindowNum = frameWindows[clientKey];
    if (frameWindowNum && sharedCompositor && sharedCompositor.isActive) {
        [sharedCompositor untrackWindow:[frameWindowNum unsignedIntValue]];
    }

    // Clean up titlebar
    UROSTitleBar *titlebar = windowTitlebars[clientKey];
    if (titlebar) {
        [titlebar destroy];
        [windowTitlebars removeObjectForKey:clientKey];
    }

    // Clean up frame references
    if (frameWindowNum) {
        NSString *frameKey = [NSString stringWithFormat:@"%u", [frameWindowNum unsignedIntValue]];
        [clientWindows removeObjectForKey:frameKey];
        [frameSizes removeObjectForKey:frameKey];
    }
    [frameWindows removeObjectForKey:clientKey];

    // Trigger compositor to update
    if (sharedCompositor && sharedCompositor.isActive) {
        [sharedCompositor compositeScreen];
    }

    NSLog(@"UROSWindowDecorator: Undecorated window %u", clientWindow);
}

+ (UROSTitleBar*)titlebarForWindow:(xcb_window_t)clientWindow {
    NSString *windowKey = [NSString stringWithFormat:@"%u", clientWindow];
    return windowTitlebars[windowKey];
}

+ (BOOL)handleExposeEvent:(xcb_expose_event_t*)event {
    xcb_window_t window = event->window;

    // Check if this is a frame window
    NSString *frameKey = [NSString stringWithFormat:@"%u", window];
    if (clientWindows[frameKey]) {
        // Re-render the frame
        [self renderFrame:window];
        // Trigger compositor
        if (sharedCompositor && sharedCompositor.isActive) {
            [sharedCompositor compositeScreen];
        }
        return YES;
    }

    // Check if this is a titlebar window
    for (UROSTitleBar *titlebar in [windowTitlebars allValues]) {
        if (titlebar.windowId == window) {
            [titlebar renderWithGSTheme];
            // Trigger compositor
            if (sharedCompositor && sharedCompositor.isActive) {
                [sharedCompositor compositeScreen];
            }
            return YES;
        }
    }

    return NO;
}

+ (BOOL)handleButtonEvent:(xcb_button_press_event_t*)event {
    // Find titlebar that owns this window and handle button press
    for (UROSTitleBar *titlebar in [windowTitlebars allValues]) {
        if (titlebar.windowId == event->event) {
            [titlebar handleButtonPress:event];
            return YES;
        }
    }
    return NO;
}

@end
