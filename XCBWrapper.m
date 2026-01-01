//
//  XCBWrapper.m
//  uroswm - Minimal XCB Wrapper
//
//  Minimal XCB wrapper implementation to replace XCBKit dependency.
//

#import "XCBWrapper.h"
#import <xcb/xcb.h>
#import <xcb/xcb_icccm.h>
#import <xcb/xproto.h>
#import <stdlib.h>
#import <string.h>

// Constants
NSString * const TitleBar = @"TitleBar";
NSString * const ClientWindow = @"ClientWindow";

#pragma mark - XCBVisual Implementation

@implementation XCBVisual

- (instancetype)initWithVisualId:(xcb_visualid_t)visualId {
    self = [super init];
    if (self) {
        _visualId = visualId;
        _visualType = NULL;
    }
    return self;
}

- (void)setVisualTypeForScreen:(XCBScreen*)screen {
    if (!screen || !screen.screen) {
        return;
    }
    
    xcb_depth_iterator_t depth_iter = xcb_screen_allowed_depths_iterator(screen.screen);
    for (; depth_iter.rem; xcb_depth_next(&depth_iter)) {
        xcb_visualtype_iterator_t visual_iter = xcb_depth_visuals_iterator(depth_iter.data);
        for (; visual_iter.rem; xcb_visualtype_next(&visual_iter)) {
            if (visual_iter.data->visual_id == self.visualId) {
                self.visualType = visual_iter.data;
                return;
            }
        }
    }
}

@end

#pragma mark - XCBScreen Implementation

@implementation XCBScreen

- (instancetype)initWithScreen:(xcb_screen_t*)screen number:(int)number {
    self = [super init];
    if (self) {
        _screen = screen;
        _screenNumber = number;
    }
    return self;
}

- (XCBWindow*)rootWindow {
    if (!self.screen) {
        return nil;
    }
    XCBWindow *window = [[XCBWindow alloc] init];
    window.window = self.screen->root;
    return window;
}

- (uint16_t)width {
    return self.screen ? self.screen->width_in_pixels : 0;
}

- (uint16_t)height {
    return self.screen ? self.screen->height_in_pixels : 0;
}

@end

#pragma mark - XCBWindow Implementation

@implementation XCBWindow

- (instancetype)init {
    self = [super init];
    if (self) {
        _window = XCB_NONE;
        _windowTitle = @"";
        _windowRect = XCBMakeRect(XCBMakePoint(0, 0), XCBMakeSize(0, 0));
    }
    return self;
}

- (void)setWindow:(xcb_window_t)window {
    _window = window;
}

- (void)setConnection:(XCBConnection*)connection {
    _connection = connection;
}

- (XCBRect)windowRect {
    return _windowRect;
}

- (void)close {
    // Send WM_DELETE_WINDOW message to the client
    if (self.window != XCB_NONE && self.connection) {
        // Try to get the WM_DELETE_WINDOW atom
        xcb_intern_atom_cookie_t cookie = xcb_intern_atom([self.connection connection], 0, 16, "WM_DELETE_WINDOW");
        xcb_intern_atom_reply_t *reply = xcb_intern_atom_reply([self.connection connection], cookie, NULL);
        
        if (reply) {
            xcb_atom_t wm_delete = reply->atom;
            free(reply);
            
            xcb_intern_atom_cookie_t proto_cookie = xcb_intern_atom([self.connection connection], 0, 12, "WM_PROTOCOLS");
            xcb_intern_atom_reply_t *proto_reply = xcb_intern_atom_reply([self.connection connection], proto_cookie, NULL);
            
            if (proto_reply) {
                xcb_atom_t wm_protocols = proto_reply->atom;
                free(proto_reply);
                
                // Send client message
                xcb_client_message_event_t event;
                memset(&event, 0, sizeof(event));
                event.response_type = XCB_CLIENT_MESSAGE;
                event.window = self.window;
                event.type = wm_protocols;
                event.format = 32;
                event.data.data32[0] = wm_delete;
                event.data.data32[1] = XCB_CURRENT_TIME;
                
                xcb_send_event([self.connection connection], 0, self.window,
                              XCB_EVENT_MASK_NO_EVENT, (const char*)&event);
                
                NSLog(@"XCBWindow: Sent WM_DELETE_WINDOW to window %u", self.window);
            }
        }
        
        // Fallback: destroy the window
        // xcb_destroy_window([self.connection connection], self.window);
    }
}

