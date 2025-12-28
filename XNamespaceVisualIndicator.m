//
//  XNamespaceVisualIndicator.m
//  uroswm - XNamespace Visual Indicators
//
//  Implementation of visual namespace indicators for windows.
//

#import "XNamespaceVisualIndicator.h"
#import "XNamespaceManager.h"
#import <cairo/cairo.h>
#import <cairo/cairo-xcb.h>

@interface XNamespaceVisualIndicator ()

// Track which windows have indicators applied
@property (strong, nonatomic) NSMutableDictionary<NSNumber *, NSString *> *windowIndicators;

@end


@implementation XNamespaceVisualIndicator

static XNamespaceVisualIndicator *sharedIndicator = nil;

#pragma mark - Singleton Access

+ (instancetype)sharedIndicator {
    if (sharedIndicator == nil) {
        sharedIndicator = [[XNamespaceVisualIndicator alloc] init];
    }
    return sharedIndicator;
}

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        _windowIndicators = [[NSMutableDictionary alloc] init];
        _indicatorStyle = XNamespaceIndicatorStyleBorder;
        _borderWidth = 2.0;
        _badgeSize = 12.0;
        _showTooltips = YES;
        _animateTransitions = NO;
        
        NSLog(@"XNamespaceVisualIndicator: Initialized");
    }
    return self;
}

- (instancetype)initWithManager:(XNamespaceManager *)manager
                     connection:(XCBConnection *)connection {
    self = [self init];
    if (self) {
        _namespaceManager = manager;
        _connection = connection;
        
        NSLog(@"XNamespaceVisualIndicator: Initialized with manager and connection");
    }
    return self;
}

#pragma mark - Indicator Application

- (void)applyIndicatorToFrame:(XCBFrame *)frame {
    if (!frame || !self.namespaceManager) {
        return;
    }
    
    xcb_window_t windowId = [frame window];
    XNamespaceInfo *namespace = [self.namespaceManager namespaceForWindow:windowId];
    
    switch (self.indicatorStyle) {
        case XNamespaceIndicatorStyleBorder:
            [self applyBorderIndicator:frame withNamespace:namespace];
            break;
            
        case XNamespaceIndicatorStyleTitlebarBadge:
        case XNamespaceIndicatorStyleTitlebarStripe: {
            XCBWindow *titlebarWindow = [frame childWindowForKey:TitleBar];
            if (titlebarWindow && [titlebarWindow isKindOfClass:[XCBTitleBar class]]) {
                XCBTitleBar *titlebar = (XCBTitleBar *)titlebarWindow;
                if (self.indicatorStyle == XNamespaceIndicatorStyleTitlebarBadge) {
                    [self drawNamespaceBadgeInTitlebar:titlebar withNamespace:namespace];
                } else {
                    [self drawNamespaceStripeInTitlebar:titlebar withNamespace:namespace];
                }
            }
            break;
        }
            
        case XNamespaceIndicatorStyleOverlay:
            // Overlay style would require a separate overlay window
            // For now, fall back to border style
            [self applyBorderIndicator:frame withNamespace:namespace];
            break;
    }
    
    // Store the indicator mapping
    self.windowIndicators[@(windowId)] = namespace.namespaceId;
    
    // Apply tooltip if enabled
    if (self.showTooltips) {
        NSString *tooltip = [self tooltipTextForNamespace:namespace];
        [self setTooltip:tooltip forWindow:windowId];
    }
    
    NSLog(@"XNamespaceVisualIndicator: Applied indicator to window %u (namespace: %@)",
          windowId, namespace.namespaceId);
}

- (void)applyIndicatorToWindow:(XCBWindow *)window {
    if ([window isKindOfClass:[XCBFrame class]]) {
        [self applyIndicatorToFrame:(XCBFrame *)window];
    }
}

- (void)updateIndicatorForWindow:(xcb_window_t)windowId {
    if (!self.connection) {
        return;
    }
    
    XCBWindow *window = [self.connection windowForXCBId:windowId];
    if (window) {
        [self applyIndicatorToWindow:window];
    }
}

- (void)removeIndicatorFromWindow:(xcb_window_t)windowId {
    [self.windowIndicators removeObjectForKey:@(windowId)];
    
    // Reset border to default
    if (self.connection) {
        uint32_t defaultBorder = 0x000000; // Black
        xcb_change_window_attributes([self.connection connection],
                                     windowId,
                                     XCB_CW_BORDER_PIXEL,
                                     &defaultBorder);
        [self.connection flush];
    }
    
    NSLog(@"XNamespaceVisualIndicator: Removed indicator from window %u", windowId);
}

- (void)refreshAllIndicators {
    if (!self.connection) {
        return;
    }
    
    // Get all managed windows
    NSDictionary *windowsMap = [self.connection windowsMap];
    
    for (NSString *windowIdString in windowsMap) {
        XCBWindow *window = windowsMap[windowIdString];
        
        if ([window isKindOfClass:[XCBFrame class]]) {
            [self applyIndicatorToFrame:(XCBFrame *)window];
        }
    }
    
    NSLog(@"XNamespaceVisualIndicator: Refreshed all indicators");
}

