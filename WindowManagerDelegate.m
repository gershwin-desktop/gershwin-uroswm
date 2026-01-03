//
//  URSHybridEventHandler.m
//  uroswm - Phase 1: NSApplication + NSRunLoop Integration
//
//  Created by Alessandro Sangiuliano on 22/06/20.
//  Copyright (c) 2020 Alessandro Sangiuliano. All rights reserved.
//
//  Phase 1 Enhancement: NSApplication delegate that integrates XCB event handling
//  with NSRunLoop using file descriptor monitoring (following libs-back pattern).
//

#import "WindowManagerDelegate.h"
#import "XCBWrapper.h"
#import <xcb/xcb.h>
#import <xcb/xcb_icccm.h>
#import "ThemeRenderer.h"

@implementation WindowManagerDelegate

@synthesize connection;
@synthesize selectionManagerWindow;
@synthesize xcbEventsIntegrated;
@synthesize nsRunLoopActive;
@synthesize eventCount;

#pragma mark - Initialization

- (id)init
{
    self = [super init];

    if (self == nil) {
        NSLog(@"Unable to init WindowManagerDelegate...");
        return nil;
    }

    // Initialize event tracking
    self.xcbEventsIntegrated = NO;
    self.nsRunLoopActive = NO;
    self.eventCount = 0;

    // Initialize XCB connection (same as original)
    connection = [XCBConnection sharedConnectionAsWindowManager:YES];

    return self;
}

#pragma mark - NSApplicationDelegate Methods

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    // Mark NSRunLoop as active
    self.nsRunLoopActive = YES;

    // Register as window manager (same as original)
    [self registerAsWindowManager];

    // Setup XCB event integration with NSRunLoop
    [self setupXCBEventIntegration];

}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    return NSTerminateNow;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    // Keep running even if no windows are visible (window manager behavior)
    return NO;
}

#pragma mark - Original URSEventHandler Methods (Preserved)

- (void)registerAsWindowManager
{
    XCBScreen *screen = [[connection screens] objectAtIndex:0];
    XCBVisual *visual = [[XCBVisual alloc] initWithVisualId:[screen screen]->root_visual];
    [visual setVisualTypeForScreen:screen];

    selectionManagerWindow = [connection createWindowWithDepth:[screen screen]->root_depth
                                                 withParentWindow:[screen rootWindow]
                                                    withXPosition:-1
                                                    withYPosition:-1
                                                        withWidth:1
                                                       withHeight:1
                                                 withBorrderWidth:0
                                                     withXCBClass:XCB_COPY_FROM_PARENT
                                                     withVisualId:visual
                                                    withValueMask:0
                                                    withValueList:NULL
                                                  registerWindow:YES];

    [connection registerAsWindowManager:YES screenId:0 selectionWindow:selectionManagerWindow];

    EWMHService *ewmhService = [EWMHService sharedInstanceWithConnection:connection];
    [ewmhService putPropertiesForRootWindow:[screen rootWindow] andWmWindow:selectionManagerWindow];
    [connection flush];

    // ARC handles cleanup automatically

}

#pragma mark - NSRunLoop Integration (New for Phase 1)

- (void)setupXCBEventIntegration
{

    // Get XCB file descriptor for monitoring
    int xcbFD = xcb_get_file_descriptor([connection connection]);
    if (xcbFD < 0) {
        NSLog(@"ERROR Phase 1: Failed to get XCB file descriptor");
        return;
    }

    // Follow libs-back pattern for NSRunLoop file descriptor monitoring
    NSRunLoop *currentRunLoop = [NSRunLoop currentRunLoop];

    // Add XCB file descriptor to NSRunLoop for read events
    [currentRunLoop addEvent:(void*)(uintptr_t)xcbFD
                        type:ET_RDESC
                     watcher:self
                     forMode:NSDefaultRunLoopMode];

    // Also add for NSRunLoopCommonModes to ensure events are processed
    [currentRunLoop addEvent:(void*)(uintptr_t)xcbFD
                        type:ET_RDESC
                     watcher:self
                     forMode:NSRunLoopCommonModes];

    self.xcbEventsIntegrated = YES;

    // Start monitoring for XCB events immediately
    [self performSelector:@selector(processAvailableXCBEvents)
               withObject:nil
               afterDelay:0.1];
}