- (void)maximizeToSize:(XCBSize)size andPosition:(XCBPoint)position {
    // Basic implementation for XCBWindow maximize
    self.windowRect = XCBMakeRect(position, size);
}

@end

#pragma mark - XCBTitleBar Implementation

@implementation XCBTitleBar

- (instancetype)init {
    self = [super init];
    if (self) {
        self.pixmap = XCB_NONE;
        self.dPixmap = XCB_NONE;
        _frame = NSZeroRect;
        _isActive = NO;
    }
    return self;
}


- (xcb_pixmap_t)dPixmap {
    return _dPixmap;
}

- (void)createPixmap {
    if (self.pixmap != XCB_NONE || !self.connection) {
        return; // Already created or no connection
    }
    
    NSSize size = self.frame.size;
    if (size.width <= 0 || size.height <= 0) {
        NSLog(@"XCBTitleBar: Invalid frame size for pixmap creation");
        return;
    }
    
    self.pixmap = xcb_generate_id([self.connection connection]);
    xcb_create_pixmap([self.connection connection],
                     24, // depth
                     self.pixmap,
                     self.window,
                     (uint16_t)size.width,
                     (uint16_t)size.height);
    
    // Also create dPixmap (inactive pixmap)
    self.dPixmap = xcb_generate_id([self.connection connection]);
    xcb_create_pixmap([self.connection connection],
                     24, // depth
                     self.dPixmap,
                     self.window,
                     (uint16_t)size.width,
                     (uint16_t)size.height);
}

- (void)putWindowBackgroundWithPixmap:(xcb_pixmap_t)pixmap {
    // Set the window background pixmap
    if (self.window != XCB_NONE && self.connection) {
        uint32_t values[] = { pixmap };
        xcb_change_window_attributes([self.connection connection], self.window,
                                   XCB_CW_BACK_PIXMAP, values);
    }
}

- (void)drawArea:(XCBRect)rect {
    // Basic drawing implementation - would need more sophisticated graphics code
    if (self.window != XCB_NONE && self.connection) {
        xcb_clear_area([self.connection connection], 0, self.window,
                      (int16_t)rect.origin.x, (int16_t)rect.origin.y,
                      (uint16_t)rect.size.width, (uint16_t)rect.size.height);
    }
}

- (XCBSize)pixmapSize {
    // Return the size based on the frame
    return XCBMakeSize(self.frame.size.width, self.frame.size.height);
}

- (void)destroyPixmap {
    // Destroy both pixmaps
    if (self.pixmap != XCB_NONE && self.connection) {
        xcb_free_pixmap([self.connection connection], self.pixmap);
        self.pixmap = XCB_NONE;
    }
    if (self.dPixmap != XCB_NONE && self.connection) {
        xcb_free_pixmap([self.connection connection], self.dPixmap);
        self.dPixmap = XCB_NONE;
    }
}

- (void)maximizeToSize:(XCBSize)size andPosition:(XCBPoint)position {
    // Maximize titlebar - update frame and window rect
    self.frame = NSMakeRect(position.x, position.y, size.width, size.height);
    [super maximizeToSize:size andPosition:position];
}

- (XCBRect)windowRect {
    // Override to return frame dimensions instead of inherited _windowRect
    return XCBMakeRect(XCBMakePoint(self.frame.origin.x, self.frame.origin.y),
                       XCBMakeSize(self.frame.size.width, self.frame.size.height));
}

@end

#pragma mark - XCBFrame Implementation

@implementation XCBFrame

@dynamic windowRect;

- (instancetype)initWithClientWindow:(XCBWindow*)clientWindow 
                      withConnection:(XCBConnection*)connection {
    self = [super init];
    if (self) {
        _clientWindow = clientWindow;
        self.connection = connection;
        _childWindows = [[NSMutableDictionary alloc] init];
        self.windowRect = XCBMakeRect(XCBMakePoint(0.0, 0.0), XCBMakeSize(0.0, 0.0));
        _maximized = NO;
        _savedRect = NSMakeRect(0, 0, 0, 0);
        
        // Generate frame window ID
        self.window = xcb_generate_id(connection.connection);
    }
    return self;
}

