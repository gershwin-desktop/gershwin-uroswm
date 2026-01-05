//
//  XCBWrapper.h
//  uroswm - Minimal XCB Wrapper
//
//  Minimal XCB wrapper to replace XCBKit dependency.
//  Only includes the absolutely necessary functionality.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <xcb/xcb.h>
#import <xcb/xcb_icccm.h>
#import <xcb/xcb_cursor.h>
#import "ThemeRenderer.h"

// Forward declarations
@class XCBConnection;
@class XCBWindow;
@class XCBFrame;
@class XCBTitleBar;
@class XCBScreen;
@class XCBVisual;
@class XCBCursor;
@class WindowManagerDelegate;

// Constants for child window keys
extern NSString * const TitleBar;
extern NSString * const ClientWindow;

// Constants for resize edges
#define RESIZE_EDGE_NONE     0
#define RESIZE_EDGE_LEFT     1
#define RESIZE_EDGE_RIGHT    2
#define RESIZE_EDGE_TOP      3
#define RESIZE_EDGE_BOTTOM   4
#define RESIZE_EDGE_TOPLEFT     5
#define RESIZE_EDGE_TOPRIGHT    6
#define RESIZE_EDGE_BOTTOMLEFT  7
#define RESIZE_EDGE_BOTTOMRIGHT 8

#define RESIZE_BORDER_WIDTH 10  // Pixels from edge to detect resize (industry standard)

// Titlebar color enum (from XCBKit)
typedef NS_ENUM(NSInteger, ETitleBarColor) {
    ETitleBarColorInactive = 0,
    ETitleBarColorActive = 1
};

// Mouse position enum for cursor handling
typedef NS_ENUM(NSInteger, MousePosition) {
    RightBorder,
    LeftBorder,
    TopBorder,
    BottomBorder,
    TopLeftCorner,
    TopRightCorner,
    BottomLeftCorner,
    BottomRightCorner,
    Error,
    None
};

// Simple Point structure
typedef struct {
    double x;
    double y;
} XCBPoint;

static inline XCBPoint XCBMakePoint(double x, double y) {
    XCBPoint p;
    p.x = x;
    p.y = y;
    return p;
}

// Simple Size structure
typedef struct {
    double width;
    double height;
} XCBSize;

static inline XCBSize XCBMakeSize(double width, double height) {
    XCBSize s;
    s.width = width;
    s.height = height;
    return s;
}

// Simple Rect structure
typedef struct {
    XCBPoint origin;
    XCBSize size;
} XCBRect;

static inline XCBRect XCBMakeRect(XCBPoint origin, XCBSize size) {
    XCBRect r;
    r.origin = origin;
    r.size = size;
    return r;
}

#pragma mark - XCBVisual

@interface XCBVisual : NSObject

@property (assign, nonatomic) xcb_visualid_t visualId;
@property (assign, nonatomic) xcb_visualtype_t *visualType;

- (instancetype)initWithVisualId:(xcb_visualid_t)visualId;
- (void)setVisualTypeForScreen:(XCBScreen*)screen;

@end

#pragma mark - XCBCursor

@interface XCBCursor : NSObject

@property (strong, nonatomic) XCBConnection *connection;
@property (strong, nonatomic) XCBScreen *screen;
@property (nonatomic) xcb_cursor_context_t *context;
@property (strong, nonatomic) NSString *cursorPath;
@property (nonatomic) xcb_cursor_t cursor;
@property (strong, nonatomic) NSMutableDictionary *cursors;
@property (strong, nonatomic) NSString *leftPointerName;
@property (strong, nonatomic) NSString *resizeBottomCursorName;
@property (strong, nonatomic) NSString *resizeRightCursorName;
@property (strong, nonatomic) NSString *resizeLeftCursorName;
@property (strong, nonatomic) NSString *resizeTopCursorName;
@property (strong, nonatomic) NSString *resizeBottomRightCornerCursorName;
@property (strong, nonatomic) NSString *resizeBottomLeftCornerCursorName;
@property (strong, nonatomic) NSString *resizeTopRightCornerCursorName;
@property (strong, nonatomic) NSString *resizeTopLeftCornerCursorName;
@property (assign, nonatomic) BOOL leftPointerSelected;
@property (assign, nonatomic) BOOL resizeBottomSelected;
@property (assign, nonatomic) BOOL resizeRightSelected;
@property (assign, nonatomic) BOOL resizeLeftSelected;
@property (assign, nonatomic) BOOL resizeBottomRightCornerSelected;
@property (assign, nonatomic) BOOL resizeBottomLeftCornerSelected;
@property (assign, nonatomic) BOOL resizeTopRightCornerSelected;
@property (assign, nonatomic) BOOL resizeTopLeftCornerSelected;
@property (assign, nonatomic) BOOL resizeTopSelected;

