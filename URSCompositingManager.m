//
//  URSCompositingManager.m
//  uroswm - XRender Compositing Manager
//
//  - Proper damage tracking and subtraction
//  - Window pixmap recreation on resize
//  - Double-buffered rendering
//  - Region-based partial repaints
//  - Proper resource cleanup
//

#import "URSCompositingManager.h"
#import <XCBKit/XCBScreen.h>
#import <xcb/xcb.h>
#import <xcb/composite.h>
#import <xcb/xfixes.h>
#import <xcb/render.h>
#import <xcb/damage.h>

// Per-window compositing data
@interface URSCompositeWindow : NSObject
@property (assign, nonatomic) xcb_window_t windowId;
@property (assign, nonatomic) xcb_damage_damage_t damage;
@property (assign, nonatomic) xcb_pixmap_t nameWindowPixmap;
@property (assign, nonatomic) xcb_render_picture_t picture;
@property (assign, nonatomic) xcb_xfixes_region_t borderSize;
@property (assign, nonatomic) xcb_xfixes_region_t extents;
@property (assign, nonatomic) BOOL damaged;
@property (assign, nonatomic) BOOL viewable;
@property (assign, nonatomic) BOOL redirected;
// Cached geometry
@property (assign, nonatomic) int16_t x;
@property (assign, nonatomic) int16_t y;
@property (assign, nonatomic) uint16_t width;
@property (assign, nonatomic) uint16_t height;
@property (assign, nonatomic) uint16_t borderWidth;
@property (assign, nonatomic) uint8_t depth;
@property (assign, nonatomic) xcb_visualid_t visual;
@end

@implementation URSCompositeWindow
- (instancetype)init {
    self = [super init];
    if (self) {
        _windowId = XCB_NONE;
        _damage = XCB_NONE;
        _nameWindowPixmap = XCB_NONE;
        _picture = XCB_NONE;
        _borderSize = XCB_NONE;
        _extents = XCB_NONE;
        _damaged = NO;
        _viewable = NO;
        _redirected = YES;
    }
    return self;
}
@end

@interface URSCompositingManager ()

@property (strong, nonatomic) XCBConnection *connection;
@property (assign, nonatomic) xcb_window_t overlayWindow;
@property (assign, nonatomic) xcb_window_t outputWindow;         // Child of overlay for actual rendering
@property (assign, nonatomic) xcb_render_picture_t rootPicture;
@property (assign, nonatomic) xcb_render_picture_t rootBuffer;   // Double buffer
@property (assign, nonatomic) xcb_pixmap_t rootPixmap;           // Backing pixmap for buffer
@property (strong, nonatomic) NSMutableDictionary<NSNumber *, URSCompositeWindow *> *cwindows;

@property (assign, nonatomic) BOOL compositingEnabled;
@property (assign, nonatomic) BOOL compositingActive;
@property (assign, nonatomic) BOOL extensionsAvailable;

// Accumulated damage region
@property (assign, nonatomic) xcb_xfixes_region_t allDamage;
@property (assign, nonatomic) xcb_xfixes_region_t screenRegion;

// Extension version tracking
@property (assign, nonatomic) uint8_t compositeOpcode;
@property (assign, nonatomic) uint8_t renderOpcode;
@property (assign, nonatomic) uint8_t damageEventBase;
@property (assign, nonatomic) uint8_t fixesOpcode;

// Throttling to prevent excessive recomposites
@property (assign, nonatomic) BOOL repairScheduled;

// Cached screen info
@property (assign, nonatomic) uint16_t screenWidth;
@property (assign, nonatomic) uint16_t screenHeight;
@property (assign, nonatomic) xcb_window_t rootWindow;
@property (assign, nonatomic) xcb_render_pictformat_t rootFormat;
@property (assign, nonatomic) xcb_render_pictformat_t argbFormat;

@end

@implementation URSCompositingManager

+ (instancetype)sharedManager {
    static URSCompositingManager *sharedManager = nil;
    @synchronized(self) {
        if (!sharedManager) {
            sharedManager = [[URSCompositingManager alloc] init];
        }
    }
    return sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _compositingEnabled = NO;
        _compositingActive = NO;
        _extensionsAvailable = NO;
        _overlayWindow = XCB_NONE;
        _outputWindow = XCB_NONE;
        _rootPicture = XCB_NONE;
        _rootBuffer = XCB_NONE;
        _rootPixmap = XCB_NONE;
        _allDamage = XCB_NONE;
        _screenRegion = XCB_NONE;
        _repairScheduled = NO;
        _cwindows = [[NSMutableDictionary alloc] init];
    }
    return self;
}

#pragma mark - Initialization

- (BOOL)initializeWithConnection:(XCBConnection *)connection {
    if (!connection) {
        NSLog(@"[CompositingManager] ERROR: No connection provided");
        return NO;
    }
    
    self.connection = connection;
    NSLog(@"[CompositingManager] Checking for required X extensions...");
    
    if (![self checkExtensions]) {
        NSLog(@"[CompositingManager] Required extensions not available");
        NSLog(@"[CompositingManager] Falling back to non-compositing mode");
        return NO;
    }
    
    // Cache screen info
    XCBScreen *screen = [[self.connection screens] firstObject];
    if (!screen) {
        NSLog(@"[CompositingManager] No screen available");
        return NO;
    }
    
    self.screenWidth = [screen screen]->width_in_pixels;
    self.screenHeight = [screen screen]->height_in_pixels;
    self.rootWindow = [screen screen]->root;
    
    // Find render formats
    if (![self findRenderFormats]) {
        NSLog(@"[CompositingManager] Failed to find render formats");
        return NO;
    }
    
    self.extensionsAvailable = YES;
    self.compositingEnabled = YES;
    NSLog(@"[CompositingManager] Initialization successful - compositing available");
    return YES;
}