- (XCBWindow*)childWindowForKey:(NSString*)key {
    return [self.childWindows objectForKey:key];
}

- (void)setChildWindow:(XCBWindow*)childWindow forKey:(NSString*)key {
    if (childWindow && key) {
        [self.childWindows setObject:childWindow forKey:key];
    }
}

- (BOOL)isMaximized {
    return _maximized;
}

- (void)minimize {
    // Minimal implementation - just unmap the window
    if (self.window != XCB_NONE && self.connection) {
        xcb_unmap_window([self.connection connection], self.window);
        [self.connection flush];
        NSLog(@"XCBFrame: Minimized window %u", self.window);
    }
}

- (void)maximizeToSize:(XCBSize)size andPosition:(XCBPoint)position {
    // Maximize window to given size and position
    if (self.window != XCB_NONE && self.connection) {
        // Save current position before maximizing
        if (!_maximized) {
            _savedRect = NSMakeRect(self.windowRect.origin.x, self.windowRect.origin.y,
                                   self.windowRect.size.width, self.windowRect.size.height);
        }
        
        uint32_t values[4];
        values[0] = (uint32_t)position.x;
        values[1] = (uint32_t)position.y;
        values[2] = (uint32_t)size.width;
        values[3] = (uint32_t)size.height;
        
        xcb_configure_window([self.connection connection],
                           self.window,
                           XCB_CONFIG_WINDOW_X | XCB_CONFIG_WINDOW_Y |
                           XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT,
                           values);
        
        self.windowRect = XCBMakeRect(position, size);
        _maximized = YES;
        [self.connection flush];
        NSLog(@"XCBFrame: Maximized window %u", self.window);
    }
}

- (XCBScreen*)onScreen {
    // Return the first screen for simplicity
    // In a more complete implementation, this would determine the actual screen
    if (self.connection && [self.connection.screens count] > 0) {
        return [self.connection.screens objectAtIndex:0];
    }
    return nil;
}

- (void)restoreDimensionAndPosition {
    // Restore from maximized state
    if (_maximized && self.window != XCB_NONE && self.connection) {
        uint32_t values[4];
        values[0] = (uint32_t)_savedRect.origin.x;
        values[1] = (uint32_t)_savedRect.origin.y;
        values[2] = (uint32_t)_savedRect.size.width;
        values[3] = (uint32_t)_savedRect.size.height;
        
        xcb_configure_window([self.connection connection],
                           self.window,
                           XCB_CONFIG_WINDOW_X | XCB_CONFIG_WINDOW_Y |
                           XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT,
                           values);
        
        self.windowRect = XCBMakeRect(XCBMakePoint(_savedRect.origin.x, _savedRect.origin.y),
                                     XCBMakeSize(_savedRect.size.width, _savedRect.size.height));
        _maximized = NO;
        [self.connection flush];
        NSLog(@"XCBFrame: Restored window %u to saved position", self.window);
    }
}

- (void)setNeedDestroy:(BOOL)needDestroy {
    // Simple implementation - could be extended to track destroy state
    if (needDestroy) {
        NSLog(@"XCBFrame: Window %u marked for destruction", self.window);
    }
}

@end

#pragma mark - EWMHService Implementation

static EWMHService *sharedEWMHInstance = nil;

@implementation EWMHService

+ (instancetype)sharedInstanceWithConnection:(XCBConnection*)connection {
    if (!sharedEWMHInstance) {
        sharedEWMHInstance = [[EWMHService alloc] init];
        sharedEWMHInstance.connection = connection;
    }
    return sharedEWMHInstance;
}

