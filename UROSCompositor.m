//
//  UROSCompositor.m
//  uroswm - Full Compositing Window Manager
//
//  Provides compositing for ARGB frame windows with shadows and rounded corners.
//  Uses Manual redirect mode to composite windows properly.
//

#import "UROSCompositor.h"
#import <xcb/composite.h>
#import <xcb/damage.h>
#import <xcb/xcb_aux.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// Throttle compositing to ~60fps max
#define MIN_COMPOSITE_INTERVAL (1.0/60.0)

@implementation UROSCompositor

@synthesize isActive = _isActive;
@synthesize argbVisual;
@synthesize argbColormap;
@synthesize argbDepth;
@synthesize connection;
@synthesize damageEventBase;

- (instancetype)initWithConnection:(XCBConnection *)conn screen:(XCBScreen *)scr
{
    self = [super init];
    if (self) {
        connection = conn;
        screen = scr;
        _isActive = NO;
        isCompositing = NO;
        lastCompositeTime = 0;

        compositeSupported = NO;
        damageSupported = NO;
        damageEventBase = 0;

        argbVisual = NULL;
        argbColormap = XCB_NONE;
        argbDepth = 0;

        backBuffer = XCB_NONE;
        backSurface = NULL;
        backContext = NULL;

        trackedWindows = [[NSMutableSet alloc] init];
        windowDamage = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [self stop];
}

#pragma mark - Extension Queries

- (BOOL)checkExtensions
{
    xcb_connection_t *conn = [connection connection];

    // Check Composite extension
    const xcb_query_extension_reply_t *compositeExt =
        xcb_get_extension_data(conn, &xcb_composite_id);

    if (compositeExt && compositeExt->present) {
        xcb_composite_query_version_cookie_t versionCookie =
            xcb_composite_query_version(conn, 0, 4);
        xcb_composite_query_version_reply_t *versionReply =
            xcb_composite_query_version_reply(conn, versionCookie, NULL);

        if (versionReply) {
            NSLog(@"UROSCompositor: Composite extension version %d.%d",
                  versionReply->major_version, versionReply->minor_version);
            compositeSupported = YES;
            free(versionReply);
        }
    }

    // Check Damage extension
    const xcb_query_extension_reply_t *damageExt =
        xcb_get_extension_data(conn, &xcb_damage_id);

    if (damageExt && damageExt->present) {
        xcb_damage_query_version_cookie_t damageCookie =
            xcb_damage_query_version(conn, 1, 1);
        xcb_damage_query_version_reply_t *damageReply =
            xcb_damage_query_version_reply(conn, damageCookie, NULL);

        if (damageReply) {
            NSLog(@"UROSCompositor: Damage extension version %d.%d",
                  damageReply->major_version, damageReply->minor_version);
            damageSupported = YES;
            damageEventBase = damageExt->first_event;
            free(damageReply);
        }
    }

    if (!compositeSupported) {
        NSLog(@"UROSCompositor: Composite extension not available");
    }
    if (!damageSupported) {
        NSLog(@"UROSCompositor: Damage extension not available");
    }

    return compositeSupported && damageSupported;
}

- (BOOL)findARGBVisual
{
    xcb_connection_t *conn = [connection connection];
    xcb_screen_t *scr = [screen screen];

    // Find a 32-bit ARGB visual
    xcb_depth_iterator_t depthIter = xcb_screen_allowed_depths_iterator(scr);

    for (; depthIter.rem; xcb_depth_next(&depthIter)) {
        if (depthIter.data->depth == 32) {
            xcb_visualtype_iterator_t visualIter =
                xcb_depth_visuals_iterator(depthIter.data);

            for (; visualIter.rem; xcb_visualtype_next(&visualIter)) {
                if (visualIter.data->_class == XCB_VISUAL_CLASS_TRUE_COLOR) {
                    argbVisual = visualIter.data;
                    argbDepth = 32;
                    NSLog(@"UROSCompositor: Found 32-bit ARGB visual: 0x%x",
                          argbVisual->visual_id);
                    break;
                }
            }
        }
        if (argbVisual) break;
    }

    if (!argbVisual) {
        NSLog(@"UROSCompositor: No 32-bit ARGB visual found");
        return NO;
    }

    // Create colormap for ARGB visual
    argbColormap = xcb_generate_id(conn);
    xcb_create_colormap(conn, XCB_COLORMAP_ALLOC_NONE,
                        argbColormap, scr->root, argbVisual->visual_id);

    NSLog(@"UROSCompositor: Created ARGB colormap: %u", argbColormap);

    return YES;
}

- (BOOL)createBackBuffer
{
    xcb_connection_t *conn = [connection connection];
    xcb_screen_t *scr = [screen screen];

    // Create pixmap for back buffer (use root visual depth for final output)
    backBuffer = xcb_generate_id(conn);
    xcb_create_pixmap(conn, scr->root_depth, backBuffer, scr->root,
                      scr->width_in_pixels, scr->height_in_pixels);

    // Create Cairo surface for the back buffer
    xcb_visualtype_t *rootVisual = xcb_aux_find_visual_by_id(scr, scr->root_visual);
    if (!rootVisual) {
        NSLog(@"UROSCompositor: Could not find root visual");
        return NO;
    }

    backSurface = cairo_xcb_surface_create(conn, backBuffer, rootVisual,
                                           scr->width_in_pixels, scr->height_in_pixels);

    if (cairo_surface_status(backSurface) != CAIRO_STATUS_SUCCESS) {
        NSLog(@"UROSCompositor: Failed to create Cairo back buffer surface");
        cairo_surface_destroy(backSurface);
        backSurface = NULL;
        return NO;
    }

    backContext = cairo_create(backSurface);

    NSLog(@"UROSCompositor: Created back buffer %ux%u",
          scr->width_in_pixels, scr->height_in_pixels);

    return YES;
}

#pragma mark - Compositing Control

- (void)start
{
    if (_isActive) return;

    NSLog(@"UROSCompositor: Starting compositor...");

    // Check extensions
    if (![self checkExtensions]) {
        NSLog(@"UROSCompositor: Required extensions not available, cannot start");
        return;
    }

    if (![self findARGBVisual]) {
        NSLog(@"UROSCompositor: No ARGB visual available");
        // Continue anyway - we can still composite without ARGB
    }

    xcb_connection_t *conn = [connection connection];
    xcb_screen_t *scr = [screen screen];

    // Use AUTOMATIC mode - X server handles basic compositing,
    // but ARGB windows can still have transparency
    // This is simpler than MANUAL mode where we'd paint everything ourselves
    xcb_void_cookie_t redirectCookie = xcb_composite_redirect_subwindows_checked(
        conn, scr->root, XCB_COMPOSITE_REDIRECT_AUTOMATIC);

    xcb_generic_error_t *error = xcb_request_check(conn, redirectCookie);
    if (error) {
        NSLog(@"UROSCompositor: Failed to redirect subwindows (error %d) - another compositor running?",
              error->error_code);
        free(error);
        return;
    }

    NSLog(@"UROSCompositor: Redirected subwindows to AUTOMATIC mode");

    xcb_flush(conn);

    _isActive = YES;
    NSLog(@"UROSCompositor: Started successfully (AUTOMATIC mode - X server handles compositing)");
}

- (void)scanExistingWindows
{
    xcb_connection_t *conn = [connection connection];
    xcb_screen_t *scr = [screen screen];

    // Query existing children of root
    xcb_query_tree_cookie_t treeCookie = xcb_query_tree(conn, scr->root);
    xcb_query_tree_reply_t *treeReply = xcb_query_tree_reply(conn, treeCookie, NULL);

    if (treeReply) {
        xcb_window_t *children = xcb_query_tree_children(treeReply);
        int numChildren = xcb_query_tree_children_length(treeReply);

        NSLog(@"UROSCompositor: Found %d existing windows", numChildren);

        for (int i = 0; i < numChildren; i++) {
            xcb_window_t win = children[i];

            // Check if window is mapped
            xcb_get_window_attributes_cookie_t attrCookie = xcb_get_window_attributes(conn, win);
            xcb_get_window_attributes_reply_t *attrReply = xcb_get_window_attributes_reply(conn, attrCookie, NULL);

            if (attrReply && attrReply->map_state == XCB_MAP_STATE_VIEWABLE) {
                [self trackWindow:win];
            }

            if (attrReply) free(attrReply);
        }

        free(treeReply);
    }
}

- (void)stop
{
    if (!_isActive) return;

    xcb_connection_t *conn = [connection connection];
    xcb_screen_t *scr = [screen screen];

    // Clean up damage objects
    for (NSNumber *damageNum in [windowDamage allValues]) {
        xcb_damage_destroy(conn, [damageNum unsignedIntValue]);
    }

    // Free back buffer resources
    if (backContext) {
        cairo_destroy(backContext);
        backContext = NULL;
    }
    if (backSurface) {
        cairo_surface_destroy(backSurface);
        backSurface = NULL;
    }
    if (backBuffer != XCB_NONE) {
        xcb_free_pixmap(conn, backBuffer);
        backBuffer = XCB_NONE;
    }

    // Unredirect subwindows
    xcb_composite_unredirect_subwindows(conn, scr->root, XCB_COMPOSITE_REDIRECT_AUTOMATIC);

    // Free colormap
    if (argbColormap != XCB_NONE) {
        xcb_free_colormap(conn, argbColormap);
        argbColormap = XCB_NONE;
    }

    [trackedWindows removeAllObjects];
    [windowDamage removeAllObjects];

    xcb_flush(conn);

    argbVisual = NULL;
    argbDepth = 0;
    _isActive = NO;

    NSLog(@"UROSCompositor: Stopped");
}

#pragma mark - Window Tracking

- (void)trackWindow:(xcb_window_t)window
{
    if (!_isActive) return;

    NSNumber *winNum = @(window);
    if ([trackedWindows containsObject:winNum]) return;

    [trackedWindows addObject:winNum];

    // Create damage tracking for this window
    if (damageSupported) {
        xcb_connection_t *conn = [connection connection];
        xcb_damage_damage_t damage = xcb_generate_id(conn);

        xcb_void_cookie_t damageCookie = xcb_damage_create_checked(
            conn, damage, window, XCB_DAMAGE_REPORT_LEVEL_NON_EMPTY);

        xcb_generic_error_t *error = xcb_request_check(conn, damageCookie);
        if (!error) {
            windowDamage[@(window)] = @(damage);
        } else {
            free(error);
        }
    }

    NSLog(@"UROSCompositor: Tracking window %u (total: %lu)", window, (unsigned long)[trackedWindows count]);
}

- (void)untrackWindow:(xcb_window_t)window
{
    NSNumber *winNum = @(window);
    if (![trackedWindows containsObject:winNum]) return;

    [trackedWindows removeObject:winNum];

    // Destroy damage object
    NSNumber *damageNum = windowDamage[@(window)];
    if (damageNum) {
        xcb_damage_destroy([connection connection], [damageNum unsignedIntValue]);
        [windowDamage removeObjectForKey:@(window)];
    }

    NSLog(@"UROSCompositor: Untracked window %u (remaining: %lu)", window, (unsigned long)[trackedWindows count]);
}

- (BOOL)isWindowTracked:(xcb_window_t)window
{
    return [trackedWindows containsObject:@(window)];
}

#pragma mark - Damage Handling

- (void)handleDamageEvent:(xcb_window_t)window
                        x:(int16_t)x y:(int16_t)y
                    width:(uint16_t)width height:(uint16_t)height
{
    if (!_isActive) return;

    // Subtract the damage region so we don't get infinite events
    NSNumber *damageNum = windowDamage[@(window)];
    if (damageNum) {
        xcb_damage_subtract([connection connection], [damageNum unsignedIntValue],
                           XCB_NONE, XCB_NONE);
    }

    // Recomposite the screen
    [self compositeScreen];
}

#pragma mark - Compositing

- (void)compositeScreen
{
    // In AUTOMATIC mode, X server handles compositing
    // We just provide ARGB visual info for windows that need transparency
    // No manual compositing needed
}

- (void)compositeWindow:(xcb_window_t)window
{
    xcb_connection_t *conn = [connection connection];
    xcb_screen_t *scr = [screen screen];

    // Get window attributes
    xcb_get_window_attributes_cookie_t attrCookie = xcb_get_window_attributes(conn, window);
    xcb_get_window_attributes_reply_t *attrReply = xcb_get_window_attributes_reply(conn, attrCookie, NULL);

    if (!attrReply) {
        return;
    }

    // Skip unmapped windows
    if (attrReply->map_state != XCB_MAP_STATE_VIEWABLE) {
        free(attrReply);
        return;
    }

    static int windowLogCount = 0;
    windowLogCount++;
    if (windowLogCount <= 20) {
        NSLog(@"UROSCompositor: Painting window %u (visual 0x%x, map_state %d)",
              window, attrReply->visual, attrReply->map_state);
    }

    // Get window geometry
    xcb_get_geometry_cookie_t geomCookie = xcb_get_geometry(conn, window);
    xcb_get_geometry_reply_t *geomReply = xcb_get_geometry_reply(conn, geomCookie, NULL);

    if (!geomReply) {
        free(attrReply);
        return;
    }

    // Get window's contents pixmap using Composite extension
    xcb_pixmap_t pixmap = xcb_generate_id(conn);
    xcb_void_cookie_t pixmapCookie = xcb_composite_name_window_pixmap_checked(conn, window, pixmap);
    xcb_generic_error_t *pixmapError = xcb_request_check(conn, pixmapCookie);
    if (pixmapError) {
        // Window might not have backing pixmap yet (e.g., newly created)
        if (windowLogCount <= 20) {
            NSLog(@"UROSCompositor: Skipped window %u - no backing pixmap (error %d)",
                  window, pixmapError->error_code);
        }
        free(pixmapError);
        free(geomReply);
        free(attrReply);
        return;
    }

    // Determine if this is an ARGB window
    BOOL isArgb = NO;
    xcb_depth_iterator_t depthIter = xcb_screen_allowed_depths_iterator(scr);
    for (; depthIter.rem; xcb_depth_next(&depthIter)) {
        if (depthIter.data->depth == 32) {
            xcb_visualtype_iterator_t visualIter = xcb_depth_visuals_iterator(depthIter.data);
            for (; visualIter.rem; xcb_visualtype_next(&visualIter)) {
                if (visualIter.data->visual_id == attrReply->visual) {
                    isArgb = YES;
                    break;
                }
            }
        }
        if (isArgb) break;
    }

    // Find the visual type for this window
    xcb_visualtype_t *visual = xcb_aux_find_visual_by_id(scr, attrReply->visual);
    if (!visual) {
        xcb_free_pixmap(conn, pixmap);
        free(geomReply);
        free(attrReply);
        return;
    }

    // Create Cairo surface for window contents
    cairo_surface_t *winSurface = cairo_xcb_surface_create(
        conn, pixmap, visual, geomReply->width, geomReply->height);

    cairo_status_t surfaceStatus = cairo_surface_status(winSurface);
    if (surfaceStatus == CAIRO_STATUS_SUCCESS) {
        // Draw shadow first (only for tracked frame windows)
        if ([trackedWindows containsObject:@(window)]) {
            [self drawShadowAt:geomReply->x y:geomReply->y
                         width:geomReply->width height:geomReply->height];
        }

        // Draw window contents
        cairo_set_operator(backContext, isArgb ? CAIRO_OPERATOR_OVER : CAIRO_OPERATOR_SOURCE);
        cairo_set_source_surface(backContext, winSurface, geomReply->x, geomReply->y);
        cairo_paint(backContext);

        if (windowLogCount <= 20) {
            NSLog(@"UROSCompositor: Painted window %u at (%d,%d) size %dx%d isARGB=%d",
                  window, geomReply->x, geomReply->y, geomReply->width, geomReply->height, isArgb);
        }
    } else {
        NSLog(@"UROSCompositor: Failed to create surface for window %u: %s",
              window, cairo_status_to_string(surfaceStatus));
    }

    cairo_surface_destroy(winSurface);
    xcb_free_pixmap(conn, pixmap);
    free(geomReply);
    free(attrReply);
}

- (void)drawShadowAt:(int16_t)x y:(int16_t)y width:(uint16_t)width height:(uint16_t)height
{
    // Draw drop shadow behind window
    int shadowX = x + SHADOW_OFFSET_X;
    int shadowY = y + SHADOW_OFFSET_Y;

    cairo_save(backContext);
    cairo_set_operator(backContext, CAIRO_OPERATOR_OVER);

    // Multi-pass shadow for soft edges
    for (int pass = SHADOW_RADIUS; pass >= 1; pass--) {
        double alpha = SHADOW_OPACITY * (1.0 - (double)pass / SHADOW_RADIUS);
        cairo_set_source_rgba(backContext, 0, 0, 0, alpha);

        // Rounded rectangle shadow
        double r = CORNER_RADIUS;
        double sx = shadowX - pass;
        double sy = shadowY - pass;
        double sw = width + pass * 2;
        double sh = height + pass * 2;

        cairo_new_path(backContext);
        cairo_move_to(backContext, sx + r, sy);
        cairo_line_to(backContext, sx + sw - r, sy);
        cairo_arc(backContext, sx + sw - r, sy + r, r, -M_PI / 2, 0);
        cairo_line_to(backContext, sx + sw, sy + sh - r);
        cairo_arc(backContext, sx + sw - r, sy + sh - r, r, 0, M_PI / 2);
        cairo_line_to(backContext, sx + r, sy + sh);
        cairo_arc(backContext, sx + r, sy + sh - r, r, M_PI / 2, M_PI);
        cairo_line_to(backContext, sx, sy + r);
        cairo_arc(backContext, sx + r, sy + r, r, M_PI, 3 * M_PI / 2);
        cairo_close_path(backContext);

        cairo_fill(backContext);
    }

    cairo_restore(backContext);
}

@end