- (BOOL)checkExtensions {
    @try {
        xcb_connection_t *conn = [self.connection connection];
        BOOL allExtensionsOK = YES;
        
        // Check COMPOSITE extension
        const xcb_query_extension_reply_t *composite_ext = 
            xcb_get_extension_data(conn, &xcb_composite_id);
        
        if (!composite_ext || !composite_ext->present) {
            NSLog(@"[CompositingManager] COMPOSITE extension not available");
            allExtensionsOK = NO;
        } else {
            self.compositeOpcode = composite_ext->major_opcode;
            
            xcb_composite_query_version_cookie_t version_cookie = 
                xcb_composite_query_version(conn, 
                                           XCB_COMPOSITE_MAJOR_VERSION, 
                                           XCB_COMPOSITE_MINOR_VERSION);
            xcb_composite_query_version_reply_t *version_reply = 
                xcb_composite_query_version_reply(conn, version_cookie, NULL);
            
            if (version_reply) {
                NSLog(@"[CompositingManager] COMPOSITE v%d.%d available", 
                      version_reply->major_version, version_reply->minor_version);
                // Need at least 0.2 for NameWindowPixmap
                if (version_reply->major_version == 0 && version_reply->minor_version < 2) {
                    NSLog(@"[CompositingManager] COMPOSITE version too old (need >= 0.2)");
                    allExtensionsOK = NO;
                }
                free(version_reply);
            }
        }
        
        // Check RENDER extension
        const xcb_query_extension_reply_t *render_ext = 
            xcb_get_extension_data(conn, &xcb_render_id);
        
        if (!render_ext || !render_ext->present) {
            NSLog(@"[CompositingManager] RENDER extension not available");
            allExtensionsOK = NO;
        } else {
            self.renderOpcode = render_ext->major_opcode;
            NSLog(@"[CompositingManager] RENDER extension available");
        }
        
        // Check DAMAGE extension
        const xcb_query_extension_reply_t *damage_ext = 
            xcb_get_extension_data(conn, &xcb_damage_id);
        
        if (!damage_ext || !damage_ext->present) {
            NSLog(@"[CompositingManager] DAMAGE extension not available");
            allExtensionsOK = NO;
        } else {
            self.damageEventBase = damage_ext->first_event;
            
            // Query DAMAGE version
            xcb_damage_query_version_cookie_t damage_version_cookie = 
                xcb_damage_query_version(conn, 
                                        XCB_DAMAGE_MAJOR_VERSION,
                                        XCB_DAMAGE_MINOR_VERSION);
            xcb_damage_query_version_reply_t *damage_version_reply =
                xcb_damage_query_version_reply(conn, damage_version_cookie, NULL);
            if (damage_version_reply) {
                NSLog(@"[CompositingManager] DAMAGE v%d.%d available (event base: %u)", 
                      damage_version_reply->major_version,
                      damage_version_reply->minor_version,
                      self.damageEventBase);
                free(damage_version_reply);
            }
        }
        
        // Check XFIXES extension
        const xcb_query_extension_reply_t *fixes_ext = 
            xcb_get_extension_data(conn, &xcb_xfixes_id);
        
        if (!fixes_ext || !fixes_ext->present) {
            NSLog(@"[CompositingManager] XFIXES extension not available");
            allExtensionsOK = NO;
        } else {
            self.fixesOpcode = fixes_ext->major_opcode;
            
            xcb_xfixes_query_version_cookie_t xfixes_cookie =
                xcb_xfixes_query_version(conn, 
                                        XCB_XFIXES_MAJOR_VERSION,
                                        XCB_XFIXES_MINOR_VERSION);
            xcb_xfixes_query_version_reply_t *xfixes_reply =
                xcb_xfixes_query_version_reply(conn, xfixes_cookie, NULL);
            if (xfixes_reply) {
                NSLog(@"[CompositingManager] XFIXES v%d.%d available", 
                      xfixes_reply->major_version, xfixes_reply->minor_version);
                free(xfixes_reply);
            }
        }
        
        return allExtensionsOK;
        
    } @catch (NSException *exception) {
        NSLog(@"[CompositingManager] EXCEPTION checking extensions: %@", exception.reason);
        return NO;
    }
}