- (void)putPropertiesForRootWindow:(XCBWindow*)rootWindow 
                        andWmWindow:(XCBWindow*)wmWindow {
    if (!self.connection || !rootWindow || !wmWindow) {
        return;
    }
    
    xcb_connection_t *conn = self.connection.connection;
    xcb_window_t root = rootWindow.window;
    xcb_window_t wm = wmWindow.window;
    
    // Set _NET_SUPPORTING_WM_CHECK on root and wm window
    xcb_atom_t net_supporting_wm_check = [self getAtom:conn name:"_NET_SUPPORTING_WM_CHECK"];
    xcb_atom_t window_atom = XCB_ATOM_WINDOW;
    
    xcb_change_property(conn, XCB_PROP_MODE_REPLACE, root,
                       net_supporting_wm_check, window_atom, 32, 1, &wm);
    xcb_change_property(conn, XCB_PROP_MODE_REPLACE, wm,
                       net_supporting_wm_check, window_atom, 32, 1, &wm);
    
    // Set _NET_WM_NAME on wm window
    xcb_atom_t net_wm_name = [self getAtom:conn name:"_NET_WM_NAME"];
    xcb_atom_t utf8_string = [self getAtom:conn name:"UTF8_STRING"];
    const char *wm_name = "uroswm";
    xcb_change_property(conn, XCB_PROP_MODE_REPLACE, wm,
                       net_wm_name, utf8_string, 8, strlen(wm_name), wm_name);
    
    // Set supported EWMH atoms on root
    xcb_atom_t net_supported = [self getAtom:conn name:"_NET_SUPPORTED"];
    xcb_atom_t supported[] = {
        [self getAtom:conn name:"_NET_SUPPORTED"],
        [self getAtom:conn name:"_NET_SUPPORTING_WM_CHECK"],
        [self getAtom:conn name:"_NET_WM_NAME"],
        [self getAtom:conn name:"_NET_ACTIVE_WINDOW"],
        [self getAtom:conn name:"_NET_CLIENT_LIST"],
        [self getAtom:conn name:"_NET_WM_STATE"],
        [self getAtom:conn name:"_NET_WM_STATE_MAXIMIZED_VERT"],
        [self getAtom:conn name:"_NET_WM_STATE_MAXIMIZED_HORZ"],
    };
    
    xcb_change_property(conn, XCB_PROP_MODE_REPLACE, root,
                       net_supported, XCB_ATOM_ATOM, 32,
                       sizeof(supported) / sizeof(xcb_atom_t), supported);
}

- (xcb_atom_t)getAtom:(xcb_connection_t*)conn name:(const char*)name {
    xcb_intern_atom_cookie_t cookie = xcb_intern_atom(conn, 0, strlen(name), name);
    xcb_intern_atom_reply_t *reply = xcb_intern_atom_reply(conn, cookie, NULL);
    xcb_atom_t atom = reply ? reply->atom : XCB_NONE;
    free(reply);
    return atom;
}

@end

#pragma mark - TitleBarSettingsService Implementation

static TitleBarSettingsService *sharedTitleBarSettings = nil;

@implementation TitleBarSettingsService

+ (instancetype)sharedInstance {
    if (!sharedTitleBarSettings) {
        sharedTitleBarSettings = [[TitleBarSettingsService alloc] init];
        sharedTitleBarSettings.height = 25;
        sharedTitleBarSettings.closePosition = XCBMakePoint(3.5, 3.8);
        sharedTitleBarSettings.minimizePosition = XCBMakePoint(3, 8);
        sharedTitleBarSettings.maximizePosition = XCBMakePoint(3, 3);
    }
    return sharedTitleBarSettings;
}

- (void)setHeight:(NSInteger)height {
    _height = height;
}

- (void)setClosePosition:(XCBPoint)position {
    _closePosition = position;
}

- (void)setMinimizePosition:(XCBPoint)position {
    _minimizePosition = position;
}

- (void)setMaximizePosition:(XCBPoint)position {
    _maximizePosition = position;
}

@end

#pragma mark - XCBConnection Implementation

static XCBConnection *sharedConnection = nil;

@implementation XCBConnection

+ (instancetype)sharedConnectionAsWindowManager:(BOOL)asWindowManager {
    if (!sharedConnection) {
        sharedConnection = [[XCBConnection alloc] initAsWindowManager:asWindowManager];
    }
    return sharedConnection;
}

