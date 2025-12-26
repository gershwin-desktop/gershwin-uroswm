//
//  UROSWindowDecorator.h
//  uroswm - Independent Window Decoration with ARGB Frames
//
//  Creates window decorations using 32-bit ARGB visuals for smooth
//  anti-aliased rounded corners and drop shadows.
//

#import <Foundation/Foundation.h>
#import <XCBKit/XCBConnection.h>
#import "UROSTitleBar.h"
#import "UROSCompositor.h"

@interface UROSWindowDecorator : NSObject

// Set the compositor (provides ARGB visual)
+ (void)setCompositor:(UROSCompositor*)compositor;

// Window decoration management
+ (void)decorateWindow:(xcb_window_t)clientWindow
        withConnection:(XCBConnection*)connection
                 title:(NSString*)title;

+ (void)updateWindowTitle:(xcb_window_t)clientWindow title:(NSString*)title;
+ (void)setWindowActive:(xcb_window_t)clientWindow active:(BOOL)active;
+ (void)undecoateWindow:(xcb_window_t)clientWindow;

// Get frame window for a client
+ (xcb_window_t)frameWindowForClient:(xcb_window_t)clientWindow;

// Re-render frame (for expose events)
+ (void)renderFrame:(xcb_window_t)frameWindow;

// Call after window resize to update frame
+ (void)updateFrameForClient:(xcb_window_t)clientWindow
                  connection:(XCBConnection*)connection
                       width:(uint16_t)width
                      height:(uint16_t)height;

// Get titlebar for a client window
+ (UROSTitleBar*)titlebarForWindow:(xcb_window_t)clientWindow;

// Event handling (returns YES if event was handled by our titlebar)
+ (BOOL)handleExposeEvent:(xcb_expose_event_t*)event;
+ (BOOL)handleButtonEvent:(xcb_button_press_event_t*)event;

@end
