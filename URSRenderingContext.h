//
//  URSRenderingContext.h
//  uroswm - Unified Damage Notification
//
//  Wraps rendering operations to automatically notify the compositor
//  when rendering is complete. This ensures consistent damage notification
//  without manual calls scattered throughout the codebase.
//

#import <Foundation/Foundation.h>
#import <AppKit/NSGraphics.h>
#import <xcb/xcb.h>

@class URSCompositingManager;

/**
 * URSRenderingContext provides automatic compositor notification.
 * 
 * Usage:
 *   URSRenderingContext *ctx = [[URSRenderingContext alloc] initWithWindow:windowId];
 *   // ... perform rendering operations ...
 *   [ctx endRendering];  // or let ARC release the context
 *
 * When the context is ended or deallocated, it automatically notifies
 * the compositor to schedule a repaint of the affected window region.
 */
@interface URSRenderingContext : NSObject

// The window being rendered to
@property (readonly, nonatomic) xcb_window_t windowId;

// Whether the context is active (rendering in progress)
@property (readonly, nonatomic) BOOL active;

// Create a rendering context for a specific window
- (instancetype)initWithWindow:(xcb_window_t)windowId;

// Create a rendering context for a window with a specific damage region
- (instancetype)initWithWindow:(xcb_window_t)windowId 
                        region:(NSRect)damageRegion;

// Begin rendering (called automatically in init)
- (void)beginRendering;

// End rendering and notify compositor
// Called automatically on dealloc if not called explicitly
- (void)endRendering;

// Mark an additional region as damaged within this context
- (void)addDamageRect:(NSRect)rect;

// Convenience class method for one-shot rendering notification
+ (void)notifyRenderingComplete:(xcb_window_t)windowId;

// Convenience class method with damage region
+ (void)notifyRenderingComplete:(xcb_window_t)windowId 
                         region:(NSRect)damageRegion;

@end