- (instancetype)initAsWindowManager:(BOOL)asWindowManager {
    self = [super init];
    if (self) {
        _windowsMap = [[NSMutableDictionary alloc] init];
        _screens = [[NSMutableArray alloc] init];
        _needFlush = NO;
        
        // Connect to X server
        int screenNum;
        _connection = xcb_connect(NULL, &screenNum);
        
        if (xcb_connection_has_error(_connection)) {
            NSLog(@"ERROR: Failed to connect to X server");
            return nil;
        }
        
        // Setup screens
        xcb_screen_iterator_t iter = xcb_setup_roots_iterator(xcb_get_setup(_connection));
        int currentScreen = 0;
        for (; iter.rem; xcb_screen_next(&iter), currentScreen++) {
            XCBScreen *screen = [[XCBScreen alloc] initWithScreen:iter.data number:currentScreen];
            [_screens addObject:screen];
        }
        
        NSLog(@"XCBConnection: Connected to X server with %lu screens", (unsigned long)[_screens count]);
    }
    return self;
}

- (void)flush {
    xcb_flush(self.connection);
}

- (void)setNeedFlush:(BOOL)needFlush {
    _needFlush = needFlush;
}

- (XCBWindow*)createWindowWithDepth:(uint8_t)depth
                   withParentWindow:(XCBWindow*)parent
                      withXPosition:(int16_t)x
                      withYPosition:(int16_t)y
                          withWidth:(uint16_t)width
                         withHeight:(uint16_t)height
                   withBorrderWidth:(uint16_t)borderWidth
                       withXCBClass:(uint16_t)windowClass
                       withVisualId:(XCBVisual*)visual
                      withValueMask:(uint32_t)valueMask
                      withValueList:(const uint32_t*)valueList
                    registerWindow:(BOOL)shouldRegister {
    xcb_window_t windowId = xcb_generate_id(self.connection);
    
    xcb_create_window(self.connection,
                     depth,
                     windowId,
                     parent.window,
                     x, y, width, height,
                     borderWidth,
                     windowClass,
                     visual.visualId,
                     valueMask,
                     valueList);
    
    XCBWindow *window = [[XCBWindow alloc] init];
    window.window = windowId;
    window.connection = self;
    
    if (shouldRegister) {
        [self registerWindow:window];
    }
    
    return window;
}

- (void)registerWindow:(XCBWindow*)window {
    if (window && window.window != XCB_NONE) {
        NSString *key = [NSString stringWithFormat:@"%u", window.window];
        [self.windowsMap setObject:window forKey:key];
    }
}

- (void)mapWindow:(XCBWindow*)window {
    if (window && window.window != XCB_NONE) {
        xcb_map_window(self.connection, window.window);
    }
}

- (XCBWindow*)windowForXCBId:(xcb_window_t)windowId {
    NSString *key = [NSString stringWithFormat:@"%u", windowId];
    return [self.windowsMap objectForKey:key];
}

- (void)registerAsWindowManager:(BOOL)registerFlag
                       screenId:(int)screenId
                selectionWindow:(XCBWindow*)selectionWindow {
    if (screenId >= [self.screens count]) {
        NSLog(@"ERROR: Invalid screen ID %d", screenId);
        return;
    }
    
    XCBScreen *screen = [self.screens objectAtIndex:screenId];
    xcb_window_t root = screen.screen->root;
    
    // Set substructure redirect on root window
    uint32_t values[] = {
        XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT |
        XCB_EVENT_MASK_SUBSTRUCTURE_NOTIFY |
        XCB_EVENT_MASK_STRUCTURE_NOTIFY |
        XCB_EVENT_MASK_PROPERTY_CHANGE
    };
    
    xcb_change_window_attributes(self.connection, root,
                                 XCB_CW_EVENT_MASK, values);
    
    // Try to register as WM
    xcb_generic_error_t *error = xcb_request_check(self.connection,
                                                   xcb_change_window_attributes_checked(
                                                       self.connection, root,
                                                       XCB_CW_EVENT_MASK, values));
    
    if (error) {
        NSLog(@"ERROR: Another window manager is already running");
        free(error);
        return;
    }
    
    NSLog(@"Successfully registered as window manager");
}

#pragma mark - Event Handlers (Minimal Implementations)

- (void)handleVisibilityEvent:(xcb_visibility_notify_event_t*)event {
    // Minimal implementation - just log
    // NSLog(@"Visibility event for window %u", event->window);
}

- (void)handleExpose:(xcb_expose_event_t*)event {
    // Minimal implementation - window needs redraw
    // NSLog(@"Expose event for window %u", event->window);
}

- (void)handleEnterNotify:(xcb_enter_notify_event_t*)event {
    // Minimal implementation
    // NSLog(@"Enter notify for window %u", event->event);
}