- (BOOL)findRenderFormats {
    xcb_connection_t *conn = [self.connection connection];
    
    xcb_render_query_pict_formats_cookie_t formats_cookie = 
        xcb_render_query_pict_formats(conn);
    xcb_render_query_pict_formats_reply_t *formats_reply = 
        xcb_render_query_pict_formats_reply(conn, formats_cookie, NULL);
    
    if (!formats_reply) {
        NSLog(@"[CompositingManager] Failed to query render formats");
        return NO;
    }
    
    // Find format for root window (typically 24-bit RGB)
    self.rootFormat = XCB_NONE;
    self.argbFormat = XCB_NONE;
    
    xcb_render_pictforminfo_iterator_t iter = 
        xcb_render_query_pict_formats_formats_iterator(formats_reply);
    
    for (; iter.rem; xcb_render_pictforminfo_next(&iter)) {
        xcb_render_pictforminfo_t *fmt = iter.data;
        
        // Look for 24-bit format (RGB without alpha)
        if (fmt->depth == 24 && fmt->type == XCB_RENDER_PICT_TYPE_DIRECT) {
            if (self.rootFormat == XCB_NONE) {
                self.rootFormat = fmt->id;
            }
        }
        
        // Look for 32-bit ARGB format
        if (fmt->depth == 32 && fmt->type == XCB_RENDER_PICT_TYPE_DIRECT) {
            // Check if it has alpha
            if (fmt->direct.alpha_mask != 0) {
                self.argbFormat = fmt->id;
            }
        }
    }
    
    free(formats_reply);
    
    if (self.rootFormat == XCB_NONE) {
        NSLog(@"[CompositingManager] Could not find 24-bit render format");
        return NO;
    }
    
    NSLog(@"[CompositingManager] Found render formats - root: %u, argb: %u", 
          self.rootFormat, self.argbFormat);
    return YES;
}

#pragma mark - Activation

- (BOOL)activateCompositing {
    if (!self.compositingEnabled) {
        NSLog(@"[CompositingManager] Cannot activate - not initialized properly");
        return NO;
    }
    
    if (self.compositingActive) {
        NSLog(@"[CompositingManager] Compositing already active");
        return YES;
    }
    
    @try {
        NSLog(@"[CompositingManager] Activating compositing...");
        
        // Redirect all windows for compositing
        if (![self redirectWindows]) {
            NSLog(@"[CompositingManager] Failed to redirect windows");
            return NO;
        }
        
        // Create overlay window
        if (![self createOverlayWindow]) {
            NSLog(@"[CompositingManager] Failed to create overlay window");
            [self cleanup];
            return NO;
        }
        
        // Create root picture and buffer
        if (![self createRootBuffer]) {
            NSLog(@"[CompositingManager] Failed to create root buffer");
            [self cleanup];
            return NO;
        }
        
        // Add all existing windows
        [self addAllWindows];
        
        self.compositingActive = YES;
        NSLog(@"[CompositingManager] Compositing activated successfully");
        
        // Damage entire screen to trigger initial paint
        [self damageScreen];
        
        return YES;
        
    } @catch (NSException *exception) {
        NSLog(@"[CompositingManager] EXCEPTION activating compositing: %@", exception.reason);
        [self cleanup];
        return NO;
    }
}

- (BOOL)redirectWindows {
    @try {
        xcb_connection_t *conn = [self.connection connection];
        
        xcb_generic_error_t *error = NULL;
        xcb_void_cookie_t cookie = xcb_composite_redirect_subwindows_checked(
            conn, self.rootWindow, XCB_COMPOSITE_REDIRECT_MANUAL);
        error = xcb_request_check(conn, cookie);
        
        if (error) {
            NSLog(@"[CompositingManager] Error redirecting windows: %d", error->error_code);
            free(error);
            return NO;
        }
        
        [self.connection flush];
        NSLog(@"[CompositingManager] Windows redirected to offscreen buffers");
        return YES;
        
    } @catch (NSException *exception) {
        NSLog(@"[CompositingManager] EXCEPTION redirecting windows: %@", exception.reason);
        return NO;
    }
}

- (BOOL)createOverlayWindow {
    @try {
        xcb_connection_t *conn = [self.connection connection];
        XCBScreen *screen = [[self.connection screens] firstObject];
        
        xcb_composite_get_overlay_window_cookie_t overlay_cookie = 
            xcb_composite_get_overlay_window(conn, self.rootWindow);
        xcb_composite_get_overlay_window_reply_t *overlay_reply = 
            xcb_composite_get_overlay_window_reply(conn, overlay_cookie, NULL);
        
        if (!overlay_reply) {
            NSLog(@"[CompositingManager] Failed to get overlay window");
            return NO;
        }
        
        self.overlayWindow = overlay_reply->overlay_win;
        free(overlay_reply);
        
        NSLog(@"[CompositingManager] Got overlay window: %u", self.overlayWindow);
        
        // Map the overlay window first
        xcb_map_window(conn, self.overlayWindow);
        
        // Make overlay window transparent to input using XFixes
        // ShapeBounding = 0 means use default (full window visible)
        // ShapeInput = empty region means no input captured
        xcb_xfixes_region_t region = xcb_generate_id(conn);
        xcb_xfixes_create_region(conn, region, 0, NULL);
        
        // Setting to 0 resets to default bounding shape (full rectangle)
        xcb_xfixes_set_window_shape_region(conn, self.overlayWindow,
                                           XCB_SHAPE_SK_BOUNDING, 0, 0, XCB_NONE);

        // Empty region = no input captured, all input passes through
        xcb_xfixes_set_window_shape_region(conn, self.overlayWindow,
                                           XCB_SHAPE_SK_INPUT, 0, 0, region);
        xcb_xfixes_destroy_region(conn, region);
        
        // Create a child window inside overlay for actual rendering
        self.outputWindow = xcb_generate_id(conn);
        xcb_create_window(conn,
                         [screen screen]->root_depth,
                         self.outputWindow,
                         self.overlayWindow,  // Parent is the overlay
                         0, 0,
                         self.screenWidth, self.screenHeight,
                         0,  // border_width
                         XCB_WINDOW_CLASS_INPUT_OUTPUT,
                         [screen screen]->root_visual,
                         0, NULL);
        
        xcb_map_window(conn, self.outputWindow);
        [self.connection flush];
        
        NSLog(@"[CompositingManager] Overlay window created with output child: overlay=%u, output=%u", 
              self.overlayWindow, self.outputWindow);
        return YES;
        
    } @catch (NSException *exception) {
        NSLog(@"[CompositingManager] EXCEPTION creating overlay: %@", exception.reason);
        return NO;
    }
}