#pragma mark - RunLoopEvents Protocol Implementation

- (void)receivedEvent:(void*)data
                 type:(RunLoopEventType)type
                extra:(void*)extra
              forMode:(NSString*)mode
{
    if (type == ET_RDESC) {
        // Process available XCB events (non-blocking)
        [self processAvailableXCBEvents];
    }
}

- (void)processAvailableXCBEvents
{
    xcb_generic_event_t *e;
    xcb_motion_notify_event_t *lastMotionEvent = NULL;
    BOOL needFlush = NO;
    NSUInteger eventsProcessed = 0;

    // Use xcb_poll_for_event (non-blocking) instead of xcb_wait_for_event (blocking)
    while ((e = xcb_poll_for_event([connection connection]))) {
        eventsProcessed++;

        // Handle motion event compression (same as original)
        if ((e->response_type & ~0x80) == XCB_MOTION_NOTIFY) {
            // Motion event compression: save the latest motion event
            if (lastMotionEvent) {
                free(lastMotionEvent);
            }
            lastMotionEvent = malloc(sizeof(xcb_motion_notify_event_t));
            memcpy(lastMotionEvent, e, sizeof(xcb_motion_notify_event_t));

            // Check if more events are queued - if so, skip processing this one
            xcb_generic_event_t *nextEvent = xcb_poll_for_event([connection connection]);
            if (nextEvent) {
                // There's another event queued, defer motion processing
                free(e);
                e = nextEvent;
                continue; // Process the next event instead
            } else {
                continue;
            }
        }

        [self processXCBEvent:e];

        // Check if we need to flush after this event
        if ([self eventNeedsFlush:e]) {
            needFlush = YES;
        }

        free(e);
    }

    // Clean up any remaining motion event
    if (lastMotionEvent) {
        free(lastMotionEvent);
    }

    // Batched flush: only flush when needed
    if (needFlush) {
        [connection flush];
        [connection setNeedFlush:NO];
    }

    // Update event statistics
    self.eventCount += eventsProcessed;

}