- (void)handleLeaveNotify:(xcb_leave_notify_event_t*)event {
    // Minimal implementation
    // NSLog(@"Leave notify for window %u", event->event);
}

- (void)handleFocusIn:(xcb_focus_in_event_t*)event {
    // Minimal implementation
    // NSLog(@"Focus in for window %u", event->event);
}

- (void)handleFocusOut:(xcb_focus_out_event_t*)event {
    // Minimal implementation
    // NSLog(@"Focus out for window %u", event->event);
}

- (void)handleButtonPress:(xcb_button_press_event_t*)event {
    // Minimal implementation - button press handling
    // NSLog(@"Button press on window %u", event->event);
}

- (void)handleButtonRelease:(xcb_button_release_event_t*)event {
    // Minimal implementation
    // NSLog(@"Button release on window %u", event->event);
}

- (void)handleMotionNotify:(xcb_motion_notify_event_t*)event {
    // Minimal implementation for window dragging/resizing
    // This is a complex operation that was handled by XCBKit
    // For now, just log
    // NSLog(@"Motion notify for window %u", event->event);
}

- (void)handleMapNotify:(xcb_map_notify_event_t*)event {
    // Minimal implementation
    // NSLog(@"Map notify for window %u", event->window);
}

- (void)handleMapRequest:(xcb_map_request_event_t*)event {
    // This is a critical WM function - a client wants to map a window
    NSLog(@"Map request for window %u", event->window);
    
    // Get window geometry
    xcb_get_geometry_cookie_t geom_cookie = xcb_get_geometry(self.connection, event->window);
    xcb_get_geometry_reply_t *geom_reply = xcb_get_geometry_reply(self.connection, geom_cookie, NULL);
    
    if (!geom_reply) {
        // If we can't get geometry, just map it
        xcb_map_window(self.connection, event->window);
        return;
    }
    
    // Check if this window should be managed (has WM_TRANSIENT_FOR = unmanaged)
    xcb_get_property_cookie_t trans_cookie = xcb_icccm_get_wm_transient_for(self.connection, event->window);
    xcb_window_t transient_for = XCB_NONE;
    BOOL is_transient = (xcb_icccm_get_wm_transient_for_reply(self.connection, trans_cookie, &transient_for, NULL) == 1);
    
    if (is_transient) {
        // Transient windows (dialogs, etc.) don't get frames
        NSLog(@"Window %u is transient, mapping without frame", event->window);
        xcb_map_window(self.connection, event->window);
        free(geom_reply);
        return;
    }
    
    // Create or get client window object
    XCBWindow *clientWindow = [self windowForXCBId:event->window];
    if (!clientWindow) {
        clientWindow = [[XCBWindow alloc] init];
        [clientWindow setWindow:event->window];
        [clientWindow setConnection:self];
        [self registerWindow:clientWindow];
    }
    
    // Create frame for the window
    XCBFrame *frame = [[XCBFrame alloc] initWithClientWindow:clientWindow withConnection:self];
    
    // Get screen info for creating frame and titlebar
    XCBScreen *screen = [self.screens objectAtIndex:0];
    
    // Calculate frame geometry (client + titlebar + borders)
    TitleBarSettingsService *tbSettings = [TitleBarSettingsService sharedInstance];
    int titlebarHeight = tbSettings.height;
    int borderWidth = 1;
    
    int frameX = geom_reply->x - borderWidth;
    int frameY = geom_reply->y - titlebarHeight - borderWidth;

    // Ensure titlebar is not positioned above screen (Y >= 0)
    if (frameY < 0) {
        frameY = 0;
    }
    int frameWidth = geom_reply->width + (borderWidth * 2);
    int frameHeight = geom_reply->height + titlebarHeight + (borderWidth * 2);
    
    // Create frame window
    uint32_t frame_mask = XCB_CW_BACK_PIXEL | XCB_CW_EVENT_MASK;
    uint32_t frame_values[2];
    frame_values[0] = screen.screen->white_pixel;
    frame_values[1] = XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT |
                      XCB_EVENT_MASK_SUBSTRUCTURE_NOTIFY |
                      XCB_EVENT_MASK_BUTTON_PRESS |
                      XCB_EVENT_MASK_BUTTON_RELEASE |
                      XCB_EVENT_MASK_POINTER_MOTION |
                      XCB_EVENT_MASK_EXPOSURE;
    
    xcb_create_window(self.connection,
                     XCB_COPY_FROM_PARENT,
                     frame.window,
                     screen.screen->root,
                     frameX, frameY,
                     frameWidth, frameHeight,
                     borderWidth,
                     XCB_WINDOW_CLASS_INPUT_OUTPUT,
                     screen.screen->root_visual,
                     frame_mask,
                     frame_values);
    
    [self registerWindow:frame];
    frame.windowRect = XCBMakeRect(XCBMakePoint(frameX, frameY), XCBMakeSize(frameWidth, frameHeight));
    
    // Create titlebar window
    XCBTitleBar *titlebar = [[XCBTitleBar alloc] init];
    titlebar.window = xcb_generate_id(self.connection);
    titlebar.connection = self;
    titlebar.frame = NSMakeRect(0, 0, frameWidth, titlebarHeight);
    
    uint32_t tb_mask = XCB_CW_BACK_PIXEL | XCB_CW_EVENT_MASK;
    uint32_t tb_values[2];
    tb_values[0] = screen.screen->white_pixel;
    tb_values[1] = XCB_EVENT_MASK_EXPOSURE |
                   XCB_EVENT_MASK_BUTTON_PRESS |
                   XCB_EVENT_MASK_BUTTON_RELEASE |
                   XCB_EVENT_MASK_POINTER_MOTION;
    
    xcb_create_window(self.connection,
                     XCB_COPY_FROM_PARENT,
                     titlebar.window,
                     frame.window,
                     0, 0,
                     frameWidth, titlebarHeight,
                     0,
                     XCB_WINDOW_CLASS_INPUT_OUTPUT,
                     screen.screen->root_visual,
                     tb_mask,
                     tb_values);
    
    // Create pixmap for titlebar
    titlebar.pixmap = xcb_generate_id(self.connection);
    xcb_create_pixmap(self.connection, 24, titlebar.pixmap, titlebar.window, frameWidth, titlebarHeight);
    
    // Setup visual
    XCBVisual *visual = [[XCBVisual alloc] initWithVisualId:screen.screen->root_visual];
    [visual setVisualTypeForScreen:screen];
    titlebar.visual = visual;
    
    [self registerWindow:titlebar];
    [frame setChildWindow:titlebar forKey:TitleBar];
    [frame setChildWindow:clientWindow forKey:ClientWindow];
    titlebar.parentWindow = frame;
    clientWindow.parentWindow = frame;
    
    // Reparent client window into frame
    xcb_reparent_window(self.connection,
                       event->window,
                       frame.window,
                       borderWidth,
                       titlebarHeight);
    
    // Map frame, titlebar, and client
    xcb_map_window(self.connection, titlebar.window);
    xcb_map_window(self.connection, event->window);
    xcb_map_window(self.connection, frame.window);
    
    free(geom_reply);
}