- (BOOL)createRootBuffer {
    @try {
        xcb_connection_t *conn = [self.connection connection];
        XCBScreen *screen = [[self.connection screens] firstObject];
        
        // Create picture for output window
        // Use IncludeInferiors
        self.rootPicture = xcb_generate_id(conn);
        uint32_t pa_mask = XCB_RENDER_CP_SUBWINDOW_MODE;
        uint32_t pa_values[] = { XCB_SUBWINDOW_MODE_INCLUDE_INFERIORS };
        xcb_render_create_picture(conn, self.rootPicture, 
                                 self.outputWindow, self.rootFormat, pa_mask, pa_values);
        
        // Create backing pixmap for double buffering
        self.rootPixmap = xcb_generate_id(conn);
        xcb_create_pixmap(conn, [screen screen]->root_depth, self.rootPixmap,
                         self.rootWindow, self.screenWidth, self.screenHeight);
        
        // Create picture for the buffer
        self.rootBuffer = xcb_generate_id(conn);
        xcb_render_create_picture(conn, self.rootBuffer,
                                 self.rootPixmap, self.rootFormat, 0, NULL);
        
        [self.connection flush];
        NSLog(@"[CompositingManager] Root buffer created (%dx%d)", 
              self.screenWidth, self.screenHeight);
        return YES;
        
    } @catch (NSException *exception) {
        NSLog(@"[CompositingManager] EXCEPTION creating root buffer: %@", exception.reason);
        return NO;
    }
}

- (void)addAllWindows {
    xcb_connection_t *conn = [self.connection connection];
    
    xcb_query_tree_cookie_t tree_cookie = xcb_query_tree(conn, self.rootWindow);
    xcb_query_tree_reply_t *tree_reply = xcb_query_tree_reply(conn, tree_cookie, NULL);
    
    if (!tree_reply) {
        NSLog(@"[CompositingManager] Failed to query window tree");
        return;
    }
    
    xcb_window_t *children = xcb_query_tree_children(tree_reply);
    int num_children = xcb_query_tree_children_length(tree_reply);
    
    for (int i = 0; i < num_children; i++) {
        [self addWindow:children[i]];
    }
    
    free(tree_reply);
    NSLog(@"[CompositingManager] Added %d existing windows", num_children);
}

#pragma mark - Window Management

- (URSCompositeWindow *)findCWindow:(xcb_window_t)windowId {
    return self.cwindows[@(windowId)];
}

- (void)addWindow:(xcb_window_t)windowId {
    if (!self.compositingActive) {
        return;
    }
    
    // Skip our own compositor windows
    if (windowId == self.overlayWindow || windowId == self.rootWindow || 
        windowId == self.outputWindow) {
        return;
    }
    
    if ([self findCWindow:windowId]) {
        return; // Already added
    }
    
    xcb_connection_t *conn = [self.connection connection];
    
    // Get window attributes
    xcb_get_window_attributes_cookie_t attr_cookie = xcb_get_window_attributes(conn, windowId);
    xcb_get_window_attributes_reply_t *attr = xcb_get_window_attributes_reply(conn, attr_cookie, NULL);
    
    if (!attr) {
        return;
    }
    
    // Skip InputOnly windows
    if (attr->_class == XCB_WINDOW_CLASS_INPUT_ONLY) {
        free(attr);
        return;
    }
    
    // Get geometry
    xcb_get_geometry_cookie_t geom_cookie = xcb_get_geometry(conn, windowId);
    xcb_get_geometry_reply_t *geom = xcb_get_geometry_reply(conn, geom_cookie, NULL);
    
    if (!geom) {
        free(attr);
        return;
    }
    
    URSCompositeWindow *cw = [[URSCompositeWindow alloc] init];
    cw.windowId = windowId;
    cw.x = geom->x;
    cw.y = geom->y;
    cw.width = geom->width;
    cw.height = geom->height;
    cw.borderWidth = geom->border_width;
    cw.depth = geom->depth;
    cw.visual = attr->visual;
    cw.viewable = (attr->map_state == XCB_MAP_STATE_VIEWABLE);
    cw.redirected = YES;
    
    // Create damage object for the window
    cw.damage = xcb_generate_id(conn);
    xcb_damage_create(conn, cw.damage, windowId, XCB_DAMAGE_REPORT_LEVEL_NON_EMPTY);
    
    self.cwindows[@(windowId)] = cw;
    
    free(attr);
    free(geom);
    
    [self.connection flush];
}

- (void)registerWindow:(xcb_window_t)window {
    [self addWindow:window];
}

- (void)unregisterWindow:(xcb_window_t)window {
    [self removeWindow:window];
}

- (void)removeWindow:(xcb_window_t)windowId {
    if (!self.compositingActive) {
        return;
    }
    
    URSCompositeWindow *cw = [self findCWindow:windowId];
    if (!cw) {
        return;
    }
    
    // Damage the area where the window was
    if (cw.viewable) {
        [self damageWindowArea:cw];
    }
    
    [self freeWindowData:cw delete:YES];
    [self.cwindows removeObjectForKey:@(windowId)];
}