#pragma mark - Border Indicators

- (void)applyBorderIndicator:(XCBFrame *)frame 
               withNamespace:(XNamespaceInfo *)namespace {
    if (!frame || !namespace || !self.connection) {
        return;
    }
    
    xcb_connection_t *conn = [self.connection connection];
    xcb_window_t windowId = [frame window];
    
    // Get border pixel color
    uint32_t borderPixel = [self borderPixelForNamespace:namespace];
    
    // Set border color
    xcb_change_window_attributes(conn, windowId, XCB_CW_BORDER_PIXEL, &borderPixel);
    
    // Set border width
    uint32_t borderWidth = (uint32_t)self.borderWidth;
    xcb_configure_window(conn, windowId, XCB_CONFIG_WINDOW_BORDER_WIDTH, &borderWidth);
    
    [self.connection flush];
    
    NSLog(@"XNamespaceVisualIndicator: Applied border indicator (color: 0x%06X, width: %u) to window %u",
          borderPixel, borderWidth, windowId);
}

- (uint32_t)borderPixelForNamespace:(XNamespaceInfo *)namespace {
    if (!namespace) {
        return 0x000000; // Default black
    }
    
    NSColor *color = [self.namespaceManager colorForNamespace:namespace];
    return [self pixelForColor:color];
}

#pragma mark - Titlebar Indicators

- (void)drawNamespaceBadgeInTitlebar:(XCBTitleBar *)titlebar
                       withNamespace:(XNamespaceInfo *)namespace {
    if (!titlebar || !namespace) {
        return;
    }
    
    @try {
        // Get titlebar dimensions
        XCBRect titlebarRect = [titlebar windowRect];
        
        // Create Cairo surface for drawing
        xcb_pixmap_t pixmap = [titlebar pixmap];
        if (pixmap == 0) {
            return;
        }
        
        cairo_surface_t *surface = cairo_xcb_surface_create(
            [self.connection connection],
            pixmap,
            [[titlebar visual] visualType],
            titlebarRect.size.width,
            titlebarRect.size.height
        );
        
        if (cairo_surface_status(surface) != CAIRO_STATUS_SUCCESS) {
            cairo_surface_destroy(surface);
            return;
        }
        
        cairo_t *ctx = cairo_create(surface);
        
        // Draw badge in the right side of titlebar
        NSColor *color = [self.namespaceManager colorForNamespace:namespace];
        CGFloat red, green, blue, alpha;
        [[color colorUsingColorSpaceName:NSCalibratedRGBColorSpace] 
            getRed:&red green:&green blue:&blue alpha:&alpha];
        
        double badgeX = titlebarRect.size.width - self.badgeSize - 5;
        double badgeY = (titlebarRect.size.height - self.badgeSize) / 2;
        
        // Draw circular badge
        cairo_arc(ctx, badgeX + self.badgeSize/2, badgeY + self.badgeSize/2, 
                  self.badgeSize/2, 0, 2 * M_PI);
        cairo_set_source_rgba(ctx, red, green, blue, alpha);
        cairo_fill(ctx);
        
        // Draw border around badge
        cairo_arc(ctx, badgeX + self.badgeSize/2, badgeY + self.badgeSize/2, 
                  self.badgeSize/2, 0, 2 * M_PI);
        cairo_set_source_rgba(ctx, 0, 0, 0, 0.3);
        cairo_set_line_width(ctx, 1);
        cairo_stroke(ctx);
        
        cairo_surface_flush(surface);
        cairo_destroy(ctx);
        cairo_surface_destroy(surface);
        
        [self.connection flush];
        
        NSLog(@"XNamespaceVisualIndicator: Drew badge in titlebar for namespace %@", 
              namespace.namespaceId);
        
    } @catch (NSException *exception) {
        NSLog(@"XNamespaceVisualIndicator: Exception drawing badge: %@", exception.reason);
    }
}

- (void)drawNamespaceStripeInTitlebar:(XCBTitleBar *)titlebar
                        withNamespace:(XNamespaceInfo *)namespace {
    if (!titlebar || !namespace) {
        return;
    }
    
    @try {
        // Get titlebar dimensions
        XCBRect titlebarRect = [titlebar windowRect];
        
        // Create Cairo surface for drawing
        xcb_pixmap_t pixmap = [titlebar pixmap];
        if (pixmap == 0) {
            return;
        }
        
        cairo_surface_t *surface = cairo_xcb_surface_create(
            [self.connection connection],
            pixmap,
            [[titlebar visual] visualType],
            titlebarRect.size.width,
            titlebarRect.size.height
        );
        
        if (cairo_surface_status(surface) != CAIRO_STATUS_SUCCESS) {
            cairo_surface_destroy(surface);
            return;
        }
        
        cairo_t *ctx = cairo_create(surface);
        
        // Draw colored stripe at the bottom of titlebar
        NSColor *color = [self.namespaceManager colorForNamespace:namespace];
        CGFloat red, green, blue, alpha;
        [[color colorUsingColorSpaceName:NSCalibratedRGBColorSpace] 
            getRed:&red green:&green blue:&blue alpha:&alpha];
        
        double stripeHeight = 3.0;
        
        cairo_rectangle(ctx, 0, titlebarRect.size.height - stripeHeight, 
                        titlebarRect.size.width, stripeHeight);
        cairo_set_source_rgba(ctx, red, green, blue, alpha);
        cairo_fill(ctx);
        
        cairo_surface_flush(surface);
        cairo_destroy(ctx);
        cairo_surface_destroy(surface);
        
        [self.connection flush];
        
        NSLog(@"XNamespaceVisualIndicator: Drew stripe in titlebar for namespace %@", 
              namespace.namespaceId);
        
    } @catch (NSException *exception) {
        NSLog(@"XNamespaceVisualIndicator: Exception drawing stripe: %@", exception.reason);
    }
}

