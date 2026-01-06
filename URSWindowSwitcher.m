//
//  URSWindowSwitcher.m
//  uroswm - Alt-Tab Window Switching
//
//  Created for implementing Alt-Tab and Shift-Alt-Tab functionality
//
//  Manages window cycling and focus switching for keyboard navigation
//

#import "URSWindowSwitcher.h"
#import <XCBKit/XCBTitleBar.h>
#import <XCBKit/XCBScreen.h>
#import <xcb/xcb.h>

@implementation URSWindowSwitcher

@synthesize connection;
@synthesize windowStack;
@synthesize currentIndex;
@synthesize isSwitching;
@synthesize previousFocus;

#pragma mark - Singleton

+ (instancetype)sharedSwitcherWithConnection:(XCBConnection *)conn {
    static URSWindowSwitcher *sharedSwitcher = nil;
    @synchronized(self) {
        if (!sharedSwitcher) {
            sharedSwitcher = [[URSWindowSwitcher alloc] initWithConnection:conn];
        }
    }
    return sharedSwitcher;
}

- (instancetype)initWithConnection:(XCBConnection *)conn {
    self = [super init];
    if (self) {
        self.connection = conn;
        self.windowStack = [NSMutableArray array];
        self.currentIndex = -1;
        self.isSwitching = NO;
        self.previousFocus = nil;
        
        // Initial window stack update
        [self updateWindowStack];
    }
    return self;
}

#pragma mark - Window Stack Management

- (void)updateWindowStack {
    @try {
        NSMutableArray *newStack = [NSMutableArray array];
        NSDictionary *windowsMap = [self.connection windowsMap];
        
        // Collect all managed frames (windows with titlebars)
        for (NSString *windowId in windowsMap) {
            XCBWindow *window = [windowsMap objectForKey:windowId];
            
            if (window && [window isKindOfClass:[XCBFrame class]]) {
                XCBFrame *frame = (XCBFrame *)window;
                
                // Check if the frame has a titlebar (managed window)
                XCBWindow *titlebarWindow = [frame childWindowForKey:TitleBar];
                if (titlebarWindow && [titlebarWindow isKindOfClass:[XCBTitleBar class]]) {
                    // Only include mapped windows (not marked for destruction)
                    if (!frame.needDestroy) {
                        [newStack addObject:frame];
                    }
                }
            }
        }
        
        // Sort by most recently focused (we'll maintain this order as windows gain focus)
        // For now, just use the current order
        self.windowStack = newStack;
        
        NSLog(@"[WindowSwitcher] Updated window stack with %lu windows", (unsigned long)[newStack count]);
        
    } @catch (NSException *exception) {
        NSLog(@"[WindowSwitcher] Exception updating window stack: %@", exception.reason);
    }
}

- (void)addWindowToStack:(XCBFrame *)frame {
    if (!frame || [self.windowStack containsObject:frame]) {
        return;
    }
    
    // Add to front of stack (most recent)
    [self.windowStack insertObject:frame atIndex:0];
    NSLog(@"[WindowSwitcher] Added window to stack, total: %lu", (unsigned long)[self.windowStack count]);
}

- (void)removeWindowFromStack:(XCBFrame *)frame {
    if (!frame) {
        return;
    }
    
    [self.windowStack removeObject:frame];
    NSLog(@"[WindowSwitcher] Removed window from stack, total: %lu", (unsigned long)[self.windowStack count]);
}

- (void)bringWindowToFront:(XCBFrame *)frame {
    if (!frame) {
        return;
    }
    
    // Remove from current position and add to front
    [self.windowStack removeObject:frame];
    [self.windowStack insertObject:frame atIndex:0];
    NSLog(@"[WindowSwitcher] Brought window to front of stack");
}

#pragma mark - Switching Operations

- (void)startSwitching {
    NSLog(@"[WindowSwitcher] Starting window switching");
    
    // Update the window stack to get current state
    [self updateWindowStack];
    
    if ([self.windowStack count] < 2) {
        NSLog(@"[WindowSwitcher] Not enough windows to switch (count: %lu)", (unsigned long)[self.windowStack count]);
        return;
    }
    
    // Save the currently focused window
    self.previousFocus = [self getCurrentFocusedWindow];
    
    // Start at position 0 (current window)
    self.currentIndex = 0;
    self.isSwitching = YES;
    
    // Move to the next window immediately
    [self cycleForward];
}

- (void)cycleForward {
    if (!self.isSwitching) {
        [self startSwitching];
        return;
    }
    
    if ([self.windowStack count] == 0) {
        NSLog(@"[WindowSwitcher] No windows to cycle through");
        return;
    }
    
    // Move to next window in stack
    self.currentIndex = (self.currentIndex + 1) % [self.windowStack count];
    
    XCBFrame *targetFrame = [self.windowStack objectAtIndex:self.currentIndex];
    NSLog(@"[WindowSwitcher] Cycling forward to index %ld", (long)self.currentIndex);
    
    // Raise and focus the window
    [self focusWindow:targetFrame];
}