- (void)processXCBEvent:(xcb_generic_event_t*)event
{
    // Process individual XCB event (same logic as original startEventHandlerLoop)
    switch (event->response_type & ~0x80) {
        case XCB_VISIBILITY_NOTIFY: {
            xcb_visibility_notify_event_t *visibilityEvent = (xcb_visibility_notify_event_t *)event;
            [connection handleVisibilityEvent:visibilityEvent];
            break;
        }
        case XCB_EXPOSE: {
            xcb_expose_event_t *exposeEvent = (xcb_expose_event_t *)event;
            [connection handleExpose:exposeEvent];
        }
        case XCB_ENTER_NOTIFY: {
            xcb_enter_notify_event_t *enterEvent = (xcb_enter_notify_event_t *)event;
            [connection handleEnterNotify:enterEvent];
            break;
        }
        case XCB_LEAVE_NOTIFY: {
            xcb_leave_notify_event_t *leaveEvent = (xcb_leave_notify_event_t *)event;
            [connection handleLeaveNotify:leaveEvent];
            break;
        }
        case XCB_FOCUS_IN: {
            xcb_focus_in_event_t *focusInEvent = (xcb_focus_in_event_t *)event;
            NSLog(@"XCB_FOCUS_IN received for window %u", focusInEvent->event);
            [connection handleFocusIn:focusInEvent];
            break;
        }
        case XCB_FOCUS_OUT: {
            xcb_focus_out_event_t *focusOutEvent = (xcb_focus_out_event_t *)event;
            NSLog(@"XCB_FOCUS_OUT received for window %u", focusOutEvent->event);
            [connection handleFocusOut:focusOutEvent];
            break;
        }
        case XCB_BUTTON_PRESS: {
            xcb_button_press_event_t *pressEvent = (xcb_button_press_event_t *)event;
            NSLog(@"EVENT: XCB_BUTTON_PRESS received for window %u at (%d, %d)",
                  pressEvent->event, pressEvent->event_x, pressEvent->event_y);
            break;
        }
        case XCB_BUTTON_RELEASE: {
            xcb_button_release_event_t *releaseEvent = (xcb_button_release_event_t *)event;
            // Let xcbkit handle the release first
            [connection handleButtonRelease:releaseEvent];
        }
        case XCB_MAP_NOTIFY: {
            xcb_map_notify_event_t *notifyEvent = (xcb_map_notify_event_t *)event;
            [connection handleMapNotify:notifyEvent];
            break;
        }
        case XCB_MAP_REQUEST: {
            xcb_map_request_event_t *mapRequestEvent = (xcb_map_request_event_t *)event;

            // Let XCBConnection handle the map request normally (this creates titlebar structure)
            [connection handleMapRequest:mapRequestEvent];
        }
        case XCB_UNMAP_NOTIFY: {
            xcb_unmap_notify_event_t *unmapNotifyEvent = (xcb_unmap_notify_event_t *)event;
            [connection handleUnMapNotify:unmapNotifyEvent];
            break;
        }
        case XCB_DESTROY_NOTIFY: {
            xcb_destroy_notify_event_t *destroyNotify = (xcb_destroy_notify_event_t *)event;
            [connection handleDestroyNotify:destroyNotify];
            break;
        }
        case XCB_CLIENT_MESSAGE: {
            xcb_client_message_event_t *clientMessageEvent = (xcb_client_message_event_t *)event;
            [connection handleClientMessage:clientMessageEvent];
            break;
        }
        case XCB_CONFIGURE_REQUEST: {
            xcb_configure_request_event_t *configRequest = (xcb_configure_request_event_t *)event;
            [connection handleConfigureWindowRequest:configRequest];
            break;
        }
        case XCB_CONFIGURE_NOTIFY: {
            xcb_configure_notify_event_t *configureNotify = (xcb_configure_notify_event_t *)event;
            [connection handleConfigureNotify:configureNotify];
            break;
        }
        case XCB_PROPERTY_NOTIFY: {
            xcb_property_notify_event_t *propEvent = (xcb_property_notify_event_t *)event;
            [connection handlePropertyNotify:propEvent];
            break;
        }
        default:
            break;
    }
}

- (BOOL)eventNeedsFlush:(xcb_generic_event_t*)event
{
    // Determine if event requires immediate flush (same logic as original)
    switch (event->response_type & ~0x80) {
        case XCB_EXPOSE:
        case XCB_BUTTON_PRESS:
        case XCB_BUTTON_RELEASE:
        case XCB_MAP_REQUEST:
        case XCB_DESTROY_NOTIFY:
        case XCB_CLIENT_MESSAGE:
        case XCB_CONFIGURE_REQUEST:
            return YES;
        default:
            return NO;
    }
}

- (void)dealloc
{

    // Remove from run loop if integrated
    if (self.xcbEventsIntegrated && connection) {
        int xcbFD = xcb_get_file_descriptor([connection connection]);
        if (xcbFD >= 0) {
            NSRunLoop *currentRunLoop = [NSRunLoop currentRunLoop];
            [currentRunLoop removeEvent:(void*)(uintptr_t)xcbFD
                                   type:ET_RDESC
                                forMode:NSDefaultRunLoopMode
                                   all:YES];
        }
    }

    // Remove notification center observers
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    // ARC handles memory management automatically
}

@end