- (void)freeWindowData:(URSCompositeWindow *)cw delete:(BOOL)shouldDelete {
    xcb_connection_t *conn = [self.connection connection];
    
    if (cw.nameWindowPixmap != XCB_NONE) {
        xcb_free_pixmap(conn, cw.nameWindowPixmap);
        cw.nameWindowPixmap = XCB_NONE;
    }
    
    if (cw.picture != XCB_NONE) {
        xcb_render_free_picture(conn, cw.picture);
        cw.picture = XCB_NONE;
    }
    
    if (cw.borderSize != XCB_NONE) {
        xcb_xfixes_destroy_region(conn, cw.borderSize);
        cw.borderSize = XCB_NONE;
    }
    
    if (cw.extents != XCB_NONE) {
        xcb_xfixes_destroy_region(conn, cw.extents);
        cw.extents = XCB_NONE;
    }
    
    if (shouldDelete && cw.damage != XCB_NONE) {
        xcb_damage_destroy(conn, cw.damage);
        cw.damage = XCB_NONE;
    }
    
    cw.damaged = NO;
}

- (void)updateWindow:(xcb_window_t)window {
    if (!self.compositingActive) {
        return;
    }
    
    URSCompositeWindow *cw = [self findCWindow:window];
    if (!cw) {
        return;
    }
    
    // Damage the window's area
    [self damageWindowArea:cw];
}

- (void)resizeWindow:(xcb_window_t)windowId x:(int16_t)x y:(int16_t)y 
               width:(uint16_t)width height:(uint16_t)height {
    if (!self.compositingActive) {
        return;
    }
    
    URSCompositeWindow *cw = [self findCWindow:windowId];
    if (!cw) {
        return;
    }
    
    xcb_connection_t *conn = [self.connection connection];
    
    // If visible, damage the old area
    if (cw.viewable) {
        [self damageWindowArea:cw];
    }
    
    // If size changed, we need to recreate the pixmap and picture
    if (cw.width != width || cw.height != height) {
        if (cw.nameWindowPixmap != XCB_NONE) {
            xcb_free_pixmap(conn, cw.nameWindowPixmap);
            cw.nameWindowPixmap = XCB_NONE;
        }
        if (cw.picture != XCB_NONE) {
            xcb_render_free_picture(conn, cw.picture);
            cw.picture = XCB_NONE;
        }
    }
    
    // If position or size changed, invalidate regions
    if (cw.width != width || cw.height != height || cw.x != x || cw.y != y) {
        if (cw.borderSize != XCB_NONE) {
            xcb_xfixes_destroy_region(conn, cw.borderSize);
            cw.borderSize = XCB_NONE;
        }
        if (cw.extents != XCB_NONE) {
            xcb_xfixes_destroy_region(conn, cw.extents);
            cw.extents = XCB_NONE;
        }
    }
    
    // Update cached geometry
    cw.x = x;
    cw.y = y;
    cw.width = width;
    cw.height = height;
    
    // Damage the new area
    if (cw.viewable) {
        [self damageWindowArea:cw];
    }
}

- (void)mapWindow:(xcb_window_t)windowId {
    URSCompositeWindow *cw = [self findCWindow:windowId];
    if (!cw) {
        [self addWindow:windowId];
        cw = [self findCWindow:windowId];
    }
    
    if (cw) {
        cw.viewable = YES;
        cw.damaged = NO;
        [self damageWindowArea:cw];
    }
}

- (void)unmapWindow:(xcb_window_t)windowId {
    URSCompositeWindow *cw = [self findCWindow:windowId];
    if (!cw) {
        return;
    }
    
    if (cw.viewable) {
        [self damageWindowArea:cw];
    }
    
    cw.viewable = NO;
    cw.damaged = NO;
    
    // Free window data but keep the damage object
    [self freeWindowData:cw delete:NO];
}

#pragma mark - Damage Handling

- (void)handleDamageNotify:(xcb_window_t)windowId {
    if (!self.compositingActive) {
        return;
    }
    
    URSCompositeWindow *cw = [self findCWindow:windowId];
    
    // If the damaged window is not directly tracked, it might be a child window
    // (like a titlebar). Find its parent frame window.
    if (!cw) {
        xcb_window_t parentFrame = [self findParentFrameWindow:windowId];
        if (parentFrame != XCB_NONE) {
            cw = [self findCWindow:parentFrame];
        }
    }
    
    if (!cw || !cw.damage) {
        return;
    }
    
    [self repairWindow:cw];
}

// Find the parent window that we're tracking (frame window)
- (xcb_window_t)findParentFrameWindow:(xcb_window_t)childWindow {
    xcb_connection_t *conn = [self.connection connection];
    xcb_window_t current = childWindow;
    
    // Walk up the window tree to find a tracked parent
    for (int depth = 0; depth < 10; depth++) { // Limit depth to prevent infinite loops
        xcb_query_tree_cookie_t tree_cookie = xcb_query_tree(conn, current);
        xcb_query_tree_reply_t *tree_reply = xcb_query_tree_reply(conn, tree_cookie, NULL);
        
        if (!tree_reply) {
            return XCB_NONE;
        }
        
        xcb_window_t parent = tree_reply->parent;
        free(tree_reply);
        
        if (parent == self.rootWindow || parent == XCB_NONE) {
            return XCB_NONE; // Reached root without finding tracked window
        }
        
        // Check if this parent is tracked
        if ([self findCWindow:parent]) {
            return parent;
        }
        
        current = parent;
    }
    
    return XCB_NONE;
}