- (void)handleUnMapNotify:(xcb_unmap_notify_event_t*)event {
    // Minimal implementation
    NSLog(@"Unmap notify for window %u", event->window);
}

- (void)handleDestroyNotify:(xcb_destroy_notify_event_t*)event {
    // Minimal implementation - clean up
    NSLog(@"Destroy notify for window %u", event->window);
    
    NSString *key = [NSString stringWithFormat:@"%u", event->window];
    [self.windowsMap removeObjectForKey:key];
}

- (void)handleConfigureRequest:(xcb_configure_request_event_t*)event {
    // Minimal implementation - client wants to reconfigure
    NSLog(@"Configure request for window %u", event->window);
    
    // Grant the request
    uint32_t values[7];
    int i = 0;
    uint16_t mask = 0;
    
    if (event->value_mask & XCB_CONFIG_WINDOW_X) {
        mask |= XCB_CONFIG_WINDOW_X;
        values[i++] = event->x;
    }
    if (event->value_mask & XCB_CONFIG_WINDOW_Y) {
        mask |= XCB_CONFIG_WINDOW_Y;
        values[i++] = event->y;
    }
    if (event->value_mask & XCB_CONFIG_WINDOW_WIDTH) {
        mask |= XCB_CONFIG_WINDOW_WIDTH;
        values[i++] = event->width;
    }
    if (event->value_mask & XCB_CONFIG_WINDOW_HEIGHT) {
        mask |= XCB_CONFIG_WINDOW_HEIGHT;
        values[i++] = event->height;
    }
    if (event->value_mask & XCB_CONFIG_WINDOW_BORDER_WIDTH) {
        mask |= XCB_CONFIG_WINDOW_BORDER_WIDTH;
        values[i++] = event->border_width;
    }
    if (event->value_mask & XCB_CONFIG_WINDOW_SIBLING) {
        mask |= XCB_CONFIG_WINDOW_SIBLING;
        values[i++] = event->sibling;
    }
    if (event->value_mask & XCB_CONFIG_WINDOW_STACK_MODE) {
        mask |= XCB_CONFIG_WINDOW_STACK_MODE;
        values[i++] = event->stack_mode;
    }
    
    xcb_configure_window(self.connection, event->window, mask, values);
}

