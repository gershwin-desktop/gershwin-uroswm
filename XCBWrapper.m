//
//  XCBWrapper.m
//  uroswm - Minimal XCB Wrapper
//
//  Minimal XCB wrapper implementation to replace XCBKit dependency.
//

#import "XCBWrapper.h"
#import "ThemeRenderer.h"
#import "WindowManagerDelegate.h"
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

#pragma mark - XCBCursor Implementation

@implementation XCBCursor

@synthesize connection;
@synthesize context;
@synthesize screen;
@synthesize cursorPath;
@synthesize cursor;
@synthesize leftPointerName;
@synthesize resizeBottomCursorName;
@synthesize resizeRightCursorName;
@synthesize cursors;
@synthesize leftPointerSelected;
@synthesize resizeBottomSelected;
@synthesize resizeRightSelected;
@synthesize resizeLeftCursorName;
@synthesize resizeLeftSelected;
@synthesize resizeBottomRightCornerCursorName;
@synthesize resizeBottomLeftCornerCursorName;
@synthesize resizeTopRightCornerCursorName;
@synthesize resizeTopLeftCornerCursorName;
@synthesize resizeBottomRightCornerSelected;
@synthesize resizeBottomLeftCornerSelected;
@synthesize resizeTopRightCornerSelected;
@synthesize resizeTopLeftCornerSelected;
@synthesize resizeTopCursorName;
@synthesize resizeTopSelected;

- (instancetype)initWithConnection:(XCBConnection *)aConnection screen:(XCBScreen*)aScreen {
    self = [super init];

    if (self == nil) {
        NSLog(@"Unable to init XCBCursor...");
        return nil;
    }

    connection = aConnection;
    screen = aScreen;

    BOOL success = [self createContext];

    if (!success) {
        NSLog(@"Error creating a new cursor context");
        return self;
    }

    cursors = [[NSMutableDictionary alloc] init];

    leftPointerName = @"left_ptr";
    resizeBottomCursorName = @"s-resize";
    resizeRightCursorName = @"w-resize";
    resizeLeftCursorName = @"e-resize";
    resizeTopCursorName = @"n-resize";
    resizeBottomRightCornerCursorName = @"nwse-resize";
    resizeBottomLeftCornerCursorName = @"nesw-resize";
    resizeTopRightCornerCursorName = @"nesw-resize";
    resizeTopLeftCornerCursorName = @"nwse-resize";

    // Load all cursor types using both theme names and font-based fallbacks
    NSLog(@"=== LOADING CURSORS ===");

    NSLog(@"Loading cursor: %@", leftPointerName);
    cursor = xcb_cursor_load_cursor(context, [leftPointerName cString]);
    if (cursor == 0) {
        NSLog(@"Theme cursor failed, trying font cursor");
        // Fallback to standard X11 font cursor (left pointer = 68)
        xcb_font_t font = xcb_generate_id([connection connection]);
        xcb_open_font([connection connection], font, strlen("cursor"), "cursor");
        cursor = xcb_generate_id([connection connection]);
        xcb_create_glyph_cursor([connection connection], cursor, font, font,
                               68, 69, 0, 0, 0, 65535, 65535, 65535);
        xcb_close_font([connection connection], font);
    }
    NSLog(@"Final cursor ID for %@: %u", leftPointerName, cursor);
    [cursors setObject:[NSNumber numberWithUnsignedInt:cursor] forKey:leftPointerName];

    NSLog(@"Loading cursor: %@", resizeBottomCursorName);
    cursor = xcb_cursor_load_cursor(context, [resizeBottomCursorName cString]);
    if (cursor == 0) {
        NSLog(@"Theme cursor failed, trying font cursor");
        // Fallback to bottom_side cursor (16)
        xcb_font_t font = xcb_generate_id([connection connection]);
        xcb_open_font([connection connection], font, strlen("cursor"), "cursor");
        cursor = xcb_generate_id([connection connection]);
        xcb_create_glyph_cursor([connection connection], cursor, font, font,
                               16, 17, 0, 0, 0, 65535, 65535, 65535);
        xcb_close_font([connection connection], font);
    }
    NSLog(@"Final cursor ID for %@: %u", resizeBottomCursorName, cursor);
    [cursors setObject:[NSNumber numberWithUnsignedInt:cursor] forKey:resizeBottomCursorName];

    NSLog(@"Loading cursor: %@", resizeRightCursorName);
    cursor = xcb_cursor_load_cursor(context, [resizeRightCursorName cString]);
    if (cursor == 0) {
        NSLog(@"Theme cursor failed, trying font cursor");
        // Fallback to right_side cursor (96)
        xcb_font_t font = xcb_generate_id([connection connection]);
        xcb_open_font([connection connection], font, strlen("cursor"), "cursor");
        cursor = xcb_generate_id([connection connection]);
        xcb_create_glyph_cursor([connection connection], cursor, font, font,
                               96, 97, 0, 0, 0, 65535, 65535, 65535);
        xcb_close_font([connection connection], font);
    }
    NSLog(@"Final cursor ID for %@: %u", resizeRightCursorName, cursor);
    [cursors setObject:[NSNumber numberWithUnsignedInt:cursor] forKey:resizeRightCursorName];

    NSLog(@"Loading cursor: %@", resizeLeftCursorName);
    cursor = xcb_cursor_load_cursor(context, [resizeLeftCursorName cString]);
    if (cursor == 0) {
        NSLog(@"Theme cursor failed, trying font cursor");
        // Fallback to left_side cursor (70)
        xcb_font_t font = xcb_generate_id([connection connection]);
        xcb_open_font([connection connection], font, strlen("cursor"), "cursor");
        cursor = xcb_generate_id([connection connection]);
        xcb_create_glyph_cursor([connection connection], cursor, font, font,
                               70, 71, 0, 0, 0, 65535, 65535, 65535);
        xcb_close_font([connection connection], font);
    }
    NSLog(@"Final cursor ID for %@: %u", resizeLeftCursorName, cursor);
    [cursors setObject:[NSNumber numberWithUnsignedInt:cursor] forKey:resizeLeftCursorName];

    NSLog(@"Loading cursor: %@", resizeBottomRightCornerCursorName);
    cursor = xcb_cursor_load_cursor(context, [resizeBottomRightCornerCursorName cString]);
    if (cursor == 0) {
        NSLog(@"Theme cursor failed, trying font cursor");
        // Fallback to bottom_right_corner cursor (14)
        xcb_font_t font = xcb_generate_id([connection connection]);
        xcb_open_font([connection connection], font, strlen("cursor"), "cursor");
        cursor = xcb_generate_id([connection connection]);
        xcb_create_glyph_cursor([connection connection], cursor, font, font,
                               14, 15, 0, 0, 0, 65535, 65535, 65535);
        xcb_close_font([connection connection], font);
    }
    NSLog(@"Final cursor ID for %@: %u", resizeBottomRightCornerCursorName, cursor);
    [cursors setObject:[NSNumber numberWithUnsignedInt:cursor] forKey:resizeBottomRightCornerCursorName];

    NSLog(@"Loading cursor: %@", resizeTopCursorName);
    cursor = xcb_cursor_load_cursor(context, [resizeTopCursorName cString]);
    if (cursor == 0) {
        NSLog(@"Theme cursor failed, trying font cursor");
        // Fallback to top_side cursor (138)
        xcb_font_t font = xcb_generate_id([connection connection]);
        xcb_open_font([connection connection], font, strlen("cursor"), "cursor");
        cursor = xcb_generate_id([connection connection]);
        xcb_create_glyph_cursor([connection connection], cursor, font, font,
                               138, 139, 0, 0, 0, 65535, 65535, 65535);
        xcb_close_font([connection connection], font);
    }
    NSLog(@"Final cursor ID for %@: %u", resizeTopCursorName, cursor);
    [cursors setObject:[NSNumber numberWithUnsignedInt:cursor] forKey:resizeTopCursorName];

    NSLog(@"Loading cursor: %@", resizeBottomLeftCornerCursorName);
    cursor = xcb_cursor_load_cursor(context, [resizeBottomLeftCornerCursorName cString]);
    if (cursor == 0) {
        NSLog(@"Theme cursor failed, trying font cursor");
        // Fallback to bottom_left_corner cursor (12)
        xcb_font_t font = xcb_generate_id([connection connection]);
        xcb_open_font([connection connection], font, strlen("cursor"), "cursor");
        cursor = xcb_generate_id([connection connection]);
        xcb_create_glyph_cursor([connection connection], cursor, font, font,
                               12, 13, 0, 0, 0, 65535, 65535, 65535);
        xcb_close_font([connection connection], font);
    }
    NSLog(@"Final cursor ID for %@: %u", resizeBottomLeftCornerCursorName, cursor);
    [cursors setObject:[NSNumber numberWithUnsignedInt:cursor] forKey:resizeBottomLeftCornerCursorName];

    NSLog(@"Loading cursor: %@", resizeTopRightCornerCursorName);
    cursor = xcb_cursor_load_cursor(context, [resizeTopRightCornerCursorName cString]);
    if (cursor == 0) {
        NSLog(@"Theme cursor failed, trying font cursor");
        // Fallback to top_right_corner cursor (136)
        xcb_font_t font = xcb_generate_id([connection connection]);
        xcb_open_font([connection connection], font, strlen("cursor"), "cursor");
        cursor = xcb_generate_id([connection connection]);
        xcb_create_glyph_cursor([connection connection], cursor, font, font,
                               136, 137, 0, 0, 0, 65535, 65535, 65535);
        xcb_close_font([connection connection], font);
    }
    NSLog(@"Final cursor ID for %@: %u", resizeTopRightCornerCursorName, cursor);
    [cursors setObject:[NSNumber numberWithUnsignedInt:cursor] forKey:resizeTopRightCornerCursorName];

    NSLog(@"Loading cursor: %@", resizeTopLeftCornerCursorName);
    cursor = xcb_cursor_load_cursor(context, [resizeTopLeftCornerCursorName cString]);
    if (cursor == 0) {
        NSLog(@"Theme cursor failed, trying font cursor");
        // Fallback to top_left_corner cursor (134)
        xcb_font_t font = xcb_generate_id([connection connection]);
        xcb_open_font([connection connection], font, strlen("cursor"), "cursor");
        cursor = xcb_generate_id([connection connection]);
        xcb_create_glyph_cursor([connection connection], cursor, font, font,
                               134, 135, 0, 0, 0, 65535, 65535, 65535);
        xcb_close_font([connection connection], font);
    }
    NSLog(@"Final cursor ID for %@: %u", resizeTopLeftCornerCursorName, cursor);
    [cursors setObject:[NSNumber numberWithUnsignedInt:cursor] forKey:resizeTopLeftCornerCursorName];

    NSLog(@"=== CURSOR LOADING COMPLETE ===");

    return self;
}

