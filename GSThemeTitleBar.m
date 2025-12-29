//
//  GSThemeTitleBar.m
//  uroswm - GSTheme-based TitleBar Replacement
//
//  Implementation of GSTheme-based titlebar that completely replaces
//  XCBTitleBar's Cairo rendering with authentic AppKit decorations.
//

#import "GSThemeTitleBar.h"

@implementation GSThemeTitleBar

#pragma mark - XCBTitleBar Method Overrides

- (void)drawTitleBarForColor:(TitleBarColor)aColor {
    NSLog(@"GSThemeTitleBar: drawTitleBarForColor called - using GSTheme");

    BOOL isActive = (aColor == TitleBarUpColor);
    [self renderWithGSTheme:isActive];
}

- (void)drawArcsForColor:(TitleBarColor)aColor {
    NSLog(@"GSThemeTitleBar: drawArcsForColor called - using GSTheme");

    BOOL isActive = (aColor == TitleBarUpColor);
    [self renderWithGSTheme:isActive];
}

- (void)drawTitleBarComponents {
    NSLog(@"GSThemeTitleBar: drawTitleBarComponents called - using GSTheme");

    [self renderWithGSTheme:YES]; // Default to active
}

- (void)drawTitleBarComponentsPixmaps {
    NSLog(@"GSThemeTitleBar: drawTitleBarComponentsPixmaps called - using GSTheme");

    [self renderWithGSTheme:YES]; // Default to active
}

#pragma mark - GSTheme Rendering Implementation

- (void)renderWithGSTheme:(BOOL)isActive {
    @try {
        GSTheme *theme = [self currentTheme];
        if (!theme) {
            NSLog(@"GSThemeTitleBar: No theme available, skipping rendering");
            return;
        }

        // Get titlebar dimensions
        XCBRect titlebarRect = [self windowRect];
        NSSize titlebarSize = NSMakeSize(titlebarRect.size.width, titlebarRect.size.height);

        NSLog(@"GSThemeTitleBar: Rendering %dx%d titlebar with GSTheme",
              (int)titlebarSize.width, (int)titlebarSize.height);

        // Create GSTheme image
        NSImage *titlebarImage = [self createGSThemeImage:titlebarSize
                                                    title:[self windowTitle]
                                                   active:isActive];

        if (titlebarImage) {
            // Transfer GSTheme image to X11 pixmap
            [self transferGSThemeImageToPixmap:titlebarImage];
            NSLog(@"GSThemeTitleBar: Successfully rendered with GSTheme");
        } else {
            NSLog(@"GSThemeTitleBar: Failed to create GSTheme image");
        }

    } @catch (NSException *exception) {
        NSLog(@"GSThemeTitleBar: Exception during rendering: %@", exception.reason);
    }
}

- (NSImage*)createGSThemeImage:(NSSize)size title:(NSString*)title active:(BOOL)isActive {
    GSTheme *theme = [self currentTheme];
    if (!theme) {
        return nil;
    }

    // Create NSImage for GSTheme rendering
    NSImage *image = [[NSImage alloc] initWithSize:size];

    [image lockFocus];

    // Clear background
    [[NSColor clearColor] set];
    NSRectFill(NSMakeRect(0, 0, size.width, size.height));

    // Use GSTheme to draw window titlebar
    NSRect drawRect = NSMakeRect(0, 0, size.width, size.height);
    NSUInteger styleMask = [self windowStyleMask];
    GSThemeControlState state = [self themeStateForActive:isActive];

    [theme drawWindowBorder:drawRect
                  withFrame:drawRect
               forStyleMask:styleMask
                      state:state
                   andTitle:title ?: @""];

    // Add properly positioned buttons using Eau theme specifications
    // Based on Eau theme analysis: 17px spacing, LEFT-aligned (miniaturize first, then close)
    float buttonSize = 13.0;
    float buttonSpacing = 17.0;  // Eau theme uses 17px spacing per button
    float topMargin = 6.0;        // Center vertically in 24px titlebar
    float leftMargin = 2.0;       // Small margin from left edge

    if (styleMask & NSMiniaturizableWindowMask) {
        NSButton *miniButton = [theme standardWindowButton:NSWindowMiniaturizeButton forStyleMask:styleMask];
        if (miniButton && [miniButton image]) {
            // Eau positions miniaturize button at LEFT edge (causes title to move right by 17px)
            NSRect miniFrame = NSMakeRect(
                leftMargin,  // At left edge
                topMargin,
                buttonSize,
                buttonSize
            );
            [[miniButton image] drawInRect:miniFrame
                                  fromRect:NSZeroRect
                                 operation:NSCompositeSourceOver
                                  fraction:1.0];
        }
    }

    if (styleMask & NSClosableWindowMask) {
        NSButton *closeButton = [theme standardWindowButton:NSWindowCloseButton forStyleMask:styleMask];
        if (closeButton && [closeButton image]) {
            // Position close button next to miniaturize button (causes title width to reduce by 17px)
            NSRect closeFrame = NSMakeRect(
                leftMargin + buttonSpacing,  // 17px from left edge (after miniaturize)
                topMargin,
                buttonSize,
                buttonSize
            );
            [[closeButton image] drawInRect:closeFrame
                                   fromRect:NSZeroRect
                                  operation:NSCompositeSourceOver
                                   fraction:1.0];
        }
    }

    if (styleMask & NSResizableWindowMask) {
        NSButton *zoomButton = [theme standardWindowButton:NSWindowZoomButton forStyleMask:styleMask];
        if (zoomButton && [zoomButton image]) {
            // Position zoom button after close button
            NSRect zoomFrame = NSMakeRect(
                leftMargin + (2 * buttonSpacing),  // 34px from left edge
                topMargin,
                buttonSize,
                buttonSize
            );
            [[zoomButton image] drawInRect:zoomFrame
                                  fromRect:NSZeroRect
                                 operation:NSCompositeSourceOver
                                  fraction:1.0];
        }
    }

    [image unlockFocus];

    NSLog(@"GSThemeTitleBar: Created GSTheme image for title: %@", title ?: @"(untitled)");
    return image;
}