- (void)repairWindow:(URSCompositeWindow *)cw {
    xcb_connection_t *conn = [self.connection connection];
    xcb_xfixes_region_t parts;
    
    // NOTE: We do NOT free the picture on damage - the underlying NameWindowPixmap
    // is automatically updated by the X server, and Pictures created from it
    // will reflect the updated content.
    // (Picture is only freed when window size changes or window is removed)
    
    if (cw.damaged) {
        // Window was already damaged before, get the damaged parts
        parts = xcb_generate_id(conn);
        xcb_xfixes_create_region(conn, parts, 0, NULL);
        
        // Subtract damage from window, copying to parts region
        xcb_damage_subtract(conn, cw.damage, XCB_NONE, parts);
        
        // Translate to screen coordinates
        xcb_xfixes_translate_region(conn, parts, 
                                    cw.x + cw.borderWidth,
                                    cw.y + cw.borderWidth);
    } else {
        // First damage on this window - use full extents
        parts = [self windowExtents:cw];
        
        // Clear all damage
        xcb_damage_subtract(conn, cw.damage, XCB_NONE, XCB_NONE);
    }
    
    if (parts != XCB_NONE) {
        [self addDamage:parts];
        cw.damaged = YES;
    }
}

- (void)damageScreen {
    xcb_xfixes_region_t region = [self getScreenRegion];
    [self addDamage:region];
}

- (void)damageWindowArea:(URSCompositeWindow *)cw {
    xcb_xfixes_region_t extents = [self windowExtents:cw];
    if (extents != XCB_NONE) {
        [self addDamage:extents];
    }
}

- (void)addDamage:(xcb_xfixes_region_t)damage {
    if (damage == XCB_NONE) {
        return;
    }
    
    xcb_connection_t *conn = [self.connection connection];
    
    // Clip to screen region
    if (self.screenRegion == XCB_NONE) {
        self.screenRegion = [self getScreenRegion];
    }
    xcb_xfixes_intersect_region(conn, damage, damage, self.screenRegion);
    
    if (self.allDamage != XCB_NONE) {
        // Union with existing damage
        xcb_xfixes_union_region(conn, self.allDamage, self.allDamage, damage);
        xcb_xfixes_destroy_region(conn, damage);
    } else {
        self.allDamage = damage;
    }
    
    [self scheduleRepair];
}

- (xcb_xfixes_region_t)windowExtents:(URSCompositeWindow *)cw {
    xcb_connection_t *conn = [self.connection connection];
    
    xcb_rectangle_t r;
    r.x = cw.x;
    r.y = cw.y;
    r.width = cw.width + 2 * cw.borderWidth;
    r.height = cw.height + 2 * cw.borderWidth;
    
    xcb_xfixes_region_t region = xcb_generate_id(conn);
    xcb_xfixes_create_region(conn, region, 1, &r);
    return region;
}

- (xcb_xfixes_region_t)getScreenRegion {
    xcb_connection_t *conn = [self.connection connection];
    
    xcb_rectangle_t r;
    r.x = 0;
    r.y = 0;
    r.width = self.screenWidth;
    r.height = self.screenHeight;
    
    xcb_xfixes_region_t region = xcb_generate_id(conn);
    xcb_xfixes_create_region(conn, region, 1, &r);
    return region;
}

#pragma mark - Compositing

- (void)scheduleRepair {
    if (self.repairScheduled) {
        return;
    }
    
    self.repairScheduled = YES;
    
    // Use a short delay to batch multiple damage events
    // Using performSelector for GNUstep compatibility (no libdispatch)
    [self performSelector:@selector(performRepair) withObject:nil afterDelay:0.001];
}

- (void)performRepair {
    self.repairScheduled = NO;
    
    if (!self.compositingActive || self.allDamage == XCB_NONE) {
        return;
    }
    
    xcb_xfixes_region_t damage = self.allDamage;
    self.allDamage = XCB_NONE;
    
    [self paintAll:damage];
    
    xcb_xfixes_destroy_region([self.connection connection], damage);
}

- (void)scheduleComposite {
    [self scheduleRepair];
}

- (void)compositeScreen {
    [self damageScreen];
}