- (xcb_cursor_t)selectLeftPointerCursor {
    cursor = [[cursors objectForKey:leftPointerName] unsignedIntValue];
    leftPointerSelected = YES;
    resizeBottomSelected = NO;
    resizeRightSelected = NO;
    resizeLeftSelected = NO;
    resizeTopSelected = NO;
    resizeBottomRightCornerSelected = NO;
    return cursor;
}

- (xcb_cursor_t)selectResizeCursorForPosition:(MousePosition)position {
    switch (position) {
        case BottomBorder:
            cursor = [[cursors objectForKey:resizeBottomCursorName] unsignedIntValue];
            leftPointerSelected = NO;
            resizeBottomSelected = YES;
            resizeRightSelected = NO;
            resizeLeftSelected = NO;
            resizeBottomRightCornerSelected = NO;
            resizeTopSelected = NO;
            break;
        case RightBorder:
            cursor = [[cursors objectForKey:resizeRightCursorName] unsignedIntValue];
            leftPointerSelected = NO;
            resizeBottomSelected = NO;
            resizeRightSelected = YES;
            resizeLeftSelected = NO;
            resizeBottomRightCornerSelected = NO;
            resizeTopSelected = NO;
            break;
        case LeftBorder:
            cursor = [[cursors objectForKey:resizeLeftCursorName] unsignedIntValue];
            leftPointerSelected = NO;
            resizeBottomSelected = NO;
            resizeRightSelected = NO;
            resizeLeftSelected = YES;
            resizeBottomRightCornerSelected = NO;
            resizeTopSelected = NO;
            break;
        case TopLeftCorner:
            cursor = [[cursors objectForKey:resizeTopLeftCornerCursorName] unsignedIntValue];
            leftPointerSelected = NO;
            resizeBottomSelected = NO;
            resizeRightSelected = NO;
            resizeLeftSelected = NO;
            resizeBottomRightCornerSelected = NO;
            resizeBottomLeftCornerSelected = NO;
            resizeTopRightCornerSelected = NO;
            resizeTopLeftCornerSelected = YES;
            resizeTopSelected = NO;
            break;
        case TopRightCorner:
            cursor = [[cursors objectForKey:resizeTopRightCornerCursorName] unsignedIntValue];
            leftPointerSelected = NO;
            resizeBottomSelected = NO;
            resizeRightSelected = NO;
            resizeLeftSelected = NO;
            resizeBottomRightCornerSelected = NO;
            resizeBottomLeftCornerSelected = NO;
            resizeTopRightCornerSelected = YES;
            resizeTopLeftCornerSelected = NO;
            resizeTopSelected = NO;
            break;
        case BottomLeftCorner:
            cursor = [[cursors objectForKey:resizeBottomLeftCornerCursorName] unsignedIntValue];
            leftPointerSelected = NO;
            resizeBottomSelected = NO;
            resizeRightSelected = NO;
            resizeLeftSelected = NO;
            resizeBottomRightCornerSelected = NO;
            resizeBottomLeftCornerSelected = YES;
            resizeTopRightCornerSelected = NO;
            resizeTopLeftCornerSelected = NO;
            resizeTopSelected = NO;
            break;
        case BottomRightCorner:
            cursor = [[cursors objectForKey:resizeBottomRightCornerCursorName] unsignedIntValue];
            leftPointerSelected = NO;
            resizeBottomSelected = NO;
            resizeRightSelected = NO;
            resizeLeftSelected = NO;
            resizeBottomRightCornerSelected = YES;
            resizeBottomLeftCornerSelected = NO;
            resizeTopRightCornerSelected = NO;
            resizeTopLeftCornerSelected = NO;
            resizeTopSelected = NO;
            break;
        case TopBorder:
            cursor = [[cursors objectForKey:resizeTopCursorName] unsignedIntValue];
            leftPointerSelected = NO;
            resizeBottomSelected = NO;
            resizeRightSelected = NO;
            resizeLeftSelected = NO;
            resizeBottomRightCornerSelected = NO;
            resizeTopSelected = YES;
           break;
        default:
            break;
    }

    return cursor;
}

- (BOOL)createContext {
    int success = xcb_cursor_context_new([connection connection], [screen screen], &context);

    if (success < 0)
        return NO;

    return YES;
}

- (void)destroyContext {
    if (context != NULL) {
        xcb_cursor_context_free(context);
        context = NULL;
    }
}

- (void)destroyCursor {
    xcb_free_cursor([connection connection], cursor);
}