- (void)handleConfigureWindowRequest:(xcb_configure_request_event_t*)event {
    // Alias for handleConfigureRequest
    [self handleConfigureRequest:event];
}

- (void)handleConfigureNotify:(xcb_configure_notify_event_t*)event {
    // Minimal implementation
    // NSLog(@"Configure notify for window %u", event->window);
}

- (void)handlePropertyNotify:(xcb_property_notify_event_t*)event {
    // Minimal implementation
    // NSLog(@"Property notify for window %u", event->window);
}

- (void)handleClientMessage:(xcb_client_message_event_t*)event {
    // Minimal implementation for client messages (like _NET_WM_STATE)
    NSLog(@"Client message for window %u", event->window);
}

- (void)dealloc {
    if (self.connection) {
        xcb_disconnect(self.connection);
    }
}

#pragma mark - Utility Functions

+ (BOOL)copyBitmapToPixmap:(NSBitmapImageRep*)bitmap
                  toPixmap:(xcb_pixmap_t)pixmap
                connection:(xcb_connection_t*)connection
                    window:(xcb_window_t)window
                    visual:(xcb_visualtype_t*)visualType {
    if (!bitmap || pixmap == XCB_NONE || !connection) {
        return NO;
    }
    
    unsigned char *bitmapPixels = [bitmap bitmapData];
    int width = [bitmap pixelsWide];
    int height = [bitmap pixelsHigh];
    int bytesPerRow = [bitmap bytesPerRow];
    
    if (!bitmapPixels || width <= 0 || height <= 0) {
        return NO;
    }
    
    // Convert RGBA to BGRA for X11
    // X11 expects BGRA byte order in memory for 24-bit depth
    unsigned char *convertedPixels = malloc(bytesPerRow * height);
    if (!convertedPixels) {
        return NO;
    }
    
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            int offset = (y * bytesPerRow) + (x * 4);
            unsigned char r = bitmapPixels[offset];
            unsigned char g = bitmapPixels[offset + 1];
            unsigned char b = bitmapPixels[offset + 2];
            unsigned char a = bitmapPixels[offset + 3];
            
            // Swap R and B for BGRA format expected by X11
            convertedPixels[offset] = b;     // Blue
            convertedPixels[offset + 1] = g; // Green
            convertedPixels[offset + 2] = r; // Red
            convertedPixels[offset + 3] = a; // Alpha
        }
    }
    
    // Create GC for the pixmap
    xcb_gcontext_t gc = xcb_generate_id(connection);
    uint32_t mask = XCB_GC_FOREGROUND | XCB_GC_BACKGROUND;
    uint32_t values[2] = {0, 0xFFFFFF};
    xcb_create_gc(connection, gc, pixmap, mask, values);
    
    // Use xcb_put_image to copy the bitmap data to the pixmap
    xcb_put_image(connection,
                  XCB_IMAGE_FORMAT_Z_PIXMAP,
                  pixmap,
                  gc,
                  width,
                  height,
                  0, 0,  // dst x, y
                  0,     // left_pad
                  24,    // depth
                  bytesPerRow * height,
                  convertedPixels);
    
    // Free GC
    xcb_free_gc(connection, gc);
    
    // Clean up
    free(convertedPixels);
    
    return YES;
}

@end