#pragma mark - Tooltip Support

- (NSString *)tooltipTextForNamespace:(XNamespaceInfo *)namespace {
    if (!namespace) {
        return @"Unknown Namespace";
    }
    
    NSMutableString *tooltip = [[NSMutableString alloc] init];
    [tooltip appendFormat:@"Namespace: %@", namespace.namespaceName];
    
    if (namespace.isRoot) {
        [tooltip appendString:@" (Root)"];
    }
    
    [tooltip appendFormat:@"\nID: %@", namespace.namespaceId];
    
    NSUInteger windowCount = [namespace.windowIds count];
    [tooltip appendFormat:@"\nWindows: %lu", (unsigned long)windowCount];
    
    return tooltip;
}

- (void)setTooltip:(NSString *)tooltip forWindow:(xcb_window_t)windowId {
    // X11 tooltips are typically handled via _NET_WM_NAME or custom properties
    // For now, we store the tooltip data for potential use by the WM's tooltip system
    
    if (!tooltip || !self.connection) {
        return;
    }
    
    // Store tooltip text in a window property
    // This would be read by a tooltip handler when the mouse hovers
    xcb_connection_t *conn = [self.connection connection];
    
    // Intern the tooltip atom
    static xcb_atom_t tooltipAtom = XCB_ATOM_NONE;
    if (tooltipAtom == XCB_ATOM_NONE) {
        const char *atomName = "_XNAMESPACE_TOOLTIP";
        xcb_intern_atom_cookie_t cookie = xcb_intern_atom(conn, 0, strlen(atomName), atomName);
        xcb_intern_atom_reply_t *reply = xcb_intern_atom_reply(conn, cookie, NULL);
        if (reply) {
            tooltipAtom = reply->atom;
            free(reply);
        }
    }
    
    if (tooltipAtom != XCB_ATOM_NONE) {
        const char *tooltipStr = [tooltip UTF8String];
        xcb_change_property(conn, XCB_PROP_MODE_REPLACE, windowId,
                            tooltipAtom, XCB_ATOM_STRING, 8,
                            strlen(tooltipStr), tooltipStr);
        [self.connection flush];
    }
}

#pragma mark - Color Utilities

- (uint32_t)pixelForColor:(NSColor *)color {
    if (!color) {
        return 0x000000;
    }
    
    CGFloat red, green, blue, alpha;
    [[color colorUsingColorSpaceName:NSCalibratedRGBColorSpace] 
        getRed:&red green:&green blue:&blue alpha:&alpha];
    
    uint32_t pixel = ((uint32_t)(red * 255) << 16) | 
                     ((uint32_t)(green * 255) << 8) | 
                     (uint32_t)(blue * 255);
    
    return pixel;
}

- (NSColor *)contrastingTextColorForNamespace:(XNamespaceInfo *)namespace {
    if (!namespace) {
        return [NSColor blackColor];
    }
    
    NSColor *bgColor = [self.namespaceManager colorForNamespace:namespace];
    
    CGFloat red, green, blue, alpha;
    [[bgColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace] 
        getRed:&red green:&green blue:&blue alpha:&alpha];
    
    // Calculate luminance
    CGFloat luminance = 0.299 * red + 0.587 * green + 0.114 * blue;
    
    // Return black or white based on luminance
    return (luminance > 0.5) ? [NSColor blackColor] : [NSColor whiteColor];
}

- (NSColor *)inactiveColorForNamespace:(XNamespaceInfo *)namespace {
    if (!namespace) {
        return [NSColor grayColor];
    }
    
    NSColor *activeColor = [self.namespaceManager colorForNamespace:namespace];
    
    // Desaturate and lighten for inactive state
    CGFloat hue, saturation, brightness, alpha;
    [[activeColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace] 
        getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];
    
    // Reduce saturation and adjust brightness
    saturation *= 0.5;
    brightness = (brightness + 1.0) / 2.0; // Move toward white
    
    return [NSColor colorWithCalibratedHue:hue 
                                saturation:saturation 
                                brightness:brightness 
                                     alpha:alpha * 0.7];
}

@end