- (instancetype)initWithConnection:(XCBConnection *)aConnection screen:(XCBScreen*)aScreen;
- (BOOL)createContext;
- (void)destroyContext;
- (void)destroyCursor;
- (xcb_cursor_t)selectLeftPointerCursor;
- (xcb_cursor_t)selectResizeCursorForPosition:(MousePosition)position;

@end

#pragma mark - XCBScreen

@interface XCBScreen : NSObject

@property (assign, nonatomic) xcb_screen_t *screen;
@property (assign, nonatomic) int screenNumber;

- (instancetype)initWithScreen:(xcb_screen_t*)screen number:(int)number;
- (XCBWindow*)rootWindow;
- (uint16_t)width;
- (uint16_t)height;

@end

#pragma mark - XCBWindow

@interface XCBWindow : NSObject

@property (assign, nonatomic) xcb_window_t window;
@property (strong, nonatomic) XCBConnection *connection;
@property (strong, nonatomic) NSString *windowTitle;
@property (strong, nonatomic) XCBWindow *parentWindow;
@property (assign, nonatomic) XCBRect windowRect;
@property (strong, nonatomic) XCBCursor *cursor;

- (instancetype)init;
- (void)setWindow:(xcb_window_t)window;
- (void)setConnection:(XCBConnection*)connection;
- (XCBRect)windowRect;
- (void)close;
- (void)maximizeToSize:(XCBSize)size andPosition:(XCBPoint)position;
- (void)initCursor;
- (void)showLeftPointerCursor;
- (void)showResizeCursorForPosition:(MousePosition)position;
- (void)changeAttributes:(const void*)valueList withMask:(uint32_t)valueMask checked:(BOOL)checked;

@end

#pragma mark - XCBTitleBar

@interface XCBTitleBar : XCBWindow

@property (assign, nonatomic) xcb_pixmap_t pixmap;
@property (assign, nonatomic) xcb_pixmap_t dPixmap;
@property (strong, nonatomic) XCBVisual *visual;
@property (assign, nonatomic) NSRect frame;
@property (assign, nonatomic) BOOL isActive;

- (void)setPixmap:(xcb_pixmap_t)pixmap;
- (xcb_pixmap_t)pixmap;
- (xcb_pixmap_t)dPixmap;
- (void)createPixmap;
- (void)putWindowBackgroundWithPixmap:(xcb_pixmap_t)pixmap;
- (void)drawArea:(XCBRect)rect;
- (XCBSize)pixmapSize;
- (void)destroyPixmap;
- (void)maximizeToSize:(XCBSize)size andPosition:(XCBPoint)position;

@end

#pragma mark - XCBFrame

@interface XCBFrame : XCBWindow

@property (strong, nonatomic) NSMutableDictionary *childWindows;
@property (strong, nonatomic) XCBWindow *clientWindow;
@property (assign, nonatomic) XCBRect windowRect;
@property (assign, nonatomic) BOOL maximized;
@property (assign, nonatomic) NSRect savedRect; // For restoring from maximized state
@property (assign, nonatomic) BOOL isDragging;
@property (assign, nonatomic) XCBPoint dragStartPosition;
@property (assign, nonatomic) XCBPoint windowStartPosition;
@property (assign, nonatomic) BOOL isResizing;
@property (assign, nonatomic) XCBPoint resizeStartPosition;
@property (assign, nonatomic) XCBSize windowStartSize;
@property (assign, nonatomic) int resizeEdge; // Which edge/corner is being resized

- (instancetype)initWithClientWindow:(XCBWindow*)clientWindow
                      withConnection:(XCBConnection*)connection;
- (XCBWindow*)childWindowForKey:(NSString*)key;
- (void)setChildWindow:(XCBWindow*)childWindow forKey:(NSString*)key;
- (BOOL)isMaximized;
- (void)minimize;
- (void)maximizeToSize:(XCBSize)size andPosition:(XCBPoint)position;
- (void)moveToPosition:(XCBPoint)position;
- (XCBScreen*)onScreen;
- (void)restoreDimensionAndPosition;
- (void)setNeedDestroy:(BOOL)needDestroy;
- (void)configureClient;
- (void)resizeFrame:(XCBSize)newSize;
- (int)resizeEdgeForPoint:(XCBPoint)point inFrame:(XCBRect)frameRect;
- (MousePosition)mousePositionForResizeEdge:(int)resizeEdge;

@end

#pragma mark - EWMHService

@interface EWMHService : NSObject

@property (strong, nonatomic) XCBConnection *connection;

+ (instancetype)sharedInstanceWithConnection:(XCBConnection*)connection;
- (void)putPropertiesForRootWindow:(XCBWindow*)rootWindow 
                        andWmWindow:(XCBWindow*)wmWindow;

@end