- (void)dealloc {
    connection = nil;
    screen = nil;
    cursorPath = nil;
    cursors = nil;

    resizeTopCursorName = nil;
    resizeBottomRightCornerCursorName = nil;
    resizeLeftCursorName = nil;
    resizeRightCursorName = nil;
    resizeBottomCursorName = nil;
    leftPointerName = nil;

    if (context != NULL)
        [self destroyContext];
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

- (void)initCursor {
    // Find the screen this window belongs to
    XCBScreen *screen = nil;
    for (XCBScreen *s in self.connection.screens) {
        if (s != nil) {
            screen = s;
            break;
        }
    }

    if (screen) {
        self.cursor = [[XCBCursor alloc] initWithConnection:self.connection screen:screen];
    }
}

- (void)showLeftPointerCursor {
    if (self.cursor) {
        [self.cursor selectLeftPointerCursor];
        xcb_cursor_t crs = [self.cursor cursor];
        [self changeAttributes:&crs withMask:XCB_CW_CURSOR checked:NO];
    }
}

- (void)showResizeCursorForPosition:(MousePosition)position {
    if (self.cursor) {
        [self.cursor selectResizeCursorForPosition:position];
        xcb_cursor_t crs = [self.cursor cursor];
        [self changeAttributes:&crs withMask:XCB_CW_CURSOR checked:NO];
    }
}

- (void)changeAttributes:(const void*)valueList withMask:(uint32_t)valueMask checked:(BOOL)checked {
    if (self.window != XCB_NONE && self.connection) {
        xcb_void_cookie_t cookie = xcb_change_window_attributes([self.connection connection],
                                                               self.window,
                                                               valueMask,
                                                               valueList);
        if (checked) {
            xcb_generic_error_t *error = xcb_request_check([self.connection connection], cookie);
            if (error) {
                NSLog(@"Error changing window attributes: %d", error->error_code);
                free(error);
            }
        }
    }
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
        _isDragging = NO;
        _dragStartPosition = XCBMakePoint(0, 0);
        _windowStartPosition = XCBMakePoint(0, 0);
        _isResizing = NO;
        _resizeStartPosition = XCBMakePoint(0, 0);
        _windowStartSize = XCBMakeSize(0, 0);
        _resizeEdge = RESIZE_EDGE_NONE;

        // Generate frame window ID
        self.window = xcb_generate_id(connection.connection);

        // Initialize cursor handling
        [self initCursor];
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

- (void)moveToPosition:(XCBPoint)position {
    // Move window to new position without changing size
    if (self.window != XCB_NONE && self.connection) {
        uint32_t values[2];
        values[0] = (uint32_t)position.x;
        values[1] = (uint32_t)position.y;

        xcb_configure_window([self.connection connection],
                           self.window,
                           XCB_CONFIG_WINDOW_X | XCB_CONFIG_WINDOW_Y,
                           values);

        // Update our internal window rect
        self.windowRect = XCBMakeRect(position, self.windowRect.size);
        [self.connection flush];
        NSLog(@"XCBFrame: Moved window %u to position (%.0f, %.0f)", self.window, position.x, position.y);
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
        // Actually destroy the frame window
        if (self.window != XCB_NONE && self.connection) {
            xcb_destroy_window([self.connection connection], self.window);
            [self.connection flush];
            NSLog(@"XCBFrame: Destroyed frame window %u", self.window);
        }
    }
}

- (void)configureClient {
    // Send synthetic configure notify event to client so it knows the window size changed
    // This is critical for applications like xterm to resize their content
    // For GNUstep apps, we also need to physically resize them
    XCBWindow *clientWindow = [self childWindowForKey:ClientWindow];
    XCBWindow *titlebarWindow = [self childWindowForKey:TitleBar];

    if (!clientWindow || !titlebarWindow) {
        NSLog(@"XCBFrame: configureClient - missing client or titlebar window");
        return;
    }

    xcb_configure_notify_event_t event;
    memset(&event, 0, sizeof(event));

    // Get current frame rect and titlebar height
    XCBRect frameRect = self.windowRect;
    uint16_t titlebarHeight = 22; // Default titlebar height

    if ([titlebarWindow respondsToSelector:@selector(windowRect)]) {
        titlebarHeight = [titlebarWindow windowRect].size.height;
    }

    // Calculate new client size
    uint16_t newClientWidth = frameRect.size.width;
    uint16_t newClientHeight = frameRect.size.height - titlebarHeight;

    // Check if this is a GNUstep window that needs physical resizing
    BOOL isGNUStepWindow = [ThemeRenderer isGNUStepWindow:clientWindow.window connection:self.connection];

    if (isGNUStepWindow) {
        // For GNUstep windows: physically resize the client window first
        NSLog(@"XCBFrame: GNUstep window - physically resizing client window %u to %dx%d",
              clientWindow.window, newClientWidth, newClientHeight);

        uint32_t values[2] = {newClientWidth, newClientHeight};
        xcb_configure_window(self.connection.connection, clientWindow.window,
                           XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT, values);
        [self.connection flush];
    }

    // Synthetic event - coordinates must be in root space
    event.response_type = XCB_CONFIGURE_NOTIFY;
    event.event = clientWindow.window;
    event.window = clientWindow.window;
    event.x = frameRect.origin.x;
    event.y = frameRect.origin.y + titlebarHeight;
    event.width = newClientWidth;
    event.height = newClientHeight;
    event.border_width = 0;
    event.above_sibling = XCB_NONE;
    event.override_redirect = 0;
    event.sequence = 0;

    // Send the synthetic event to the client
    [self.connection sendEvent:(const char*)&event toClient:clientWindow propagate:NO];

    // Update client window's internal rect
    XCBRect clientRect = XCBMakeRect(
        XCBMakePoint(0, titlebarHeight), // Relative to frame
        XCBMakeSize(frameRect.size.width, frameRect.size.height - titlebarHeight)
    );
    clientWindow.windowRect = clientRect;

    NSLog(@"XCBFrame: Sent configure notify to client window %u (size: %dx%d, position: %d,%d, frame: %dx%d)",
          clientWindow.window, event.width, event.height, event.x, event.y,
          (int)frameRect.size.width, (int)frameRect.size.height);
}

- (void)resizeFrame:(XCBSize)newSize {
    // Coordinated resize of frame, titlebar, and client window
    if (self.window == XCB_NONE || !self.connection) {
        return;
    }

    XCBWindow *clientWindow = [self childWindowForKey:ClientWindow];
    XCBWindow *titlebarWindow = [self childWindowForKey:TitleBar];

    if (!clientWindow || !titlebarWindow) {
        NSLog(@"XCBFrame: resizeFrame - missing child windows");
        return;
    }

    uint16_t titlebarHeight = 22;
    if ([titlebarWindow respondsToSelector:@selector(windowRect)]) {
        titlebarHeight = [titlebarWindow windowRect].size.height;
    }

    // Resize frame window
    uint32_t frameValues[2] = {(uint32_t)newSize.width, (uint32_t)newSize.height};
    xcb_configure_window([self.connection connection], self.window,
                        XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT, frameValues);

    // Resize titlebar window
    uint32_t titlebarValues[2] = {(uint32_t)newSize.width, titlebarHeight};
    xcb_configure_window([self.connection connection], titlebarWindow.window,
                        XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT, titlebarValues);

    // Resize client window
    uint32_t clientValues[2] = {(uint32_t)newSize.width, (uint32_t)(newSize.height - titlebarHeight)};
    xcb_configure_window([self.connection connection], clientWindow.window,
                        XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT, clientValues);

    // Update internal rects
    self.windowRect = XCBMakeRect(self.windowRect.origin, newSize);
    titlebarWindow.windowRect = XCBMakeRect(XCBMakePoint(0, 0), XCBMakeSize(newSize.width, titlebarHeight));

    [self.connection flush];

    // Critical: Send configure notify to client so it knows to redraw its content
    [self configureClient];

    NSLog(@"XCBFrame: Coordinated resize to %dx%d (titlebar: %dx%d, client: %dx%d)",
          (int)newSize.width, (int)newSize.height,
          (int)newSize.width, titlebarHeight,
          (int)newSize.width, (int)(newSize.height - titlebarHeight));
}

- (int)resizeEdgeForPoint:(XCBPoint)point inFrame:(XCBRect)frameRect {
    // Determine which edge/corner is being clicked for resize operations
    double x = point.x - frameRect.origin.x;
    double y = point.y - frameRect.origin.y;
    double width = frameRect.size.width;
    double height = frameRect.size.height;

    // Check if point is near edges
    BOOL nearLeft = (x <= RESIZE_BORDER_WIDTH);
    BOOL nearRight = (x >= width - RESIZE_BORDER_WIDTH);
    BOOL nearTop = (y <= RESIZE_BORDER_WIDTH);
    BOOL nearBottom = (y >= height - RESIZE_BORDER_WIDTH);

    // Corner detection takes precedence
    if (nearTop && nearLeft) return RESIZE_EDGE_TOPLEFT;
    if (nearTop && nearRight) return RESIZE_EDGE_TOPRIGHT;
    if (nearBottom && nearLeft) return RESIZE_EDGE_BOTTOMLEFT;
    if (nearBottom && nearRight) return RESIZE_EDGE_BOTTOMRIGHT;

    // Edge detection
    if (nearLeft) return RESIZE_EDGE_LEFT;
    if (nearRight) return RESIZE_EDGE_RIGHT;
    if (nearTop) return RESIZE_EDGE_TOP;
    if (nearBottom) return RESIZE_EDGE_BOTTOM;

    return RESIZE_EDGE_NONE;
}

- (MousePosition)mousePositionForResizeEdge:(int)resizeEdge {
    switch (resizeEdge) {
        case RESIZE_EDGE_LEFT:
            return LeftBorder;
        case RESIZE_EDGE_RIGHT:
            return RightBorder;
        case RESIZE_EDGE_TOP:
            return TopBorder;
        case RESIZE_EDGE_BOTTOM:
            return BottomBorder;
        case RESIZE_EDGE_BOTTOMRIGHT:
        case RESIZE_EDGE_BOTTOMLEFT:
        case RESIZE_EDGE_TOPRIGHT:
        case RESIZE_EDGE_TOPLEFT:
            return BottomRightCorner;  // Use one corner cursor for all corners
        default:
            return None;
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

        // Setup simple timer-based theme integration
        [self setupPeriodicThemeIntegration];
        NSLog(@"GSTheme integration initialized with periodic checking enabled");
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

    // Handle titlebar expose events for GSTheme
    @try {
        ThemeRenderer *integration = [ThemeRenderer sharedInstance];
        if (integration.enabled) {
            xcb_window_t exposedWindow = event->window;

            // Check if the exposed window is a titlebar we're managing
            for (XCBTitleBar *titlebar in integration.managedTitlebars) {
                if ([titlebar window] == exposedWindow) {
                    // This titlebar was exposed, re-apply GSTheme to override XCBKit redrawing
                    NSString *windowIdString = [NSString stringWithFormat:@"%u", exposedWindow];
                    XCBWindow *window = [self.windowsMap objectForKey:windowIdString];

                    if (window && [window isKindOfClass:[XCBFrame class]]) {
                        XCBFrame *frame = (XCBFrame*)window;
                        NSLog(@"Titlebar %u exposed, re-applying GSTheme", exposedWindow);
                        [ThemeRenderer renderGSThemeToWindow:window
                                                             frame:frame
                                                             title:titlebar.windowTitle
                                                            active:YES
                                                    isGNUStepWindow:NO];
                    }
                    break;
                }
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"Exception in titlebar expose handler: %@", exception.reason);
    }
}

- (void)handleEnterNotify:(xcb_enter_notify_event_t*)event {
    // Initialize cursor when entering a window
    XCBWindow *window = [self windowForXCBId:event->event];
    if (window) {
        // If entering a frame, show left pointer cursor initially
        if ([window isKindOfClass:[XCBFrame class]]) {
            XCBFrame *frame = (XCBFrame*)window;
            if (frame.cursor && ![frame.cursor leftPointerSelected]) {
                [frame showLeftPointerCursor];
            }
        } else if ([window isKindOfClass:[XCBTitleBar class]]) {
            // For titlebar, ensure cursor is initialized
            if (!window.cursor) {
                [window initCursor];
            }
            if (window.cursor && ![window.cursor leftPointerSelected]) {
                [window showLeftPointerCursor];
            }
        }
    }
}

- (void)handleLeaveNotify:(xcb_leave_notify_event_t*)event {
    // Minimal implementation
    // NSLog(@"Leave notify for window %u", event->event);
}

- (void)handleFocusIn:(xcb_focus_in_event_t*)event {
    // Minimal implementation
    NSLog(@"XCB_FOCUS_IN received for window %u", event->event);

    // Re-render titlebar with GSTheme as active
    [self applyFocusChangeToWindow:event->event isActive:YES];
}

- (void)handleFocusOut:(xcb_focus_out_event_t*)event {
    // Minimal implementation
    NSLog(@"XCB_FOCUS_OUT received for window %u", event->event);

    // Re-render titlebar with GSTheme as inactive
    [self applyFocusChangeToWindow:event->event isActive:NO];
}

- (void)handleButtonPress:(xcb_button_press_event_t*)event {
    NSLog(@"EVENT: XCB_BUTTON_PRESS received for window %u at (%d, %d)",
          event->event, event->event_x, event->event_y);

    // Check if this is a button click on a GSTheme titlebar
    if ([self handleTitlebarButtonPress:event]) {
        return; // Titlebar button was handled
    }

    // Handle button press for window dragging
    XCBWindow *window = [self windowForXCBId:event->event];
    if (!window) {
        return;
    }

    // Only handle left mouse button (button 1)
    if (event->detail != 1) {
        return;
    }

    // Check if this is a titlebar or frame window
    XCBFrame *frame = nil;
    BOOL isTitleBar = NO;

    if ([window isKindOfClass:[XCBFrame class]]) {
        frame = (XCBFrame*)window;
    } else if ([window isKindOfClass:[XCBTitleBar class]]) {
        isTitleBar = YES;
        if (window.parentWindow && [window.parentWindow isKindOfClass:[XCBFrame class]]) {
            frame = (XCBFrame*)window.parentWindow;
        }
    } else if (window.parentWindow && [window.parentWindow isKindOfClass:[XCBFrame class]]) {
        frame = (XCBFrame*)window.parentWindow;
    }

    // Only handle interactions if we clicked on titlebar or frame (not client window)
    if (frame && (isTitleBar || [window isKindOfClass:[XCBFrame class]])) {
        // Don't allow dragging/resizing if window is maximized
        if (frame.maximized) {
            return;
        }

        // Check if this is a resize operation (clicked near frame edge)
        XCBPoint clickPoint = XCBMakePoint(event->root_x, event->root_y);
        int resizeEdge = [frame resizeEdgeForPoint:clickPoint inFrame:frame.windowRect];

        if (resizeEdge != RESIZE_EDGE_NONE && !isTitleBar) {
            // Start resizing
            frame.isResizing = YES;
            frame.resizeEdge = resizeEdge;
            frame.resizeStartPosition = clickPoint;
            frame.windowStartSize = XCBMakeSize(frame.windowRect.size.width, frame.windowRect.size.height);

            NSLog(@"XCBFrame: Started resizing window %u from edge %d, size %.0fx%.0f",
                  frame.window, resizeEdge, frame.windowStartSize.width, frame.windowStartSize.height);
        } else {
            // Start dragging (titlebar or non-edge frame area)
            frame.isDragging = YES;
            frame.dragStartPosition = XCBMakePoint(event->root_x, event->root_y);
            frame.windowStartPosition = XCBMakePoint(frame.windowRect.origin.x, frame.windowRect.origin.y);

            NSLog(@"XCBFrame: Started dragging window %u from position (%.0f, %.0f)",
                  frame.window, frame.windowStartPosition.x, frame.windowStartPosition.y);
        }

        // Grab the pointer to ensure we receive all motion events
        xcb_cursor_t grab_cursor = XCB_NONE;
        if (frame.cursor) {
            grab_cursor = [frame.cursor cursor];
        }

        xcb_grab_pointer(self.connection,
                        0, // owner_events
                        event->event,
                        XCB_EVENT_MASK_BUTTON_RELEASE | XCB_EVENT_MASK_POINTER_MOTION,
                        XCB_GRAB_MODE_ASYNC,
                        XCB_GRAB_MODE_ASYNC,
                        XCB_NONE, // confine_to
                        grab_cursor, // cursor
                        XCB_CURRENT_TIME);
    }
}

- (void)handleButtonRelease:(xcb_button_release_event_t*)event {
    // Handle button release to end window dragging
    XCBWindow *window = [self windowForXCBId:event->event];
    if (!window) {
        return;
    }

    // Only handle left mouse button (button 1)
    if (event->detail != 1) {
        return;
    }

    // Find the frame that might be dragging
    XCBFrame *frame = nil;
    if ([window isKindOfClass:[XCBFrame class]]) {
        frame = (XCBFrame*)window;
    } else if ([window isKindOfClass:[XCBTitleBar class]]) {
        if (window.parentWindow && [window.parentWindow isKindOfClass:[XCBFrame class]]) {
            frame = (XCBFrame*)window.parentWindow;
        }
    } else if (window.parentWindow && [window.parentWindow isKindOfClass:[XCBFrame class]]) {
        frame = (XCBFrame*)window.parentWindow;
    }

    // Check if any frame is currently dragging or resizing and stop it
    if (!frame) {
        // Search through all windows to find any dragging or resizing frame
        for (NSString *key in self.windowsMap) {
            XCBWindow *win = [self.windowsMap objectForKey:key];
            if ([win isKindOfClass:[XCBFrame class]]) {
                XCBFrame *checkFrame = (XCBFrame*)win;
                if (checkFrame.isDragging || checkFrame.isResizing) {
                    frame = checkFrame;
                    break;
                }
            }
        }
    }

    if (frame && frame.isDragging) {
        // Stop dragging
        frame.isDragging = NO;
        NSLog(@"XCBFrame: Stopped dragging window %u at position (%.0f, %.0f)",
              frame.window, frame.windowRect.origin.x, frame.windowRect.origin.y);

        // Ungrab the pointer
        xcb_ungrab_pointer(self.connection, XCB_CURRENT_TIME);
    } else if (frame && frame.isResizing) {
        // Stop resizing
        frame.isResizing = NO;
        frame.resizeEdge = RESIZE_EDGE_NONE;
        NSLog(@"XCBFrame: Stopped resizing window %u at size %.0fx%.0f",
              frame.window, frame.windowRect.size.width, frame.windowRect.size.height);

        // Ungrab the pointer
        xcb_ungrab_pointer(self.connection, XCB_CURRENT_TIME);
    }

    // After resize completes, update the titlebar with GSTheme
    [self handleResizeComplete:event];
}

- (void)handleMotionNotify:(xcb_motion_notify_event_t*)event {
    // Handle window dragging
    XCBWindow *window = [self windowForXCBId:event->event];
    if (!window) {
        return;
    }

    // Check if this is a frame window and if it's being dragged
    XCBFrame *frame = nil;
    if ([window isKindOfClass:[XCBFrame class]]) {
        frame = (XCBFrame*)window;
    } else if (window.parentWindow && [window.parentWindow isKindOfClass:[XCBFrame class]]) {
        frame = (XCBFrame*)window.parentWindow;
    }

    if (frame && frame.isDragging) {
        // Calculate new position based on mouse movement
        int16_t deltaX = event->root_x - frame.dragStartPosition.x;
        int16_t deltaY = event->root_y - frame.dragStartPosition.y;

        XCBPoint newPosition = XCBMakePoint(
            frame.windowStartPosition.x + deltaX,
            frame.windowStartPosition.y + deltaY
        );

        // Ensure window doesn't go off screen (basic bounds checking)
        XCBScreen *screen = [frame onScreen];
        if (screen) {
            if (newPosition.x < 0) newPosition.x = 0;
            if (newPosition.y < 0) newPosition.y = 0;
            if (newPosition.x + frame.windowRect.size.width > screen.width) {
                newPosition.x = screen.width - frame.windowRect.size.width;
            }
            if (newPosition.y + frame.windowRect.size.height > screen.height) {
                newPosition.y = screen.height - frame.windowRect.size.height;
            }
        }

        // Move the window
        [frame moveToPosition:newPosition];
    } else if (frame && frame.isResizing) {
        // Handle resize operations
        int16_t deltaX = event->root_x - frame.resizeStartPosition.x;
        int16_t deltaY = event->root_y - frame.resizeStartPosition.y;

        XCBSize newSize = frame.windowStartSize;
        XCBPoint newPosition = frame.windowRect.origin;

        // Calculate new size based on resize edge
        switch (frame.resizeEdge) {
            case RESIZE_EDGE_RIGHT:
                newSize.width = frame.windowStartSize.width + deltaX;
                break;
            case RESIZE_EDGE_LEFT:
                newSize.width = frame.windowStartSize.width - deltaX;
                newPosition.x = frame.windowRect.origin.x + deltaX;
                break;
            case RESIZE_EDGE_BOTTOM:
                newSize.height = frame.windowStartSize.height + deltaY;
                break;
            case RESIZE_EDGE_TOP:
                newSize.height = frame.windowStartSize.height - deltaY;
                newPosition.y = frame.windowRect.origin.y + deltaY;
                break;
            case RESIZE_EDGE_BOTTOMRIGHT:
                newSize.width = frame.windowStartSize.width + deltaX;
                newSize.height = frame.windowStartSize.height + deltaY;
                break;
            case RESIZE_EDGE_BOTTOMLEFT:
                newSize.width = frame.windowStartSize.width - deltaX;
                newSize.height = frame.windowStartSize.height + deltaY;
                newPosition.x = frame.windowRect.origin.x + deltaX;
                break;
            case RESIZE_EDGE_TOPRIGHT:
                newSize.width = frame.windowStartSize.width + deltaX;
                newSize.height = frame.windowStartSize.height - deltaY;
                newPosition.y = frame.windowRect.origin.y + deltaY;
                break;
            case RESIZE_EDGE_TOPLEFT:
                newSize.width = frame.windowStartSize.width - deltaX;
                newSize.height = frame.windowStartSize.height - deltaY;
                newPosition.x = frame.windowRect.origin.x + deltaX;
                newPosition.y = frame.windowRect.origin.y + deltaY;
                break;
        }

        // Enforce minimum size
        if (newSize.width < 100) newSize.width = 100;
        if (newSize.height < 50) newSize.height = 50;

        // Perform the resize
        if (newPosition.x != frame.windowRect.origin.x || newPosition.y != frame.windowRect.origin.y) {
            [frame moveToPosition:newPosition];
        }
        [frame resizeFrame:newSize];
    } else if (frame && !frame.isDragging && !frame.isResizing) {
        // Handle cursor changes when hovering over resize edges
        // Use relative coordinates for border detection (like original XCBKit)
        double frameWidth = frame.windowRect.size.width;
        double frameHeight = frame.windowRect.size.height;
        double mouseX = event->event_x;
        double mouseY = event->event_y;

        // Debug logging (commented out)
        // NSLog(@"Mouse motion: x=%.0f, y=%.0f, frame size=%.0fx%.0f",
        //       mouseX, mouseY, frameWidth, frameHeight);

        // Check if mouse is near edges (using same logic as original XCBKit)
        BOOL nearLeft = (mouseX <= RESIZE_BORDER_WIDTH);
        BOOL nearRight = (mouseX >= frameWidth - RESIZE_BORDER_WIDTH);
        BOOL nearTop = (mouseY <= RESIZE_BORDER_WIDTH);
        BOOL nearBottom = (mouseY >= frameHeight - RESIZE_BORDER_WIDTH);

        MousePosition position = None;

        // Corner detection takes precedence
        if (nearTop && nearLeft) {
            position = TopLeftCorner;
        } else if (nearTop && nearRight) {
            position = TopRightCorner;
        } else if (nearBottom && nearLeft) {
            position = BottomLeftCorner;
        } else if (nearBottom && nearRight) {
            position = BottomRightCorner;
        } else if (nearLeft) {
            position = LeftBorder;
        } else if (nearRight) {
            position = RightBorder;
        } else if (nearTop) {
            position = TopBorder;
        } else if (nearBottom) {
            position = BottomBorder;
        }

        if (position != None) {
            // Only change cursor if it's not already the right one (optimization from XCBKit)
            BOOL needsChange = NO;
            switch (position) {
                case RightBorder:
                    needsChange = ![frame.cursor resizeRightSelected];
                    break;
                case LeftBorder:
                    needsChange = ![frame.cursor resizeLeftSelected];
                    break;
                case TopBorder:
                    needsChange = ![frame.cursor resizeTopSelected];
                    break;
                case BottomBorder:
                    needsChange = ![frame.cursor resizeBottomSelected];
                    break;
                case TopLeftCorner:
                    needsChange = ![frame.cursor resizeTopLeftCornerSelected];
                    break;
                case TopRightCorner:
                    needsChange = ![frame.cursor resizeTopRightCornerSelected];
                    break;
                case BottomLeftCorner:
                    needsChange = ![frame.cursor resizeBottomLeftCornerSelected];
                    break;
                case BottomRightCorner:
                    needsChange = ![frame.cursor resizeBottomRightCornerSelected];
                    break;
                default:
                    needsChange = YES;
                    break;
            }

            if (needsChange) {
                [frame showResizeCursorForPosition:position];
            }
        } else {
            // Only change to left pointer if not already selected
            if (![frame.cursor leftPointerSelected]) {
                [frame showLeftPointerCursor];
            }
        }
    } else {
        // Handle resize motion if this is a resize operation (legacy)
        [self handleResizeDuringMotion:event];
    }
}

- (void)handleMapNotify:(xcb_map_notify_event_t*)event {
    // Minimal implementation
    // NSLog(@"Map notify for window %u", event->window);
}

- (void)handleMapRequest:(xcb_map_request_event_t*)event {
    // This is a critical WM function - a client wants to map a window
    NSLog(@"=== MAP REQUEST START: window %u ===", event->window);

    // Check if this window is already managed
    XCBWindow *existingWindow = [self windowForXCBId:event->window];
    if (existingWindow) {
        NSLog(@"Window %u already managed, just mapping it", event->window);
        [self mapWindow:existingWindow];
        return;
    }

    // Get window attributes to check override_redirect
    xcb_get_window_attributes_cookie_t attr_cookie = xcb_get_window_attributes(self.connection, event->window);
    xcb_get_window_attributes_reply_t *attr_reply = xcb_get_window_attributes_reply(self.connection, attr_cookie, NULL);

    if (attr_reply) {
        if (attr_reply->override_redirect) {
            // Override redirect windows (menus, tooltips, popups) should not be managed
            NSLog(@"Window %u has override_redirect=true, mapping without frame", event->window);
            xcb_map_window(self.connection, event->window);
            free(attr_reply);
            return;
        }
        free(attr_reply);
    }

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

    // Basic filtering: check for special window types that never get frames
    NSLog(@"Checking basic window filtering for window %u", event->window);
    BOOL shouldAttemptDecoration = [self shouldDecorateWindow:event->window];
    if (!shouldAttemptDecoration) {
        // Special window types (dock, menu, notification, etc.) don't get frames
        NSLog(@"Window %u is special type, mapping without frame", event->window);
        xcb_map_window(self.connection, event->window);
        free(geom_reply);
        return;
    }

    // Check if this is a GNUstep window
    BOOL isGNUStepWindow = [ThemeRenderer isGNUStepWindow:event->window connection:self];
    BOOL isGNUStepWindowNeedingDecorations = NO;

    if (isGNUStepWindow) {
        NSLog(@"GNUstep window %u detected (size: %dx%d)", event->window, geom_reply->width, geom_reply->height);
        // Check GNUstep decoration preferences
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *backHandlesDecorations = [defaults stringForKey:@"GSBackHandlesWindowDecorations"];
        BOOL gnustepHandlesDecorations = NO;

        if (backHandlesDecorations) {
            gnustepHandlesDecorations = ![backHandlesDecorations boolValue]; // NO means GNUstep decorates
        } else {
            gnustepHandlesDecorations = YES; // Default: GNUstep handles decorations
        }

        if (gnustepHandlesDecorations) {
            // GNUstep handles decorations - map directly without any frames
            NSLog(@"GNUstep window %u handles decorations, mapping directly", event->window);
            xcb_map_window(self.connection, event->window);
            free(geom_reply);
            return;
        } else {
            // GNUstep expects WM to provide decorations - but check if it should be filtered
            NSLog(@"GNUstep window %u needs decorations, checking if should be filtered", event->window);

            // Even GNUstep windows can be context menus - check size and transient properties
            BOOL shouldStillDecorate = [self shouldDecorateWindow:event->window];
            if (!shouldStillDecorate) {
                NSLog(@"GNUstep window %u filtered out (likely context menu), mapping without frame", event->window);
                xcb_map_window(self.connection, event->window);
                free(geom_reply);
                return;
            }

            NSLog(@"GNUstep window %u passed filtering, creating frame", event->window);
            isGNUStepWindowNeedingDecorations = YES;
        }
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
    int borderWidth = 5; // 5px borders for all windows

    int frameX, frameY, frameWidth, frameHeight;

    if (isGNUStepWindowNeedingDecorations) {
        // GNUstep windows: Try to get actual content size, not decorated window size
        int contentWidth = geom_reply->width;
        int contentHeight = geom_reply->height;

        // Try to get WM_NORMAL_HINTS for size constraints (but keep requested size)
        xcb_get_property_cookie_t hints_cookie = xcb_icccm_get_wm_normal_hints(self.connection, event->window);
        xcb_size_hints_t size_hints;
        if (xcb_icccm_get_wm_normal_hints_reply(self.connection, hints_cookie, &size_hints, NULL)) {
            // For GNUstep: respect the actual requested size, but enforce minimums
            if (size_hints.flags & XCB_ICCCM_SIZE_HINT_P_MIN_SIZE) {
                if (contentWidth < size_hints.min_width) {
                    NSLog(@"GNUstep: Enforcing min width %d (was %d)", size_hints.min_width, contentWidth);
                    contentWidth = size_hints.min_width;
                }
                if (contentHeight < size_hints.min_height) {
                    NSLog(@"GNUstep: Enforcing min height %d (was %d)", size_hints.min_height, contentHeight);
                    contentHeight = size_hints.min_height;
                }
            }

            // Also check max size constraints
            if (size_hints.flags & XCB_ICCCM_SIZE_HINT_P_MAX_SIZE) {
                if (contentWidth > size_hints.max_width) {
                    NSLog(@"GNUstep: Enforcing max width %d (was %d)", size_hints.max_width, contentWidth);
                    contentWidth = size_hints.max_width;
                }
                if (contentHeight > size_hints.max_height) {
                    NSLog(@"GNUstep: Enforcing max height %d (was %d)", size_hints.max_height, contentHeight);
                    contentHeight = size_hints.max_height;
                }
            }

            NSLog(@"GNUstep: Using requested geometry %dx%d (constraints applied)",
                  contentWidth, contentHeight);
        } else {
            NSLog(@"GNUstep: No size hints available, using requested geometry: %dx%d",
                  contentWidth, contentHeight);
        }


        frameX = geom_reply->x;
        frameY = geom_reply->y - titlebarHeight;
        frameWidth = contentWidth;
        frameHeight = contentHeight + titlebarHeight;

        NSLog(@"GSIPC: GNUstep window frame: x=%d y=%d w=%d h=%d (content: %dx%d + titlebar: %d)",
              frameX, frameY, frameWidth, frameHeight,
              contentWidth, contentHeight, titlebarHeight);
    } else {
        // Regular X11 windows: Use traditional calculation with borders
        frameX = geom_reply->x - borderWidth;
        frameY = geom_reply->y - titlebarHeight - borderWidth;
        frameWidth = geom_reply->width + (borderWidth * 2);
        frameHeight = geom_reply->height + titlebarHeight + (borderWidth * 2);

        NSLog(@"Regular window frame: x=%d y=%d w=%d h=%d (client: %dx%d + titlebar: %d + borders: %d)",
              frameX, frameY, frameWidth, frameHeight,
              geom_reply->width, geom_reply->height, titlebarHeight, borderWidth);
    }

    // Ensure titlebar is not positioned above screen (Y >= 0)
    if (frameY < 0) {
        frameY = 0;
    }
    
    // Create frame window
    uint32_t frame_mask = XCB_CW_BACK_PIXEL | XCB_CW_EVENT_MASK;
    uint32_t frame_values[2];
    frame_values[0] = screen.screen->black_pixel;
    frame_values[1] = XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT |
                      XCB_EVENT_MASK_SUBSTRUCTURE_NOTIFY |
                      XCB_EVENT_MASK_BUTTON_PRESS |
                      XCB_EVENT_MASK_BUTTON_RELEASE |
                      XCB_EVENT_MASK_POINTER_MOTION |
                      XCB_EVENT_MASK_ENTER_WINDOW |
                      XCB_EVENT_MASK_LEAVE_WINDOW |
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
    
    // Create titlebar window using XCBTitleBar (standalone GSTheme will handle theming)
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
                   XCB_EVENT_MASK_POINTER_MOTION |
                   XCB_EVENT_MASK_ENTER_WINDOW |
                   XCB_EVENT_MASK_LEAVE_WINDOW;
    
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

    // Initialize cursor for titlebar
    [titlebar initCursor];
    
    // Reparent client window into frame
    // Both GNUstep and regular windows now position at (borderWidth, titlebarHeight)
    int clientX = borderWidth;
    int clientY = titlebarHeight;

    xcb_reparent_window(self.connection,
                       event->window,
                       frame.window,
                       clientX,
                       clientY);

    NSLog(@"Client window positioned at (%d, %d) within frame", clientX, clientY);

    // Resize client window to match the calculated content size
    if (isGNUStepWindowNeedingDecorations) {
        // Get the content size we calculated above
        int finalContentWidth = frameWidth;
        int finalContentHeight = frameHeight - titlebarHeight;

        // Always resize GNUstep client windows to match our frame calculations
        uint32_t clientConfigValues[2] = {finalContentWidth, finalContentHeight};
        xcb_configure_window(self.connection, event->window,
                           XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT,
                           clientConfigValues);
        NSLog(@"GSIPC: Resized GNUstep client window to content size: %dx%d",
              finalContentWidth, finalContentHeight);
    }
    
    // Hide borders for windows with fixed sizes (like info panels and logout)
    [self adjustBorderForFixedSizeWindow:event->window];

    // Apply GSTheme decoration (we only reach here for windows that should be decorated)
    NSString *windowTitle = [self getWindowTitle:event->window];

    // Set the window title on both client window and titlebar
    clientWindow.windowTitle = windowTitle;
    titlebar.windowTitle = windowTitle;

    BOOL themeSuccess = [ThemeRenderer renderGSThemeToWindow:clientWindow
                                                      frame:frame
                                                      title:windowTitle
                                                     active:YES
                                            isGNUStepWindow:isGNUStepWindowNeedingDecorations];

    if (!themeSuccess) {
        // This shouldn't happen since we pre-checked, but handle gracefully
        NSLog(@"Unexpected: GSTheme declined to render window %u after pre-check passed", event->window);
        xcb_destroy_window(self.connection, titlebar.window);
        xcb_destroy_window(self.connection, frame.window);
        xcb_map_window(self.connection, event->window);
        free(geom_reply);
        return;
    }

    NSLog(@"GSTheme successfully rendered window %u", event->window);

    // Map frame, titlebar, and client now that theming succeeded
    xcb_map_window(self.connection, titlebar.window);
    xcb_map_window(self.connection, event->window);
    xcb_map_window(self.connection, frame.window);

    NSLog(@"=== MAP REQUEST END: window %u decorated ===", event->window);
    free(geom_reply);
}

- (void)handleUnMapNotify:(xcb_unmap_notify_event_t*)event {
    // Minimal implementation
    NSLog(@"Unmap notify for window %u", event->window);
}

- (void)handleDestroyNotify:(xcb_destroy_notify_event_t*)event {
    // Proper cleanup like the original XCBKit implementation
    NSLog(@"Destroy notify for window %u", event->window);

    XCBWindow *window = [self windowForXCBId:event->window];
    XCBFrame *frameWindow = nil;
    XCBTitleBar *titleBarWindow = nil;
    XCBWindow *clientWindow = nil;

    if ([window isKindOfClass:[XCBFrame class]]) {
        frameWindow = (XCBFrame*)window;
        titleBarWindow = (XCBTitleBar*)[frameWindow childWindowForKey:TitleBar];
        clientWindow = [frameWindow childWindowForKey:ClientWindow];
    } else if ([window isKindOfClass:[XCBWindow class]]) {
        if ([[window parentWindow] isKindOfClass:[XCBFrame class]]) {
            // This is a client window
            frameWindow = (XCBFrame*)[window parentWindow];
            clientWindow = window;
            titleBarWindow = (XCBTitleBar*)[frameWindow childWindowForKey:TitleBar];
            [frameWindow setNeedDestroy:YES]; // This will destroy the frame
        }
    }

    // Unregister all related windows
    if (frameWindow) {
        NSString *frameKey = [NSString stringWithFormat:@"%u", frameWindow.window];
        [self.windowsMap removeObjectForKey:frameKey];
        NSLog(@"Unregistered frame window %u", frameWindow.window);
    }
    if (titleBarWindow) {
        NSString *titleKey = [NSString stringWithFormat:@"%u", titleBarWindow.window];
        [self.windowsMap removeObjectForKey:titleKey];
        NSLog(@"Unregistered titlebar window %u", titleBarWindow.window);
    }
    if (clientWindow) {
        NSString *clientKey = [NSString stringWithFormat:@"%u", clientWindow.window];
        [self.windowsMap removeObjectForKey:clientKey];
        NSLog(@"Unregistered client window %u", clientWindow.window);
    }

    // Remove the destroyed window itself
    NSString *key = [NSString stringWithFormat:@"%u", event->window];
    [self.windowsMap removeObjectForKey:key];

    NSLog(@"XCBConnection: Cleaned up destroyed window %u and associated windows", event->window);
}

- (void)handleConfigureRequest:(xcb_configure_request_event_t*)event {
    // Proper three-window coordination for configure requests
    NSLog(@"Configure request for window %u", event->window);

    // Find the client window
    XCBWindow *clientWindow = [self windowForXCBId:event->window];
    if (!clientWindow) {
        // Unmanaged window - grant request directly
        NSLog(@"Configure request for unmanaged window %u - granting directly", event->window);
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
        return;
    }

    // Check if this is a client window with a frame
    if (!clientWindow.parentWindow || ![clientWindow.parentWindow isKindOfClass:[XCBFrame class]]) {
        // Client window without frame - grant request directly
        NSLog(@"Configure request for unframed client window %u - granting directly", event->window);
        uint32_t values[7];
        int i = 0;
        uint16_t mask = 0;

        if (event->value_mask & XCB_CONFIG_WINDOW_WIDTH) {
            mask |= XCB_CONFIG_WINDOW_WIDTH;
            values[i++] = event->width;
        }
        if (event->value_mask & XCB_CONFIG_WINDOW_HEIGHT) {
            mask |= XCB_CONFIG_WINDOW_HEIGHT;
            values[i++] = event->height;
        }

        xcb_configure_window(self.connection, event->window, mask, values);
        return;
    }

    // Framed client window - coordinate frame, titlebar, and client
    XCBFrame *frame = (XCBFrame*)clientWindow.parentWindow;
    XCBWindow *titlebarWindow = [frame childWindowForKey:TitleBar];

    NSLog(@"Configure request for framed client window %u - coordinating frame %u",
          event->window, frame.window);

    // Get titlebar height
    TitleBarSettingsService *tbSettings = [TitleBarSettingsService sharedInstance];
    uint16_t titlebarHeight = tbSettings.height;

    // Prepare configuration masks and values for all three windows
    uint16_t frameMask = 0, clientMask = 0, titlebarMask = 0;
    uint32_t frameValues[7], clientValues[7], titlebarValues[7];
    int frameIndex = 0, clientIndex = 0, titlebarIndex = 0;

    XCBRect currentFrameRect = frame.windowRect;
    XCBRect newFrameRect = currentFrameRect;

    // Handle width changes
    if (event->value_mask & XCB_CONFIG_WINDOW_WIDTH) {
        frameMask |= XCB_CONFIG_WINDOW_WIDTH;
        clientMask |= XCB_CONFIG_WINDOW_WIDTH;
        titlebarMask |= XCB_CONFIG_WINDOW_WIDTH;

        frameValues[frameIndex++] = event->width;
        clientValues[clientIndex++] = event->width;
        titlebarValues[titlebarIndex++] = event->width;

        newFrameRect.size.width = event->width;
    }

    // Handle height changes (frame = client + titlebar)
    if (event->value_mask & XCB_CONFIG_WINDOW_HEIGHT) {
        frameMask |= XCB_CONFIG_WINDOW_HEIGHT;
        clientMask |= XCB_CONFIG_WINDOW_HEIGHT;

        uint16_t frameHeight = event->height + titlebarHeight;
        frameValues[frameIndex++] = frameHeight;
        clientValues[clientIndex++] = event->height;

        newFrameRect.size.height = frameHeight;
    }

    // Handle position changes (apply to frame only, client stays at offset)
    if (event->value_mask & XCB_CONFIG_WINDOW_X) {
        frameMask |= XCB_CONFIG_WINDOW_X;
        frameValues[frameIndex++] = event->x;
        newFrameRect.origin.x = event->x;
    }

    if (event->value_mask & XCB_CONFIG_WINDOW_Y) {
        frameMask |= XCB_CONFIG_WINDOW_Y;
        frameValues[frameIndex++] = event->y - titlebarHeight; // Adjust for titlebar
        newFrameRect.origin.y = event->y - titlebarHeight;
    }

    // Apply configuration to all three windows
    if (frameMask) {
        xcb_configure_window(self.connection, frame.window, frameMask, frameValues);
        frame.windowRect = newFrameRect;
        NSLog(@"Configured frame %u: %dx%d at (%d,%d)",
              frame.window, (int)newFrameRect.size.width, (int)newFrameRect.size.height,
              (int)newFrameRect.origin.x, (int)newFrameRect.origin.y);
    }

    if (titlebarMask && titlebarWindow) {
        xcb_configure_window(self.connection, titlebarWindow.window, titlebarMask, titlebarValues);
        NSLog(@"Configured titlebar %u width: %d", titlebarWindow.window, titlebarValues[0]);
    }

    if (clientMask) {
        xcb_configure_window(self.connection, clientWindow.window, clientMask, clientValues);
        NSLog(@"Configured client %u: %dx%d",
              clientWindow.window, clientValues[0],
              clientIndex > 1 ? clientValues[1] : (int)currentFrameRect.size.height);
    }

    // CRITICAL: Send synthetic configure notify event (ICCCM compliance)
    [frame configureClient];

    [self flush];
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
    if (!event) return;

    // Check if this is a window title change
    BOOL isTitleChange = NO;

    // Check for WM_NAME property change
    if (event->atom == XCB_ATOM_WM_NAME) {
        isTitleChange = YES;
        NSLog(@"WM_NAME property changed for window %u", event->window);
    } else {
        // Check for _NET_WM_NAME property change
        xcb_intern_atom_cookie_t net_wm_name_cookie = xcb_intern_atom(self.connection, 0, 12, "_NET_WM_NAME");
        xcb_intern_atom_reply_t *net_wm_name_reply = xcb_intern_atom_reply(self.connection, net_wm_name_cookie, NULL);

        if (net_wm_name_reply && event->atom == net_wm_name_reply->atom) {
            isTitleChange = YES;
            NSLog(@"_NET_WM_NAME property changed for window %u", event->window);
        }
        if (net_wm_name_reply) free(net_wm_name_reply);
    }

    if (isTitleChange) {
        // Find the client window and update its title
        XCBWindow *clientWindow = [self windowForXCBId:event->window];
        if (!clientWindow) {
            // This might be a notification for an unmapped window
            NSLog(@"Title change for unknown window %u", event->window);
            return;
        }

        // Get the new title
        NSString *newTitle = [self getWindowTitle:event->window];
        NSLog(@"Title changed for window %u: '%@'", event->window, newTitle);

        // Update the window title
        clientWindow.windowTitle = newTitle;

        // If this client window has a frame, update the titlebar too
        if (clientWindow.parentWindow && [clientWindow.parentWindow isKindOfClass:[XCBFrame class]]) {
            XCBFrame *frame = (XCBFrame*)clientWindow.parentWindow;
            XCBWindow *titlebarWindow = [frame childWindowForKey:TitleBar];

            if (titlebarWindow && [titlebarWindow isKindOfClass:[XCBTitleBar class]]) {
                XCBTitleBar *titlebar = (XCBTitleBar*)titlebarWindow;
                titlebar.windowTitle = newTitle;

                // Check if this is a GNUstep window
                BOOL isGNUStepWindow = [ThemeRenderer isGNUStepWindow:event->window connection:self];

                // Re-render the titlebar with the new title
                BOOL success = [ThemeRenderer renderGSThemeToWindow:clientWindow
                                                              frame:frame
                                                              title:newTitle
                                                             active:titlebar.isActive
                                                    isGNUStepWindow:isGNUStepWindow];

                if (success) {
                    // Update the titlebar display
                    [titlebar putWindowBackgroundWithPixmap:[titlebar pixmap]];
                    [titlebar drawArea:[titlebar windowRect]];
                    [self flush];
                    NSLog(@"Titlebar re-rendered with new title: '%@'", newTitle);
                } else {
                    NSLog(@"Failed to re-render titlebar with new title: '%@'", newTitle);
                }
            }
        }
    }
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

- (void)sendEvent:(const char*)event toClient:(XCBWindow*)clientWindow propagate:(BOOL)propagate {
    // Send synthetic event to client window - critical for notifying apps of window changes
    if (!clientWindow || clientWindow.window == XCB_NONE) {
        NSLog(@"XCBConnection: Cannot send event to invalid client window");
        return;
    }

    xcb_send_event(self.connection,
                   propagate ? 1 : 0,           // propagate flag
                   clientWindow.window,         // destination window
                   XCB_EVENT_MASK_STRUCTURE_NOTIFY, // event mask for configure notify
                   event);                      // event data

    [self flush];
    NSLog(@"XCBConnection: Sent synthetic event to client window %u", clientWindow.window);
}

- (BOOL)shouldDecorateWindow:(xcb_window_t)window {
    // Check _NET_WM_WINDOW_TYPE to determine if window should get decorations
    // Based on original XCBKit logic (lines 705-749)

    NSLog(@"shouldDecorateWindow: Checking window %u", window);

    // Get _NET_WM_WINDOW_TYPE property
    xcb_atom_t net_wm_window_type = [self getAtom:"_NET_WM_WINDOW_TYPE"];
    if (net_wm_window_type == XCB_ATOM_NONE) {
        // If we can't get the atom, assume it's a normal window that should be decorated
        NSLog(@"shouldDecorateWindow: Could not get _NET_WM_WINDOW_TYPE atom");
        return YES;
    }

    xcb_get_property_cookie_t prop_cookie = xcb_get_property(
        self.connection, 0, window, net_wm_window_type, XCB_ATOM_ATOM, 0, UINT32_MAX);
    xcb_get_property_reply_t *prop_reply = xcb_get_property_reply(self.connection, prop_cookie, NULL);

    if (!prop_reply) {
        // No window type property, check for transient windows (context menus often use this)
        return [self shouldDecorateTransientWindow:window];
    }

    if (xcb_get_property_value_length(prop_reply) == 0) {
        // Empty property, check for transient windows
        free(prop_reply);
        return [self shouldDecorateTransientWindow:window];
    }

    // Get the window type atom
    xcb_atom_t *window_type = (xcb_atom_t*)xcb_get_property_value(prop_reply);
    xcb_atom_t type = *window_type;
    free(prop_reply);

    // Get atoms for special window types that shouldn't be decorated
    xcb_atom_t dock_atom = [self getAtom:"_NET_WM_WINDOW_TYPE_DOCK"];
    xcb_atom_t menu_atom = [self getAtom:"_NET_WM_WINDOW_TYPE_MENU"];
    xcb_atom_t popup_menu_atom = [self getAtom:"_NET_WM_WINDOW_TYPE_POPUP_MENU"];
    xcb_atom_t dropdown_menu_atom = [self getAtom:"_NET_WM_WINDOW_TYPE_DROPDOWN_MENU"];
    xcb_atom_t combo_atom = [self getAtom:"_NET_WM_WINDOW_TYPE_COMBO"];
    xcb_atom_t dnd_atom = [self getAtom:"_NET_WM_WINDOW_TYPE_DND"];
    xcb_atom_t utility_atom = [self getAtom:"_NET_WM_WINDOW_TYPE_UTILITY"];
    xcb_atom_t toolbar_atom = [self getAtom:"_NET_WM_WINDOW_TYPE_TOOLBAR"];
    xcb_atom_t tooltip_atom = [self getAtom:"_NET_WM_WINDOW_TYPE_TOOLTIP"];
    xcb_atom_t notification_atom = [self getAtom:"_NET_WM_WINDOW_TYPE_NOTIFICATION"];
    xcb_atom_t splash_atom = [self getAtom:"_NET_WM_WINDOW_TYPE_SPLASH"];

    // Check if this is a special window type that shouldn't be decorated
    if (type == dock_atom) {
        NSLog(@"Window %u is dock type, no decoration", window);
        return NO;
    }
    if (type == menu_atom || type == popup_menu_atom || type == dropdown_menu_atom ||
        type == combo_atom || type == dnd_atom) {
        NSLog(@"Window %u is menu/popup type, no decoration", window);
        return NO;
    }
    if (type == tooltip_atom) {
        NSLog(@"Window %u is tooltip type, no decoration", window);
        return NO;
    }
    if (type == notification_atom) {
        NSLog(@"Window %u is notification type, no decoration", window);
        return NO;
    }
    if (type == splash_atom) {
        NSLog(@"Window %u is splash screen type, no decoration", window);
        return NO;
    }
    if (type == toolbar_atom || type == utility_atom) {
        NSLog(@"Window %u is toolbar/utility type, no decoration", window);
        return NO;
    }


    // Default: normal windows get decorated
    NSLog(@"Window %u is normal type, will be decorated", window);
    return YES;
}

- (xcb_atom_t)getAtom:(const char*)name {
    // Helper method to get atom by name
    xcb_intern_atom_cookie_t cookie = xcb_intern_atom(self.connection, 0, strlen(name), name);
    xcb_intern_atom_reply_t *reply = xcb_intern_atom_reply(self.connection, cookie, NULL);
    if (reply) {
        xcb_atom_t atom = reply->atom;
        free(reply);
        return atom;
    }
    return XCB_ATOM_NONE;
}

- (BOOL)shouldDecorateTransientWindow:(xcb_window_t)window {
    // Check if this is a transient window (WM_TRANSIENT_FOR property)
    // Many context menus and popups use this instead of _NET_WM_WINDOW_TYPE

    xcb_get_property_cookie_t transient_cookie = xcb_get_property(
        self.connection, 0, window, XCB_ATOM_WM_TRANSIENT_FOR, XCB_ATOM_WINDOW, 0, 1);
    xcb_get_property_reply_t *transient_reply = xcb_get_property_reply(self.connection, transient_cookie, NULL);

    if (transient_reply && xcb_get_property_value_length(transient_reply) > 0) {
        // Window has WM_TRANSIENT_FOR property - likely a context menu or dialog
        xcb_window_t *parent = (xcb_window_t*)xcb_get_property_value(transient_reply);
        NSLog(@"Window %u is transient for window %u, no decoration", window, *parent);
        free(transient_reply);
        return NO; // Don't decorate transient windows
    }

    if (transient_reply) {
        free(transient_reply);
    }


    // Not transient and not small, assume normal window
    NSLog(@"Window %u is normal type, will be decorated", window);
    return YES;
}

#pragma mark - XCB Integration Methods for GSTheme

- (void)setupPeriodicThemeIntegration {
    ThemeRenderer *integration = [ThemeRenderer sharedInstance];
    [integration setupPeriodicThemeIntegrationWithConnection:self];
}

- (void)applyFocusChangeToWindow:(xcb_window_t)windowId isActive:(BOOL)isActive {
    @try {
        NSLog(@"handleFocusChange: window %u, isActive: %d", windowId, isActive);

        // Find the window that received focus change
        XCBWindow *window = [self windowForXCBId:windowId];
        if (!window) {
            NSLog(@"handleFocusChange: window %u not found in windowsMap, searching for frame containing it", windowId);
            // The focus event might be for a client window - search all frames
            NSDictionary *windowsMap = [self windowsMap];
            for (NSString *mapWindowId in windowsMap) {
                XCBWindow *mapWindow = [windowsMap objectForKey:mapWindowId];
                if (mapWindow && [mapWindow isKindOfClass:[XCBFrame class]]) {
                    XCBFrame *testFrame = (XCBFrame*)mapWindow;
                    XCBWindow *clientWindow = [testFrame childWindowForKey:ClientWindow];
                    if (clientWindow && [clientWindow window] == windowId) {
                        NSLog(@"handleFocusChange: Found frame containing client window %u", windowId);
                        window = testFrame;
                        break;
                    }
                }
            }
            if (!window) {
                NSLog(@"handleFocusChange: Could not find any frame for window %u", windowId);
                return;
            }
        }

        NSLog(@"handleFocusChange: Found window of type %@", NSStringFromClass([window class]));

        // Find the frame and titlebar
        XCBFrame *frame = nil;
        XCBTitleBar *titlebar = nil;

        if ([window isKindOfClass:[XCBFrame class]]) {
            frame = (XCBFrame*)window;
        } else if ([window isKindOfClass:[XCBTitleBar class]]) {
            titlebar = (XCBTitleBar*)window;
            frame = (XCBFrame*)[titlebar parentWindow];
        } else if ([window parentWindow] && [[window parentWindow] isKindOfClass:[XCBFrame class]]) {
            frame = (XCBFrame*)[window parentWindow];
        }

        if (frame) {
            XCBWindow *titlebarWindow = [frame childWindowForKey:TitleBar];
            if (titlebarWindow && [titlebarWindow isKindOfClass:[XCBTitleBar class]]) {
                titlebar = (XCBTitleBar*)titlebarWindow;
            }
        }

        if (!titlebar) {
            NSLog(@"handleFocusChange: No titlebar found for window %u", windowId);
            return;
        }

        // Use ThemeRenderer to re-render with proper focus state
        ThemeRenderer *integration = [ThemeRenderer sharedInstance];
        [integration rerenderTitlebarForFrame:frame active:isActive];
        [self flush];

    } @catch (NSException *exception) {
        NSLog(@"Exception in handleFocusChange: %@", exception.reason);
    }
}

- (BOOL)handleTitlebarButtonPress:(xcb_button_press_event_t*)pressEvent {
    @try {
        // Find the window that was clicked
        XCBWindow *window = [self windowForXCBId:pressEvent->event];
        NSLog(@"GSTheme: handleTitlebarButtonPress for window ID %u, window object: %@",
              pressEvent->event, window ? NSStringFromClass([window class]) : @"nil");

        if (!window) {
            NSLog(@"GSTheme: No window found for ID %u", pressEvent->event);
            return NO;
        }

        // Check if it's an XCBTitleBar (GSTheme renders to XCBTitleBar, not a separate class)
        if (![window isKindOfClass:[XCBTitleBar class]]) {
            NSLog(@"GSTheme: Window is not XCBTitleBar, it's %@", NSStringFromClass([window class]));
            return NO;
        }

        XCBTitleBar *titlebar = (XCBTitleBar*)window;

        // CRITICAL: Allow X11 to continue processing events
        xcb_allow_events(self.connection, XCB_ALLOW_ASYNC_POINTER, pressEvent->time);

        // Check which button was clicked using ThemeRenderer
        NSPoint clickPoint = NSMakePoint(pressEvent->event_x, pressEvent->event_y);
        ThemeRenderer *integration = [ThemeRenderer sharedInstance];
        GSThemeTitleBarButton button = [integration buttonAtPoint:clickPoint forTitlebar:titlebar];

        if (button == GSThemeTitleBarButtonNone) {
            return NO; // Click wasn't on a button
        }

        // Find the frame that contains this titlebar
        XCBFrame *frame = (XCBFrame*)[titlebar parentWindow];
        if (!frame || ![frame isKindOfClass:[XCBFrame class]]) {
            NSLog(@"GSTheme: Could not find frame for titlebar button action");
            return NO;
        }

        XCBWindow *clientWindow = [frame childWindowForKey:ClientWindow];

        // Handle the button action using xcbkit methods
        switch (button) {
            case GSThemeTitleBarButtonClose:
                NSLog(@"GSTheme: Close button clicked");
                if (clientWindow) {
                    [clientWindow close];
                    [frame setNeedDestroy:YES];
                }
                break;

            case GSThemeTitleBarButtonMiniaturize:
                NSLog(@"GSTheme: Minimize button clicked");
                [frame minimize];
                break;

            case GSThemeTitleBarButtonZoom:
                NSLog(@"GSTheme: Zoom button clicked, frame isMaximized: %d", [frame isMaximized]);
                if ([frame isMaximized]) {
                    // Restore from maximized
                    [frame restoreDimensionAndPosition];
                    [self updateTitlebarAfterResize:titlebar frame:frame];
                } else {
                    // Maximize to screen size
                    XCBScreen *screen = [frame onScreen];
                    XCBSize size = XCBMakeSize([screen width], [screen height]);
                    XCBPoint position = XCBMakePoint(0.0, 0.0);
                    [frame maximizeToSize:size andPosition:position];
                    [frame resizeFrame:size];
                    [self updateTitlebarAfterResize:titlebar frame:frame];
                }
                break;

            default:
                return NO;
        }

        [self flush];
        return YES; // We handled the button press

    } @catch (NSException *exception) {
        NSLog(@"Exception handling titlebar button press: %@", exception.reason);
        return NO;
    }
}

- (void)updateTitlebarAfterResize:(XCBTitleBar*)titlebar frame:(XCBFrame*)frame {
    // Helper method to update titlebar after resize operations
    [titlebar destroyPixmap];
    [titlebar createPixmap];

    // Redraw with GSTheme
    [ThemeRenderer renderGSThemeToWindow:frame
                                         frame:frame
                                         title:[titlebar windowTitle]
                                        active:YES
                               isGNUStepWindow:NO];

    [titlebar putWindowBackgroundWithPixmap:[titlebar pixmap]];
    [titlebar drawArea:[titlebar windowRect]];
}

- (void)adjustBorderForFixedSizeWindow:(xcb_window_t)clientWindowId {
    @try {
        // Check if window has fixed size (min == max in WM_NORMAL_HINTS)
        xcb_size_hints_t sizeHints;
        if (xcb_icccm_get_wm_normal_hints_reply(self.connection,
                                                 xcb_icccm_get_wm_normal_hints(self.connection, clientWindowId),
                                                 &sizeHints,
                                                 NULL)) {
            if ((sizeHints.flags & XCB_ICCCM_SIZE_HINT_P_MIN_SIZE) &&
                (sizeHints.flags & XCB_ICCCM_SIZE_HINT_P_MAX_SIZE) &&
                sizeHints.min_width == sizeHints.max_width &&
                sizeHints.min_height == sizeHints.max_height) {

                NSLog(@"Fixed-size window %u detected - removing border and extra buttons", clientWindowId);

                // Register as fixed-size window (for button hiding in GSTheme rendering)
                [ThemeRenderer registerFixedSizeWindow:clientWindowId];

                // Find the frame for this client window and set its border to 0
                NSDictionary *windowsMap = self.windowsMap;
                for (NSString *mapWindowId in windowsMap) {
                    XCBWindow *window = [windowsMap objectForKey:mapWindowId];

                    if (window && [window isKindOfClass:[XCBFrame class]]) {
                        XCBFrame *frame = (XCBFrame*)window;
                        XCBWindow *clientWindow = [frame childWindowForKey:ClientWindow];

                        if (clientWindow && [clientWindow window] == clientWindowId) {
                            // Set the frame's border width to 0
                            uint32_t borderWidth[] = {0};
                            xcb_configure_window(self.connection,
                                                 [frame window],
                                                 XCB_CONFIG_WINDOW_BORDER_WIDTH,
                                                 borderWidth);
                            [self flush];
                            NSLog(@"Removed border from frame %u for fixed-size window %u", [frame window], clientWindowId);
                            return;
                        }
                    }
                }
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"Exception in adjustBorderForFixedSizeWindow: %@", exception.reason);
    }
}


- (void)clearTitlebarBackgroundBeforeResize:(xcb_motion_notify_event_t*)motionEvent {
    @try {
        // Find the frame
        XCBWindow *window = [self windowForXCBId:motionEvent->event];
        if (!window || ![window isKindOfClass:[XCBFrame class]]) {
            return;
        }
        XCBFrame *frame = (XCBFrame*)window;

        // Get the titlebar
        XCBWindow *titlebarWindow = [frame childWindowForKey:TitleBar];
        if (!titlebarWindow || ![titlebarWindow isKindOfClass:[XCBTitleBar class]]) {
            return;
        }

        // Set background to NONE to prevent X11 from tiling the old pixmap
        uint32_t value = 0; // XCB_BACK_PIXMAP_NONE
        xcb_change_window_attributes(self.connection,
                                     [titlebarWindow window],
                                     XCB_CW_BACK_PIXMAP,
                                     &value);
    } @catch (NSException *exception) {
        // Silently ignore
    }
}

- (void)handleResizeDuringMotion:(xcb_motion_notify_event_t*)motionEvent {
    @try {
        // Find the window involved in the motion
        XCBWindow *window = [self windowForXCBId:motionEvent->event];
        if (!window) {
            return;
        }

        // Check if it's a frame (resize happens on frames)
        XCBFrame *frame = nil;
        if ([window isKindOfClass:[XCBFrame class]]) {
            frame = (XCBFrame*)window;
        }

        if (!frame) {
            return;
        }

        // Get the titlebar
        XCBWindow *titlebarWindow = [frame childWindowForKey:TitleBar];
        if (!titlebarWindow || ![titlebarWindow isKindOfClass:[XCBTitleBar class]]) {
            return;
        }
        XCBTitleBar *titlebar = (XCBTitleBar*)titlebarWindow;

        // After xcbkit processes motion, windowRect is updated with new size
        XCBRect titlebarRect = [titlebar windowRect];
        XCBSize pixmapSize = [titlebar pixmapSize];

        // Only update if the size has changed
        if (pixmapSize.width != titlebarRect.size.width) {
            [self updateTitlebarAfterResize:titlebar frame:frame];
            [titlebar drawArea:titlebarRect];
            [self flush];
            [frame configureClient];
        }
    } @catch (NSException *exception) {
        // Silently ignore exceptions during resize motion to avoid spam
    }
}

- (void)handleResizeComplete:(xcb_button_release_event_t*)releaseEvent {
    @try {
        // Find the window that was released
        XCBWindow *window = [self windowForXCBId:releaseEvent->event];
        if (!window) {
            return;
        }

        // Check if it's a frame (resize happens on frames)
        XCBFrame *frame = nil;
        if ([window isKindOfClass:[XCBFrame class]]) {
            frame = (XCBFrame*)window;
        } else if ([window parentWindow] && [[window parentWindow] isKindOfClass:[XCBFrame class]]) {
            frame = (XCBFrame*)[window parentWindow];
        }

        if (!frame) {
            return;
        }

        // Get the titlebar
        XCBWindow *titlebarWindow = [frame childWindowForKey:TitleBar];
        if (!titlebarWindow || ![titlebarWindow isKindOfClass:[XCBTitleBar class]]) {
            return;
        }
        XCBTitleBar *titlebar = (XCBTitleBar*)titlebarWindow;

        // Check if the titlebar size has changed (compare pixmap size to window rect)
        XCBRect titlebarRect = [titlebar windowRect];
        XCBSize pixmapSize = [titlebar pixmapSize];

        if (pixmapSize.width != titlebarRect.size.width ||
            pixmapSize.height != titlebarRect.size.height) {
            NSLog(@"GSTheme: Titlebar size changed from %fx%f to %fx%f, recreating pixmap",
                  pixmapSize.width, pixmapSize.height,
                  titlebarRect.size.width, titlebarRect.size.height);

            [self updateTitlebarAfterResize:titlebar frame:frame];
            [titlebar drawArea:[titlebar windowRect]];
            [self flush];
            [frame configureClient];

            NSLog(@"GSTheme: Titlebar redrawn after resize, client notified");
        }
    } @catch (NSException *exception) {
        NSLog(@"Exception in handleResizeComplete: %@", exception.reason);
    }
}

#pragma mark - Window Title Retrieval

- (NSString*)getWindowTitle:(xcb_window_t)window {
    if (!self.connection || window == XCB_NONE) {
        return @"";
    }

    NSString *title = @"";

    // Try to get _NET_WM_NAME first (UTF-8 encoded)
    xcb_intern_atom_cookie_t net_wm_name_cookie = xcb_intern_atom(self.connection, 0, 12, "_NET_WM_NAME");
    xcb_intern_atom_reply_t *net_wm_name_reply = xcb_intern_atom_reply(self.connection, net_wm_name_cookie, NULL);

    if (net_wm_name_reply) {
        xcb_atom_t net_wm_name_atom = net_wm_name_reply->atom;
        free(net_wm_name_reply);

        xcb_get_property_cookie_t prop_cookie = xcb_get_property(self.connection, 0, window,
                                                                net_wm_name_atom, XCB_ATOM_ANY, 0, UINT32_MAX);
        xcb_get_property_reply_t *prop_reply = xcb_get_property_reply(self.connection, prop_cookie, NULL);

        if (prop_reply && xcb_get_property_value_length(prop_reply) > 0) {
            const char *name = (const char*)xcb_get_property_value(prop_reply);
            NSUInteger length = xcb_get_property_value_length(prop_reply);
            title = [[NSString alloc] initWithBytes:name length:length encoding:NSUTF8StringEncoding];
            free(prop_reply);

            if (title && [title length] > 0) {
                NSLog(@"Retrieved _NET_WM_NAME for window %u: '%@'", window, title);
                return title;
            }
        }
        if (prop_reply) free(prop_reply);
    }

    // Fallback to WM_NAME (standard ICCCM property)
    xcb_get_property_cookie_t wm_name_cookie = xcb_icccm_get_wm_name(self.connection, window);
    xcb_icccm_get_text_property_reply_t wm_name_reply;

    if (xcb_icccm_get_wm_name_reply(self.connection, wm_name_cookie, &wm_name_reply, NULL)) {
        if (wm_name_reply.name && wm_name_reply.name_len > 0) {
            title = [[NSString alloc] initWithBytes:wm_name_reply.name
                                             length:wm_name_reply.name_len
                                           encoding:NSUTF8StringEncoding];

            if (!title) {
                // Try with Latin-1 encoding if UTF-8 fails
                title = [[NSString alloc] initWithBytes:wm_name_reply.name
                                                 length:wm_name_reply.name_len
                                               encoding:NSISOLatin1StringEncoding];
            }
        }
        xcb_icccm_get_text_property_reply_wipe(&wm_name_reply);

        if (title && [title length] > 0) {
            NSLog(@"Retrieved WM_NAME for window %u: '%@'", window, title);
            return title;
        }
    }

    // If no title found, try to get the window class for fallback
    xcb_get_property_cookie_t class_cookie = xcb_icccm_get_wm_class(self.connection, window);
    xcb_icccm_get_wm_class_reply_t class_reply;

    if (xcb_icccm_get_wm_class_reply(self.connection, class_cookie, &class_reply, NULL)) {
        if (class_reply.class_name && strlen(class_reply.class_name) > 0) {
            title = [NSString stringWithUTF8String:class_reply.class_name];
            NSLog(@"Using WM_CLASS as fallback title for window %u: '%@'", window, title);
        }
        xcb_icccm_get_wm_class_reply_wipe(&class_reply);
    }

    if (!title || [title length] == 0) {
        title = [NSString stringWithFormat:@"Window %u", window];
        NSLog(@"No title found for window %u, using fallback: '%@'", window, title);
    }

    return title;
}

@end
