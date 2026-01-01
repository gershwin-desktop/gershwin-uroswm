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

// Import GNUstep window level constants
typedef enum {
    WindowTypeNormal,
    WindowTypeDesktop,
    WindowTypeDock,
    WindowTypePanel,
    WindowTypeDialog
} WindowType;

// GNUstep Window Manager Attributes (from libs-back)
typedef struct {
    unsigned long flags;
    unsigned long window_style;
    unsigned long window_level;
    unsigned long reserved;
    xcb_pixmap_t miniaturize_pixmap;
    xcb_pixmap_t close_pixmap;
    xcb_pixmap_t miniaturize_mask;
    xcb_pixmap_t close_mask;
    unsigned long extra_flags;
} GNUstepWMAttributes;

// GNUstep WM attribute flags
#define GSWindowStyleAttr           (1<<0)
#define GSWindowLevelAttr           (1<<1)
#define GSMiniaturizePixmapAttr     (1<<3)
#define GSClosePixmapAttr           (1<<4)
#define GSMiniaturizeMaskAttr       (1<<5)
#define GSCloseMaskAttr             (1<<6)
#define GSExtraFlagsAttr            (1<<7)

// GNUstep extra flags for window filtering
#define GSDocumentEditedFlag                    (1<<0)
#define GSWindowWillResizeNotificationsFlag     (1<<1)
#define GSWindowWillMoveNotificationsFlag       (1<<2)
#define GSNoApplicationIconFlag                 (1<<5)

// Forward declarations
@class XCBConnection;
@class XCBWindow;
@class XCBFrame;
@class XCBTitleBar;
@class XCBScreen;
@class XCBVisual;

// Constants for child window keys
extern NSString * const TitleBar;
extern NSString * const ClientWindow;

// Titlebar color enum (from XCBKit)
typedef NS_ENUM(NSInteger, ETitleBarColor) {
    ETitleBarColorInactive = 0,
    ETitleBarColorActive = 1
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

// GNUstep Window Manager attributes for filtering
@property (assign, nonatomic) GNUstepWMAttributes wmAttributes;
@property (assign, nonatomic) unsigned long windowStyle;
@property (assign, nonatomic) unsigned long windowLevel;
@property (assign, nonatomic) BOOL skipTaskbar;
@property (assign, nonatomic) BOOL skipPager;
@property (assign, nonatomic) BOOL documentEdited;

- (instancetype)init;
- (void)setWindow:(xcb_window_t)window;
- (void)setConnection:(XCBConnection*)connection;
- (XCBRect)windowRect;
- (void)close;
- (void)maximizeToSize:(XCBSize)size andPosition:(XCBPoint)position;

// Window filtering methods
- (void)updateWMAttributes;
- (BOOL)shouldShowInTaskbar;
- (BOOL)shouldShowInPager;
- (BOOL)shouldDecorate;
- (void)setSkipTaskbar:(BOOL)skip;
- (void)setSkipPager:(BOOL)skip;

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

- (instancetype)initWithClientWindow:(XCBWindow*)clientWindow 
                      withConnection:(XCBConnection*)connection;
- (XCBWindow*)childWindowForKey:(NSString*)key;
- (void)setChildWindow:(XCBWindow*)childWindow forKey:(NSString*)key;
- (BOOL)isMaximized;
- (void)minimize;
- (void)maximizeToSize:(XCBSize)size andPosition:(XCBPoint)position;
- (XCBScreen*)onScreen;
- (void)restoreDimensionAndPosition;
- (void)setNeedDestroy:(BOOL)needDestroy;

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

// Store NSWindow wrappers for X11 applications
@property (strong, nonatomic) NSMutableDictionary *nsWindowWrappers;
// Map titlebar/frame window IDs back to original X11 window IDs
@property (strong, nonatomic) NSMutableDictionary *titlebarToClientMap;
// Track window dragging state
@property (assign, nonatomic) BOOL isDragging;
@property (assign, nonatomic) xcb_window_t draggingWindow;

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

// Window filtering utilities (legacy)
- (void)detectWindowTypeForWindow:(XCBWindow*)window;
- (BOOL)shouldManageWindow:(XCBWindow*)window;

// NSWindow wrapper approach (new)
- (WindowType)detectWindowTypeForX11Window:(xcb_window_t)x11Window;
- (NSWindow*)createNSWindowWrapperForX11Window:(xcb_window_t)x11Window;
- (BOOL)shouldManageNSWindow:(NSWindow*)nsWindow;
- (BOOL)isGNUstepApplication:(xcb_window_t)x11Window;
- (void)updateNSWindowWrapperPosition:(xcb_window_t)x11Window;

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

// Utility function to copy NSBitmapImageRep data to XCB pixmap
// This replaces Cairo functionality with direct XCB operations
+ (BOOL)copyBitmapToPixmap:(NSBitmapImageRep*)bitmap
                  toPixmap:(xcb_pixmap_t)pixmap
                connection:(xcb_connection_t*)connection
                    window:(xcb_window_t)window
                    visual:(xcb_visualtype_t*)visualType;

@end