#pragma mark - TitleBarSettingsService

@interface TitleBarSettingsService : NSObject

@property (assign, nonatomic) NSInteger height;
@property (assign, nonatomic) XCBPoint closePosition;
@property (assign, nonatomic) XCBPoint minimizePosition;
@property (assign, nonatomic) XCBPoint maximizePosition;

+ (instancetype)sharedInstance;
- (void)setHeight:(NSInteger)height;
- (void)setClosePosition:(XCBPoint)position;
- (void)setMinimizePosition:(XCBPoint)position;
- (void)setMaximizePosition:(XCBPoint)position;

@end

#pragma mark - XCBConnection

@interface XCBConnection : NSObject

@property (strong, nonatomic) NSMutableDictionary *windowsMap;
@property (strong, nonatomic) NSMutableArray *screens;
@property (assign, nonatomic) xcb_connection_t *connection;
@property (assign, nonatomic) BOOL needFlush;
@property (weak, nonatomic) WindowManagerDelegate *delegate;

// Singleton
+ (instancetype)sharedConnectionAsWindowManager:(BOOL)asWindowManager;

// Core XCB operations
- (xcb_connection_t*)connection;
- (void)flush;
- (void)setNeedFlush:(BOOL)needFlush;

// Window management
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
                    registerWindow:(BOOL)shouldRegister;

- (void)registerWindow:(XCBWindow*)window;
- (void)mapWindow:(XCBWindow*)window;
- (XCBWindow*)windowForXCBId:(xcb_window_t)windowId;

// Window manager operations
- (void)registerAsWindowManager:(BOOL)registerFlag
                       screenId:(int)screenId
                selectionWindow:(XCBWindow*)selectionWindow;

// Event handlers
- (void)handleVisibilityEvent:(xcb_visibility_notify_event_t*)event;
- (void)handleExpose:(xcb_expose_event_t*)event;
- (void)handleEnterNotify:(xcb_enter_notify_event_t*)event;
- (void)handleLeaveNotify:(xcb_leave_notify_event_t*)event;
- (void)handleFocusIn:(xcb_focus_in_event_t*)event;
- (void)handleFocusOut:(xcb_focus_out_event_t*)event;
- (void)handleButtonPress:(xcb_button_press_event_t*)event;
- (void)handleButtonRelease:(xcb_button_release_event_t*)event;
- (void)handleMotionNotify:(xcb_motion_notify_event_t*)event;
- (void)handleMapNotify:(xcb_map_notify_event_t*)event;
- (void)handleMapRequest:(xcb_map_request_event_t*)event;
- (void)handleUnMapNotify:(xcb_unmap_notify_event_t*)event;
- (void)handleDestroyNotify:(xcb_destroy_notify_event_t*)event;
- (void)handleConfigureRequest:(xcb_configure_request_event_t*)event;
- (void)handleConfigureWindowRequest:(xcb_configure_request_event_t*)event;
- (void)handleConfigureNotify:(xcb_configure_notify_event_t*)event;
- (void)handlePropertyNotify:(xcb_property_notify_event_t*)event;
- (void)handleClientMessage:(xcb_client_message_event_t*)event;

// Client notification
- (void)sendEvent:(const char*)event toClient:(XCBWindow*)clientWindow propagate:(BOOL)propagate;

// Window filtering
- (BOOL)shouldDecorateWindow:(xcb_window_t)window;
- (BOOL)shouldDecorateTransientWindow:(xcb_window_t)window;

// Window title retrieval
- (NSString*)getWindowTitle:(xcb_window_t)window;

// GSTheme Integration Methods (XCB-specific integration)
- (void)applyFocusChangeToWindow:(xcb_window_t)windowId isActive:(BOOL)isActive;
- (BOOL)handleTitlebarButtonPress:(xcb_button_press_event_t*)pressEvent;
- (void)adjustBorderForFixedSizeWindow:(xcb_window_t)clientWindowId;
- (void)setupPeriodicThemeIntegration;
- (void)clearTitlebarBackgroundBeforeResize:(xcb_motion_notify_event_t*)motionEvent;
- (void)handleResizeDuringMotion:(xcb_motion_notify_event_t*)motionEvent;
- (void)handleResizeComplete:(xcb_button_release_event_t*)releaseEvent;
- (void)updateTitlebarAfterResize:(XCBTitleBar*)titlebar frame:(XCBFrame*)frame;

// Utility function to copy NSBitmapImageRep data to XCB pixmap
// This replaces Cairo functionality with direct XCB operations
+ (BOOL)copyBitmapToPixmap:(NSBitmapImageRep*)bitmap
                  toPixmap:(xcb_pixmap_t)pixmap
                connection:(xcb_connection_t*)connection
                    window:(xcb_window_t)window
                    visual:(xcb_visualtype_t*)visualType;

@end