- (void)paintAll:(xcb_xfixes_region_t)region {
    xcb_connection_t *conn = [self.connection connection];
    
    if (self.rootBuffer == XCB_NONE) {
        return;
    }
    
    // Get list of all windows in stacking order
    xcb_query_tree_cookie_t tree_cookie = xcb_query_tree(conn, self.rootWindow);
    xcb_query_tree_reply_t *tree_reply = xcb_query_tree_reply(conn, tree_cookie, NULL);
    
    if (!tree_reply) {
        return;
    }
    
    xcb_window_t *children = xcb_query_tree_children(tree_reply);
    int num_children = xcb_query_tree_children_length(tree_reply);
    
    // Create a copy of the region for painting
    xcb_xfixes_region_t paint_region = xcb_generate_id(conn);
    xcb_xfixes_create_region(conn, paint_region, 0, NULL);
    xcb_xfixes_copy_region(conn, region, paint_region);
    
    // Paint background in damaged areas
    xcb_xfixes_set_picture_clip_region(conn, self.rootBuffer, paint_region, 0, 0);
    xcb_render_color_t bg_color = {0x3333, 0x3333, 0x3333, 0xFFFF}; // Dark gray background
    xcb_rectangle_t bg_rect = {0, 0, self.screenWidth, self.screenHeight};
    xcb_render_fill_rectangles(conn, XCB_RENDER_PICT_OP_SRC,
                               self.rootBuffer, bg_color, 1, &bg_rect);
    
    // Paint windows from bottom to top (so higher z-order windows are on top)
    int windowsPainted = 0;
    for (int i = 0; i < num_children; i++) {
        xcb_window_t win = children[i];
        
        // Skip overlay and output windows (our own compositor windows)
        if (win == self.overlayWindow || win == self.outputWindow) {
            continue;
        }
        
        URSCompositeWindow *cw = [self findCWindow:win];
        if (!cw) {
            // Window not tracked yet, try to add it
            [self addWindow:win];
            cw = [self findCWindow:win];
        }
        if (!cw || !cw.viewable) {
            continue;
        }
        
        windowsPainted++;
        // Set clip region to entire damaged area
        xcb_xfixes_set_picture_clip_region(conn, self.rootBuffer, paint_region, 0, 0);
        
        // Paint the window - IncludeInferiors captures all child content
        [self paintWindow:cw atX:cw.x atY:cw.y withClipRegion:paint_region];
    }
    
    xcb_xfixes_destroy_region(conn, paint_region);
    
    // Copy buffer to screen (overlay window)
    // Get bounds of damaged region for efficient copy
    xcb_xfixes_fetch_region_cookie_t fetch_cookie = 
        xcb_xfixes_fetch_region(conn, region);
    xcb_xfixes_fetch_region_reply_t *fetch_reply =
        xcb_xfixes_fetch_region_reply(conn, fetch_cookie, NULL);
    
    if (fetch_reply) {
        xcb_rectangle_t bounds = fetch_reply->extents;
        
        xcb_xfixes_set_picture_clip_region(conn, self.rootPicture, region, 0, 0);
        xcb_render_composite(conn,
                            XCB_RENDER_PICT_OP_SRC,
                            self.rootBuffer,
                            XCB_NONE,
                            self.rootPicture,
                            bounds.x, bounds.y,
                            0, 0,
                            bounds.x, bounds.y,
                            bounds.width, bounds.height);
        
        free(fetch_reply);
    }
    
    free(tree_reply);
    [self.connection flush];
    
    NSLog(@"[CompositingManager] paintAll: painted %d windows out of %d children", windowsPainted, num_children);
}

// Paint a window - IncludeInferiors in the picture handles child windows automatically
- (void)paintWindow:(URSCompositeWindow *)cw 
                atX:(int16_t)screenX 
                atY:(int16_t)screenY 
     withClipRegion:(xcb_xfixes_region_t)clipRegion {
    
    xcb_connection_t *conn = [self.connection connection];
    
    // Ensure we have a picture for this window
    if (cw.picture == XCB_NONE) {
        cw.picture = [self getWindowPicture:cw];
    }
    
    if (cw.picture != XCB_NONE) {
        // Paint the window - IncludeInferiors captures all child content
        // (titlebar, buttons, client content, etc.)
        xcb_xfixes_set_picture_clip_region(conn, self.rootBuffer, clipRegion, 0, 0);
        xcb_render_composite(conn,
                            XCB_RENDER_PICT_OP_OVER,
                            cw.picture,
                            XCB_NONE,
                            self.rootBuffer,
                            0, 0,
                            0, 0,
                            screenX, screenY,
                            cw.width + 2 * cw.borderWidth,
                            cw.height + 2 * cw.borderWidth);
    }
    // No need to recursively paint children - IncludeInferiors handles that
}

// Note: Child window painting is handled automatically by IncludeInferiors
// No need for explicit recursive painting

- (xcb_render_picture_t)getWindowPicture:(URSCompositeWindow *)cw {
    xcb_connection_t *conn = [self.connection connection];
    xcb_drawable_t draw = cw.windowId;
    
    // Use NameWindowPixmap (the redirected offscreen storage) for proper content capture
    // Try to get the name_window_pixmap first
    if (cw.nameWindowPixmap == XCB_NONE) {
        cw.nameWindowPixmap = xcb_generate_id(conn);
        xcb_void_cookie_t cookie = xcb_composite_name_window_pixmap_checked(conn, cw.windowId, cw.nameWindowPixmap);
        xcb_generic_error_t *error = xcb_request_check(conn, cookie);
        if (error) {
            // Failed to get named pixmap, use window directly
            cw.nameWindowPixmap = XCB_NONE;
            free(error);
        }
    }
    
    // Use the named pixmap if available, otherwise fall back to window drawable
    if (cw.nameWindowPixmap != XCB_NONE) {
        draw = cw.nameWindowPixmap;
    }
    
    // Find appropriate format for this window's visual
    xcb_render_pictformat_t format = [self findVisualFormat:cw.visual];
    if (format == XCB_NONE) {
        // Fall back to depth-based format
        format = [self findFormatForDepth:cw.depth];
    }
    if (format == XCB_NONE) {
        NSLog(@"[CompositingManager] No format for visual %d depth %d", cw.visual, cw.depth);
        return XCB_NONE;
    }
    
    // Create picture with IncludeInferiors
    // This ensures child window content (like titlebar decorations) is captured
    xcb_render_picture_t picture = xcb_generate_id(conn);
    uint32_t pa_mask = XCB_RENDER_CP_SUBWINDOW_MODE;
    uint32_t pa_values[] = { XCB_SUBWINDOW_MODE_INCLUDE_INFERIORS };
    xcb_render_create_picture(conn, picture, draw, format, pa_mask, pa_values);
    
    return picture;
}

