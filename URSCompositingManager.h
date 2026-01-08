//
//  URSCompositingManager.h
//  uroswm - XRender Compositing Manager
//
//  Provides optional XRender-based compositing for window transparency and effects.
//  Uses defensive coding with fallback to non-compositing mode on any errors.
//  Only activated when --compositing flag is specified.
//

#import <Foundation/Foundation.h>
#import <XCBKit/XCBConnection.h>

@interface URSCompositingManager : NSObject

// Singleton access
+ (instancetype)sharedManager;

// Compositing state
@property (readonly, nonatomic) BOOL compositingEnabled;
@property (readonly, nonatomic) BOOL compositingActive;

// Initialize compositing (must be called before activation)
- (BOOL)initializeWithConnection:(XCBConnection *)connection;

// Activate/deactivate compositing
// Returns YES on success, NO on failure (falls back to non-compositing)
- (BOOL)activateCompositing;
- (void)deactivateCompositing;

// Window management for compositing
- (void)registerWindow:(xcb_window_t)window;
- (void)unregisterWindow:(xcb_window_t)window;
- (void)updateWindow:(xcb_window_t)window;

// Window state changes
- (void)mapWindow:(xcb_window_t)window;
- (void)unmapWindow:(xcb_window_t)window;
- (void)moveWindow:(xcb_window_t)windowId x:(int16_t)x y:(int16_t)y;
- (void)resizeWindow:(xcb_window_t)windowId x:(int16_t)x y:(int16_t)y 
               width:(uint16_t)width height:(uint16_t)height;
// Move window without resize (for drag operations) - more efficient than resizeWindow
- (void)moveWindow:(xcb_window_t)windowId x:(int16_t)x y:(int16_t)y;

// OPTIMIZATION: Notify compositor that stacking order changed (window raised/lowered)
- (void)markStackingOrderDirty;

// Force immediate repair without deferring to next runloop (use during interactive drag)
- (void)performRepairNow;

// Render the composite screen
- (void)compositeScreen;

// Schedule a throttled composite (preferred for event-driven updates)
- (void)scheduleComposite;

// Perform repair immediately without deferring (for critical updates like cursor blinking)
- (void)performRepairNow;

// Handle damage events
- (void)handleDamageNotify:(xcb_window_t)window;

// Extension event base access (for event routing)
- (uint8_t)damageEventBase;

// Cleanup
- (void)cleanup;

@end