- (void)transferGSThemeImageToPixmap:(NSImage*)image {
    // Convert NSImage to bitmap representation
    NSBitmapImageRep *bitmap = nil;
    for (NSImageRep *rep in [image representations]) {
        if ([rep isKindOfClass:[NSBitmapImageRep class]]) {
            bitmap = (NSBitmapImageRep*)rep;
            break;
        }
    }

    if (!bitmap) {
        NSData *imageData = [image TIFFRepresentation];
        bitmap = [NSBitmapImageRep imageRepWithData:imageData];
    }

    if (!bitmap) {
        NSLog(@"GSThemeTitleBar: Failed to create bitmap from GSTheme image");
        return;
    }

    // Use direct XCB pixmap operations instead of Cairo
    BOOL success = [XCBConnection copyBitmapToPixmap:bitmap
                                            toPixmap:[self pixmap]
                                          connection:[[self connection] connection]
                                              window:self.window
                                              visual:[[self visual] visualType]];
    
    if (!success) {
        NSLog(@"GSThemeTitleBar: Failed to copy bitmap to pixmap");
        return;
    }

    // Flush connection
    [[self connection] flush];
    xcb_flush([[self connection] connection]);

    NSLog(@"GSThemeTitleBar: Successfully transferred GSTheme image to X11 pixmap");
}

#pragma mark - Helper Methods

- (GSTheme*)currentTheme {
    return [GSTheme theme];
}

- (NSUInteger)windowStyleMask {
    return NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask;
}

- (GSThemeControlState)themeStateForActive:(BOOL)isActive {
    return isActive ? GSThemeNormalState : GSThemeSelectedState;
}

#pragma mark - Button Hit Detection

- (GSThemeTitleBarButton)buttonAtPoint:(NSPoint)point {
    // Button layout constants (must match createGSThemeImage:)
    float buttonSize = 13.0;
    float buttonSpacing = 17.0;
    float topMargin = 6.0;
    float leftMargin = 2.0;

    NSUInteger styleMask = [self windowStyleMask];

    // Define button rects (order: miniaturize, close, zoom)
    NSRect miniaturizeRect = NSMakeRect(leftMargin, topMargin, buttonSize, buttonSize);
    NSRect closeRect = NSMakeRect(leftMargin + buttonSpacing, topMargin, buttonSize, buttonSize);
    NSRect zoomRect = NSMakeRect(leftMargin + (2 * buttonSpacing), topMargin, buttonSize, buttonSize);

    // Check which button was clicked (if any)
    if ((styleMask & NSMiniaturizableWindowMask) && NSPointInRect(point, miniaturizeRect)) {
        return GSThemeTitleBarButtonMiniaturize;
    }
    if ((styleMask & NSClosableWindowMask) && NSPointInRect(point, closeRect)) {
        return GSThemeTitleBarButtonClose;
    }
    if ((styleMask & NSResizableWindowMask) && NSPointInRect(point, zoomRect)) {
        return GSThemeTitleBarButtonZoom;
    }

    return GSThemeTitleBarButtonNone;
}

@end