- (void)cycleBackward {
    if (!self.isSwitching) {
        [self startSwitching];
        return;
    }
    
    if ([self.windowStack count] == 0) {
        NSLog(@"[WindowSwitcher] No windows to cycle through");
        return;
    }
    
    // Move to previous window in stack (wrap around)
    self.currentIndex = (self.currentIndex - 1 + [self.windowStack count]) % [self.windowStack count];
    
    XCBFrame *targetFrame = [self.windowStack objectAtIndex:self.currentIndex];
    NSLog(@"[WindowSwitcher] Cycling backward to index %ld", (long)self.currentIndex);
    
    // Raise and focus the window
    [self focusWindow:targetFrame];
}

- (void)completeSwitching {
    if (!self.isSwitching) {
        return;
    }
    
    NSLog(@"[WindowSwitcher] Completing window switch");
    
    // Get the final selected window
    if (self.currentIndex >= 0 && self.currentIndex < [self.windowStack count]) {
        XCBFrame *selectedFrame = [self.windowStack objectAtIndex:self.currentIndex];
        
        // Move it to the front of the stack (most recently used)
        [self bringWindowToFront:selectedFrame];
        
        // Ensure it has focus
        [self focusWindow:selectedFrame];
    }
    
    // Reset switching state
    self.isSwitching = NO;
    self.currentIndex = -1;
    self.previousFocus = nil;
}

- (void)cancelSwitching {
    if (!self.isSwitching) {
        return;
    }
    
    NSLog(@"[WindowSwitcher] Cancelling window switch");
    
    // Return focus to the original window
    if (self.previousFocus) {
        [self focusWindow:self.previousFocus];
    }
    
    // Reset switching state
    self.isSwitching = NO;
    self.currentIndex = -1;
    self.previousFocus = nil;
}

#pragma mark - Helper Methods

- (NSArray *)getManagedWindows {
    return [NSArray arrayWithArray:self.windowStack];
}

- (void)focusWindow:(XCBFrame *)frame {
    if (!frame) {
        NSLog(@"[WindowSwitcher] Cannot focus nil frame");
        return;
    }
    
    @try {
        // Raise the window to the top of the stack
        uint32_t values[] = { XCB_STACK_MODE_ABOVE };
        xcb_configure_window([self.connection connection],
                           [frame window],
                           XCB_CONFIG_WINDOW_STACK_MODE,
                           values);
        
        // Get the client window
        XCBWindow *clientWindow = [frame childWindowForKey:ClientWindow];
        if (clientWindow) {
            // Set input focus to the client window
            xcb_set_input_focus([self.connection connection],
                              XCB_INPUT_FOCUS_POINTER_ROOT,
                              [clientWindow window],
                              XCB_CURRENT_TIME);
            
            NSLog(@"[WindowSwitcher] Focused window: %u (client: %u)", 
                  [frame window], [clientWindow window]);
        }
        
        // Flush to apply changes
        [self.connection flush];
        
    } @catch (NSException *exception) {
        NSLog(@"[WindowSwitcher] Exception focusing window: %@", exception.reason);
    }
}

- (XCBFrame *)getCurrentFocusedWindow {
    @try {
        // Query X server for current focus
        xcb_get_input_focus_cookie_t cookie = xcb_get_input_focus([self.connection connection]);
        xcb_get_input_focus_reply_t *reply = xcb_get_input_focus_reply([self.connection connection], cookie, NULL);
        
        if (!reply) {
            return nil;
        }
        
        xcb_window_t focusedWindowId = reply->focus;
        free(reply);
        
        // Find the frame containing this window
        XCBWindow *focusedWindow = [self.connection windowForXCBId:focusedWindowId];
        
        if (focusedWindow && [focusedWindow isKindOfClass:[XCBFrame class]]) {
            return (XCBFrame *)focusedWindow;
        }
        
        // If it's a client window, find its parent frame
        if (focusedWindow && [focusedWindow parentWindow]) {
            XCBWindow *parent = [focusedWindow parentWindow];
            if ([parent isKindOfClass:[XCBFrame class]]) {
                return (XCBFrame *)parent;
            }
        }
        
        // Search through all frames to find one containing this window
        NSDictionary *windowsMap = [self.connection windowsMap];
        for (NSString *windowId in windowsMap) {
            XCBWindow *window = [windowsMap objectForKey:windowId];
            if (window && [window isKindOfClass:[XCBFrame class]]) {
                XCBFrame *frame = (XCBFrame *)window;
                XCBWindow *clientWindow = [frame childWindowForKey:ClientWindow];
                if (clientWindow && [clientWindow window] == focusedWindowId) {
                    return frame;
                }
            }
        }
        
        return nil;
        
    } @catch (NSException *exception) {
        NSLog(@"[WindowSwitcher] Exception getting focused window: %@", exception.reason);
        return nil;
    }
}

@end