- (xcb_render_pictformat_t)findVisualFormat:(xcb_visualid_t)visual {
    xcb_connection_t *conn = [self.connection connection];
    
    xcb_render_query_pict_formats_cookie_t formats_cookie = 
        xcb_render_query_pict_formats(conn);
    xcb_render_query_pict_formats_reply_t *formats_reply = 
        xcb_render_query_pict_formats_reply(conn, formats_cookie, NULL);
    
    if (!formats_reply) {
        return XCB_NONE;
    }
    
    xcb_render_pictformat_t format = XCB_NONE;
    
    // Iterate through screens to find the matching visual
    xcb_render_pictscreen_iterator_t screen_iter = 
        xcb_render_query_pict_formats_screens_iterator(formats_reply);
    
    for (; screen_iter.rem; xcb_render_pictscreen_next(&screen_iter)) {
        xcb_render_pictdepth_iterator_t depth_iter = 
            xcb_render_pictscreen_depths_iterator(screen_iter.data);
        
        for (; depth_iter.rem; xcb_render_pictdepth_next(&depth_iter)) {
            xcb_render_pictvisual_iterator_t visual_iter = 
                xcb_render_pictdepth_visuals_iterator(depth_iter.data);
            
            for (; visual_iter.rem; xcb_render_pictvisual_next(&visual_iter)) {
                if (visual_iter.data->visual == visual) {
                    format = visual_iter.data->format;
                    break;
                }
            }
            if (format != XCB_NONE) break;
        }
        if (format != XCB_NONE) break;
    }
    
    free(formats_reply);
    return format;
}

- (xcb_render_pictformat_t)findFormatForDepth:(uint8_t)depth {
    xcb_connection_t *conn = [self.connection connection];
    
    xcb_render_query_pict_formats_cookie_t formats_cookie = 
        xcb_render_query_pict_formats(conn);
    xcb_render_query_pict_formats_reply_t *formats_reply = 
        xcb_render_query_pict_formats_reply(conn, formats_cookie, NULL);
    
    if (!formats_reply) {
        return XCB_NONE;
    }
    
    xcb_render_pictformat_t format = XCB_NONE;
    xcb_render_pictforminfo_iterator_t iter = 
        xcb_render_query_pict_formats_formats_iterator(formats_reply);
    
    for (; iter.rem; xcb_render_pictforminfo_next(&iter)) {
        if (iter.data->depth == depth) {
            format = iter.data->id;
            break;
        }
    }
    
    free(formats_reply);
    return format;
}

- (uint8_t)damageEventBase {
    return _damageEventBase;
}

#pragma mark - Deactivation & Cleanup

- (void)deactivateCompositing {
    if (!self.compositingActive) {
        return;
    }
    
    NSLog(@"[CompositingManager] Deactivating compositing...");
    
    @try {
        xcb_connection_t *conn = [self.connection connection];
        
        // Unredirect windows
        xcb_composite_unredirect_subwindows(conn, self.rootWindow,
                                           XCB_COMPOSITE_REDIRECT_MANUAL);
        
        [self cleanup];
        self.compositingActive = NO;
        NSLog(@"[CompositingManager] Compositing deactivated");
        
    } @catch (NSException *exception) {
        NSLog(@"[CompositingManager] EXCEPTION deactivating: %@", exception.reason);
    }
}

- (void)cleanup {
    @try {
        xcb_connection_t *conn = [self.connection connection];
        
        // Free all window data
        for (NSNumber *key in [self.cwindows allKeys]) {
            URSCompositeWindow *cw = self.cwindows[key];
            [self freeWindowData:cw delete:YES];
        }
        [self.cwindows removeAllObjects];
        
        // Free damage regions
        if (self.allDamage != XCB_NONE) {
            xcb_xfixes_destroy_region(conn, self.allDamage);
            self.allDamage = XCB_NONE;
        }
        
        if (self.screenRegion != XCB_NONE) {
            xcb_xfixes_destroy_region(conn, self.screenRegion);
            self.screenRegion = XCB_NONE;
        }
        
        // Free root buffer and picture
        if (self.rootBuffer != XCB_NONE) {
            xcb_render_free_picture(conn, self.rootBuffer);
            self.rootBuffer = XCB_NONE;
        }
        
        if (self.rootPixmap != XCB_NONE) {
            xcb_free_pixmap(conn, self.rootPixmap);
            self.rootPixmap = XCB_NONE;
        }
        
        if (self.rootPicture != XCB_NONE) {
            xcb_render_free_picture(conn, self.rootPicture);
            self.rootPicture = XCB_NONE;
        }
        
        // Destroy output window (child of overlay)
        if (self.outputWindow != XCB_NONE) {
            xcb_destroy_window(conn, self.outputWindow);
            self.outputWindow = XCB_NONE;
        }
        
        // Release overlay window
        if (self.overlayWindow != XCB_NONE) {
            xcb_composite_release_overlay_window(conn, self.rootWindow);
            self.overlayWindow = XCB_NONE;
        }
        
        [self.connection flush];
        NSLog(@"[CompositingManager] Cleanup complete");
        
    } @catch (NSException *exception) {
        NSLog(@"[CompositingManager] EXCEPTION during cleanup: %@", exception.reason);
    }
}

- (void)dealloc {
    [self cleanup];
}

@end
