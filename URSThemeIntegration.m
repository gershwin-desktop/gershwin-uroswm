//
//  URSThemeIntegration.m
//  uroswm - GSTheme Window Decoration for Titlebars
//
//  Implementation of GSTheme window decoration rendering for X11 titlebars.
//

#import "URSThemeIntegration.h"
#import <XCBKit/XCBConnection.h>
#import <XCBKit/XCBFrame.h>
#import <cairo/cairo.h>
#import <cairo/cairo-xcb.h>
#import <objc/runtime.h>
#import "GSThemeTitleBar.h"

@implementation URSThemeIntegration

static URSThemeIntegration *sharedInstance = nil;

#pragma mark - Singleton Management

+ (instancetype)sharedInstance {
    if (sharedInstance == nil) {
        sharedInstance = [[self alloc] init];
    }
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.enabled = YES;
        self.managedTitlebars = [[NSMutableArray alloc] init];
        NSLog(@"GSTheme titlebar integration initialized");
    }
    return self;
}

#pragma mark - GSTheme Management

+ (void)initializeGSTheme {
    // Load the user's current theme from system defaults
    @try {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *themeName = [defaults stringForKey:@"GSTheme"];

        NSLog(@"GSTheme user default: '%@'", themeName ?: @"(none)");

        if (themeName && [themeName length] > 0) {
            // Remove .theme extension if present
            if ([[themeName pathExtension] isEqualToString:@"theme"]) {
                themeName = [themeName stringByDeletingPathExtension];
            }

            NSLog(@"Loading user's selected theme: %@", themeName);
            GSTheme *userTheme = [GSTheme loadThemeNamed:themeName];
            if (userTheme) {
                [GSTheme setTheme:userTheme];
                NSLog(@"GSTheme loaded: %@", [userTheme name] ?: @"Unknown");
                return;
            } else {
                NSLog(@"Failed to load theme '%@', falling back to default", themeName);
            }
        } else {
            NSLog(@"No theme specified in GSTheme default, using system default");
        }

        // Fallback to whatever GSTheme gives us by default
        GSTheme *theme = [GSTheme theme];
        NSLog(@"GSTheme fallback loaded: %@", [theme name] ?: @"Default");

        // Log theme bundle info for debugging
        if (theme && [theme bundle]) {
            NSLog(@"Theme bundle path: %@", [[theme bundle] bundlePath]);
        }

    } @catch (NSException *exception) {
        NSLog(@"Failed to load GSTheme: %@", exception.reason);
    }
}

+ (GSTheme*)currentTheme {
    return [GSTheme theme];
}

+ (void)enableGSThemeTitleBars {
    NSLog(@"Enabling GSThemeTitleBar replacement for XCBTitleBar...");

    // The GSThemeTitleBar class will automatically override XCBTitleBar methods
    // when instances are created. We just need to ensure it's loaded.
    Class gsThemeClass = [GSThemeTitleBar class];
    if (gsThemeClass) {
        NSLog(@"GSThemeTitleBar class loaded successfully");
    } else {
        NSLog(@"Warning: GSThemeTitleBar class not found");
    }
}

#pragma mark - GSTheme Titlebar Rendering

+ (BOOL)renderGSThemeTitlebar:(XCBTitleBar*)titlebar
                        title:(NSString*)title
                       active:(BOOL)isActive {

    if (![[URSThemeIntegration sharedInstance] enabled] || !titlebar) {
        return NO;
    }

    GSTheme *theme = [self currentTheme];
    if (!theme) {
        NSLog(@"Warning: No GSTheme available for titlebar rendering");
        return NO;
    }

    @try {
        // Get titlebar dimensions
        XCBRect xcbRect = titlebar.windowRect;
        NSSize titlebarSize = NSMakeSize(xcbRect.size.width, xcbRect.size.height);

        // Create NSImage for GSTheme to render into
        NSImage *titlebarImage = [[NSImage alloc] initWithSize:titlebarSize];

        [titlebarImage lockFocus];

        // Clear background
        [[NSColor clearColor] set];
        NSRectFill(NSMakeRect(0, 0, titlebarSize.width, titlebarSize.height));

        // Define the titlebar rect
        NSRect titlebarRect = NSMakeRect(0, 0, titlebarSize.width, titlebarSize.height);

        // Use GSTheme to draw titlebar decoration with all button types
        NSUInteger styleMask = NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask;
        GSThemeControlState state = isActive ? GSThemeNormalState : GSThemeSelectedState;

        NSLog(@"Drawing GSTheme titlebar with styleMask: 0x%lx, state: %d", (unsigned long)styleMask, (int)state);

        // Draw the window titlebar using GSTheme
        [theme drawWindowBorder:titlebarRect
                      withFrame:titlebarRect
                   forStyleMask:styleMask
                          state:state
                       andTitle:title ?: @""];

        // Add properly positioned buttons using Rik theme specifications
        // Based on Rik theme analysis: 17px spacing, LEFT-aligned (miniaturize first, then close)
        float buttonSize = 13.0;
        float buttonSpacing = 17.0;  // Rik theme uses 17px spacing per button
        float topMargin = 6.0;        // Center vertically in 24px titlebar
        float leftMargin = 2.0;       // Small margin from left edge

        if (styleMask & NSMiniaturizableWindowMask) {
            NSButton *miniButton = [theme standardWindowButton:NSWindowMiniaturizeButton forStyleMask:styleMask];
            if (miniButton) {
                // Rik positions miniaturize button at LEFT edge (causes title to move right by 17px)
                NSRect miniFrame = NSMakeRect(
                    leftMargin,  // At left edge
                    topMargin,
                    buttonSize,
                    buttonSize
                );

                NSImage *buttonImage = [miniButton image];
                if (buttonImage) {
                    [buttonImage drawInRect:miniFrame
                                   fromRect:NSZeroRect
                                  operation:NSCompositeSourceOver
                                   fraction:1.0];
                    NSLog(@"Drew miniaturize button at Rik LEFT position: %@", NSStringFromRect(miniFrame));
                }
            }
        }

        if (styleMask & NSClosableWindowMask) {
            NSButton *closeButton = [theme standardWindowButton:NSWindowCloseButton forStyleMask:styleMask];
            if (closeButton) {
                // Position close button next to miniaturize button (causes title width to reduce by 17px)
                NSRect closeFrame = NSMakeRect(
                    leftMargin + buttonSpacing,  // 17px from left edge (after miniaturize)
                    topMargin,
                    buttonSize,
                    buttonSize
                );

                NSImage *buttonImage = [closeButton image];
                if (buttonImage) {
                    [buttonImage drawInRect:closeFrame
                                   fromRect:NSZeroRect
                                  operation:NSCompositeSourceOver
                                   fraction:1.0];
                    NSLog(@"Drew close button at Rik LEFT position: %@", NSStringFromRect(closeFrame));
                }
            }
        }

        if (styleMask & NSResizableWindowMask) {
            NSButton *zoomButton = [theme standardWindowButton:NSWindowZoomButton forStyleMask:styleMask];
            if (zoomButton) {
                // Position zoom button after close button
                NSRect zoomFrame = NSMakeRect(
                    leftMargin + (2 * buttonSpacing),  // 34px from left edge
                    topMargin,
                    buttonSize,
                    buttonSize
                );

                NSImage *buttonImage = [zoomButton image];
                if (buttonImage) {
                    [buttonImage drawInRect:zoomFrame
                                   fromRect:NSZeroRect
                                  operation:NSCompositeSourceOver
                                   fraction:1.0];
                    NSLog(@"Drew zoom button at Rik LEFT position: %@", NSStringFromRect(zoomFrame));
                }
            }
        }

        [titlebarImage unlockFocus];

        // Convert NSImage to Cairo surface and apply to titlebar
        BOOL success = [self transferImage:titlebarImage toTitlebar:titlebar];

        if (success) {
            NSLog(@"GSTheme titlebar rendered successfully for: %@", title);
        } else {
            NSLog(@"Failed to transfer GSTheme titlebar for: %@", title);
        }

        return success;

    } @catch (NSException *exception) {
        NSLog(@"GSTheme titlebar rendering failed: %@", exception.reason);
        return NO;
    }
}

#pragma mark - Image Transfer

+ (BOOL)transferImage:(NSImage*)image toTitlebar:(XCBTitleBar*)titlebar {
    // Convert NSImage to bitmap representation
    NSBitmapImageRep *bitmap = nil;
    for (NSImageRep *rep in [image representations]) {
        if ([rep isKindOfClass:[NSBitmapImageRep class]]) {
            bitmap = (NSBitmapImageRep*)rep;
            break;
        }
    }

    if (!bitmap) {
        // Create bitmap from image data
        NSData *imageData = [image TIFFRepresentation];
        bitmap = [NSBitmapImageRep imageRepWithData:imageData];
    }

    if (!bitmap) {
        NSLog(@"Failed to create bitmap from NSImage for titlebar transfer");
        return NO;
    }

    NSLog(@"Creating Cairo surface for titlebar pixmap: %u, size: %dx%d",
          titlebar.pixmap, (int)image.size.width, (int)image.size.height);

    // Create Cairo surface from XCB titlebar pixmap
    cairo_surface_t *x11Surface = cairo_xcb_surface_create(
        [titlebar.connection connection],
        titlebar.pixmap,
        titlebar.visual.visualType,
        (int)image.size.width,
        (int)image.size.height
    );

    cairo_status_t surface_status = cairo_surface_status(x11Surface);
    if (surface_status != CAIRO_STATUS_SUCCESS) {
        NSLog(@"Failed to create Cairo X11 surface for titlebar: %s", cairo_status_to_string(surface_status));
        cairo_surface_destroy(x11Surface);
        return NO;
    }

    NSLog(@"Cairo X11 surface created successfully");

    cairo_t *ctx = cairo_create(x11Surface);

    // Create Cairo image surface from bitmap data
    cairo_surface_t *imageSurface = cairo_image_surface_create_for_data(
        [bitmap bitmapData],
        CAIRO_FORMAT_ARGB32,
        [bitmap pixelsWide],
        [bitmap pixelsHigh],
        [bitmap bytesPerRow]
    );

    if (cairo_surface_status(imageSurface) != CAIRO_STATUS_SUCCESS) {
        NSLog(@"Failed to create Cairo image surface for titlebar transfer");
        cairo_surface_destroy(imageSurface);
        cairo_destroy(ctx);
        cairo_surface_destroy(x11Surface);
        return NO;
    }

    NSLog(@"Painting GSTheme image to X11 surface...");

    // Clear and paint GSTheme image to X11 surface
    cairo_set_operator(ctx, CAIRO_OPERATOR_CLEAR);
    cairo_paint(ctx);
    cairo_set_operator(ctx, CAIRO_OPERATOR_OVER);
    cairo_set_source_surface(ctx, imageSurface, 0, 0);
    cairo_paint(ctx);
    cairo_surface_flush(x11Surface);

    // Force immediate X11 update to ensure GSTheme is visible
    [titlebar.connection flush];
    xcb_flush([titlebar.connection connection]);

    NSLog(@"GSTheme image painted and surface flushed");

    // Cleanup
    cairo_surface_destroy(imageSurface);
    cairo_destroy(ctx);
    cairo_surface_destroy(x11Surface);
    [titlebar.connection flush];

    return YES;
}

#pragma mark - GSTheme Method Swizzling Implementations

// These methods replace XCBTitleBar's drawing methods
- (void)gstheme_drawTitleBarComponentsPixmaps {
    // Replace XCBTitleBar's Cairo drawing with GSTheme
    NSLog(@"GSTheme: Replacing drawTitleBarComponentsPixmaps with GSTheme rendering");

    XCBTitleBar *titlebar = (XCBTitleBar*)self;
    [URSThemeIntegration renderGSThemeTitlebar:titlebar
                                         title:titlebar.windowTitle
                                        active:YES];
}

- (void)gstheme_drawTitleBarComponents {
    // Replace XCBTitleBar's Cairo drawing with GSTheme
    NSLog(@"GSTheme: Replacing drawTitleBarComponents with GSTheme rendering");

    XCBTitleBar *titlebar = (XCBTitleBar*)self;
    [URSThemeIntegration renderGSThemeTitlebar:titlebar
                                         title:titlebar.windowTitle
                                        active:YES];
}

- (void)gstheme_drawTitleBarForColor:(TitleBarColor)aColor {
    // Replace XCBTitleBar's Cairo drawing with GSTheme
    NSLog(@"GSTheme: Replacing drawTitleBarForColor: with GSTheme rendering");

    XCBTitleBar *titlebar = (XCBTitleBar*)self;
    BOOL isActive = (aColor == TitleBarUpColor);
    [URSThemeIntegration renderGSThemeTitlebar:titlebar
                                         title:titlebar.windowTitle
                                        active:isActive];
}

+ (BOOL)renderGSThemeToWindow:(XCBWindow*)window
                        frame:(XCBFrame*)frame
                        title:(NSString*)title
                       active:(BOOL)isActive {

    if (![[URSThemeIntegration sharedInstance] enabled] || !window || !frame) {
        return NO;
    }

    GSTheme *theme = [self currentTheme];
    if (!theme) {
        NSLog(@"Warning: No GSTheme available for standalone titlebar rendering");
        return NO;
    }

    @try {
        // Get the frame's titlebar area
        XCBWindow *titlebarWindow = [frame childWindowForKey:TitleBar];
        if (!titlebarWindow || ![titlebarWindow isKindOfClass:[XCBTitleBar class]]) {
            NSLog(@"Warning: No titlebar found in frame for GSTheme rendering");
            return NO;
        }
        XCBTitleBar *titlebar = (XCBTitleBar*)titlebarWindow;

        // Get titlebar dimensions
        XCBRect titlebarRect = [titlebar windowRect];
        NSSize titlebarSize = NSMakeSize(titlebarRect.size.width, titlebarRect.size.height);

        NSLog(@"Rendering standalone GSTheme titlebar: %dx%d for window %u",
              (int)titlebarSize.width, (int)titlebarSize.height, [window window]);

        // Create NSImage for GSTheme to render into
        NSImage *titlebarImage = [[NSImage alloc] initWithSize:titlebarSize];

        [titlebarImage lockFocus];

        // Clear background
        [[NSColor clearColor] set];
        NSRectFill(NSMakeRect(0, 0, titlebarSize.width, titlebarSize.height));

        // Use GSTheme to draw titlebar decoration with all button types
        NSRect drawRect = NSMakeRect(0, 0, titlebarSize.width, titlebarSize.height);
        NSUInteger styleMask = NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask;
        GSThemeControlState state = isActive ? GSThemeNormalState : GSThemeSelectedState;

        NSLog(@"Drawing standalone GSTheme titlebar with styleMask: 0x%lx, state: %d", (unsigned long)styleMask, (int)state);

        // Log GSTheme padding and size values to verify Rik theme values
        if ([theme respondsToSelector:@selector(titlebarPaddingLeft)]) {
            NSLog(@"GSTheme titlebarPaddingLeft: %.1f", [theme titlebarPaddingLeft]);
        }
        if ([theme respondsToSelector:@selector(titlebarPaddingRight)]) {
            NSLog(@"GSTheme titlebarPaddingRight: %.1f", [theme titlebarPaddingRight]);
        }
        if ([theme respondsToSelector:@selector(titlebarPaddingTop)]) {
            NSLog(@"GSTheme titlebarPaddingTop: %.1f", [theme titlebarPaddingTop]);
        }
        if ([theme respondsToSelector:@selector(titlebarButtonSize)]) {
            NSLog(@"GSTheme titlebarButtonSize: %.1f", [theme titlebarButtonSize]);
        }
        NSLog(@"Expected Rik values: paddingLeft=2, paddingRight=2, paddingTop=6, buttonSize=13");

        // Draw the window titlebar using GSTheme
        [theme drawWindowBorder:drawRect
                      withFrame:drawRect
                   forStyleMask:styleMask
                          state:state
                       andTitle:title ?: @""];

        // Add properly positioned and styled buttons using direct theme image loading
        // Use manual Rik positioning since GSTheme methods return generic values
        NSLog(@"Standalone: Theme name: %@, class: %@", [theme name], [theme class]);

        BOOL isRikTheme = [[theme name] isEqualToString:@"Rik"];
        NSLog(@"Using %@ positioning for buttons", isRikTheme ? @"authentic Rik" : @"automatic GSTheme");

        // COMPARISON: Log what the actual Rik theme positioning methods return
        if (isRikTheme) {
            NSRect actualCloseFrame = [theme closeButtonFrameForBounds:drawRect];
            NSRect actualMiniFrame = [theme miniaturizeButtonFrameForBounds:drawRect];
            NSLog(@"COMPARISON - Actual Rik closeButtonFrame: %@", NSStringFromRect(actualCloseFrame));
            NSLog(@"COMPARISON - Actual Rik miniaturizeButtonFrame: %@", NSStringFromRect(actualMiniFrame));
        }

        if (styleMask & NSClosableWindowMask) {
            NSRect closeFrame;
            if (isRikTheme) {
                // Authentic Rik positioning from GSStandardDecorationView+Rik.m
                #define RIK_TITLEBAR_BUTTON_SIZE 15
                #define RIK_TITLEBAR_PADDING_LEFT 10.5
                #define RIK_TITLEBAR_PADDING_TOP 5.5

                closeFrame = NSMakeRect(
                    RIK_TITLEBAR_PADDING_LEFT,
                    drawRect.size.height - RIK_TITLEBAR_BUTTON_SIZE - RIK_TITLEBAR_PADDING_TOP,
                    RIK_TITLEBAR_BUTTON_SIZE, RIK_TITLEBAR_BUTTON_SIZE);
                NSLog(@"Standalone: Our Rik closeFrame: %@", NSStringFromRect(closeFrame));
                NSLog(@"COMPARISON - Using constants: left=%.1f, top=%.1f, size=%.1f",
                      RIK_TITLEBAR_PADDING_LEFT, RIK_TITLEBAR_PADDING_TOP, (float)RIK_TITLEBAR_BUTTON_SIZE);
            } else {
                closeFrame = [theme closeButtonFrameForBounds:drawRect];
                NSLog(@"Standalone: GSTheme closeButtonFrameForBounds returned: %@", NSStringFromRect(closeFrame));
            }

            // Load Rik theme specific button images
            NSImage *closeImage = nil;
            NSBundle *themeBundle = [theme bundle];

            if (themeBundle) {
                NSString *bundlePath = [themeBundle bundlePath];
                NSLog(@"Standalone: Rik theme bundle path: %@", bundlePath);

                // Try Rik-specific close button images
                NSArray *closeImageNames = @[@"CloseButton", @"close", @"Close", @"common_Close"];
                NSArray *imageExtensions = @[@"png", @"tiff", @"jpg", @"gif"];

                for (NSString *imageName in closeImageNames) {
                    for (NSString *ext in imageExtensions) {
                        NSString *imagePath = [themeBundle pathForResource:imageName ofType:ext];
                        if (imagePath) {
                            closeImage = [[NSImage alloc] initWithContentsOfFile:imagePath];
                            if (closeImage) {
                                NSLog(@"Standalone: Found Rik close button: %@", imagePath);
                                break;
                            }
                        }
                    }
                    if (closeImage) break;
                }
            }

            // Fallback to system image if no Rik-specific image found
            if (!closeImage) {
                closeImage = [NSImage imageNamed:@"common_Close"];
                NSLog(@"Standalone: Using fallback common_Close image");
            }

            NSLog(@"Standalone: Close button image: %@ (from %@)", closeImage, closeImage ? @"loaded" : @"failed to load");

            // Debug: Save the close button image to see what it looks like
            if (closeImage) {
                NSData *imageData = [closeImage TIFFRepresentation];
                if (imageData) {
                    [imageData writeToFile:@"/tmp/close_button_debug.tiff" atomically:YES];
                    NSLog(@"Saved close button image to /tmp/close_button_debug.tiff");
                }
            }

            if (closeImage) {
                // Add authentic Rik button background - make it exactly image size (12x13)
                // Center a 12x12 ball within the 15x15 frame to exactly match image width
                NSRect ballFrame = NSMakeRect(
                    closeFrame.origin.x + 1.5,
                    closeFrame.origin.y + 1.5,
                    12.0, 12.0);
                NSLog(@"Standalone: Close ballFrame (13x13 centered): %@", NSStringFromRect(ballFrame));

                [[NSColor colorWithCalibratedRed:0.9 green:0.9 blue:0.9 alpha:1.0] set];
                NSBezierPath *ovalPath = [NSBezierPath bezierPathWithOvalInRect:ballFrame];
                [ovalPath fill];

                // Add a border
                [[NSColor darkGrayColor] set];
                [ovalPath stroke];

                // Draw the 12x13 image centered in the 15x15 frame
                NSRect imageRect = NSMakeRect(
                    closeFrame.origin.x + (closeFrame.size.width - closeImage.size.width) / 2,
                    closeFrame.origin.y + (closeFrame.size.height - closeImage.size.height) / 2,
                    closeImage.size.width, closeImage.size.height);
                NSLog(@"Standalone: Close imageRect (centered %gx%g in %gx%g): %@",
                      closeImage.size.width, closeImage.size.height,
                      closeFrame.size.width, closeFrame.size.height,
                      NSStringFromRect(imageRect));

                [closeImage drawInRect:imageRect
                               fromRect:NSZeroRect
                              operation:NSCompositeSourceOver
                               fraction:1.0];
                NSLog(@"Standalone: Drew close button image with circular background at frame: %@", NSStringFromRect(closeFrame));
            } else {
                // Draw a simple close 'X' if no image available
                [[NSColor blackColor] set];
                NSBezierPath *xPath = [NSBezierPath bezierPath];
                [xPath moveToPoint:NSMakePoint(closeFrame.origin.x + 2, closeFrame.origin.y + 2)];
                [xPath lineToPoint:NSMakePoint(closeFrame.origin.x + closeFrame.size.width - 2, closeFrame.origin.y + closeFrame.size.height - 2)];
                [xPath moveToPoint:NSMakePoint(closeFrame.origin.x + closeFrame.size.width - 2, closeFrame.origin.y + 2)];
                [xPath lineToPoint:NSMakePoint(closeFrame.origin.x + 2, closeFrame.origin.y + closeFrame.size.height - 2)];
                [xPath setLineWidth:2.0];
                [xPath stroke];
                NSLog(@"Standalone: Drew fallback close 'X' at frame: %@", NSStringFromRect(closeFrame));
            }
        }

        if (styleMask & NSMiniaturizableWindowMask) {
            NSRect miniFrame;
            if (isRikTheme) {
                // Authentic Rik positioning: miniaturize button after close button with 4px spacing
                miniFrame = NSMakeRect(
                    RIK_TITLEBAR_PADDING_LEFT + RIK_TITLEBAR_BUTTON_SIZE + 4, // 4px padding between buttons
                    drawRect.size.height - RIK_TITLEBAR_BUTTON_SIZE - RIK_TITLEBAR_PADDING_TOP,
                    RIK_TITLEBAR_BUTTON_SIZE, RIK_TITLEBAR_BUTTON_SIZE);
                NSLog(@"Standalone: Our Rik miniFrame: %@", NSStringFromRect(miniFrame));
                NSLog(@"COMPARISON - Mini calc: x=%.1f+%.1f+4=%.1f, y=%.1f-%.1f-%.1f=%.1f",
                      RIK_TITLEBAR_PADDING_LEFT, (float)RIK_TITLEBAR_BUTTON_SIZE,
                      RIK_TITLEBAR_PADDING_LEFT + RIK_TITLEBAR_BUTTON_SIZE + 4,
                      drawRect.size.height, (float)RIK_TITLEBAR_BUTTON_SIZE, RIK_TITLEBAR_PADDING_TOP,
                      drawRect.size.height - RIK_TITLEBAR_BUTTON_SIZE - RIK_TITLEBAR_PADDING_TOP);
            } else {
                miniFrame = [theme miniaturizeButtonFrameForBounds:drawRect];
                NSLog(@"Standalone: GSTheme miniaturizeButtonFrameForBounds returned: %@", NSStringFromRect(miniFrame));
            }

            // Load Rik theme specific miniaturize button images
            NSImage *miniImage = nil;
            NSBundle *themeBundle = [theme bundle];

            if (themeBundle) {
                // Try Rik-specific miniaturize button images
                NSArray *miniImageNames = @[@"MiniaturizeButton", @"minimize", @"Minimize", @"common_Miniaturize"];
                NSArray *imageExtensions = @[@"png", @"tiff", @"jpg", @"gif"];

                for (NSString *imageName in miniImageNames) {
                    for (NSString *ext in imageExtensions) {
                        NSString *imagePath = [themeBundle pathForResource:imageName ofType:ext];
                        if (imagePath) {
                            miniImage = [[NSImage alloc] initWithContentsOfFile:imagePath];
                            if (miniImage) {
                                NSLog(@"Standalone: Found Rik miniaturize button: %@", imagePath);
                                break;
                            }
                        }
                    }
                    if (miniImage) break;
                }
            }

            // Fallback to system image if no Rik-specific image found
            if (!miniImage) {
                miniImage = [NSImage imageNamed:@"common_Miniaturize"];
                NSLog(@"Standalone: Using fallback common_Miniaturize image");
            }

            NSLog(@"Standalone: Miniaturize button image: %@ (from %@)", miniImage, miniImage ? @"loaded" : @"failed to load");

            // Debug: Save the miniaturize button image to see what it looks like
            if (miniImage) {
                NSData *imageData = [miniImage TIFFRepresentation];
                if (imageData) {
                    [imageData writeToFile:@"/tmp/miniaturize_button_debug.tiff" atomically:YES];
                    NSLog(@"Saved miniaturize button image to /tmp/miniaturize_button_debug.tiff");
                }
            }

            if (miniImage) {
                // Add authentic Rik button background - make it exactly image size (12x13)
                // Center a 12x12 ball within the 15x15 frame to exactly match image width
                NSRect ballFrame = NSMakeRect(
                    miniFrame.origin.x + 1.5,
                    miniFrame.origin.y + 1.5,
                    12.0, 12.0);
                NSLog(@"Standalone: Mini ballFrame (13x13 centered): %@", NSStringFromRect(ballFrame));

                [[NSColor colorWithCalibratedRed:0.9 green:0.9 blue:0.9 alpha:1.0] set];
                NSBezierPath *ovalPath = [NSBezierPath bezierPathWithOvalInRect:ballFrame];
                [ovalPath fill];

                // Add a border
                [[NSColor darkGrayColor] set];
                [ovalPath stroke];

                // Draw the 12x13 image centered in the 15x15 frame
                NSRect imageRect = NSMakeRect(
                    miniFrame.origin.x + (miniFrame.size.width - miniImage.size.width) / 2,
                    miniFrame.origin.y + (miniFrame.size.height - miniImage.size.height) / 2,
                    miniImage.size.width, miniImage.size.height);
                NSLog(@"Standalone: Mini imageRect (centered %gx%g in %gx%g): %@",
                      miniImage.size.width, miniImage.size.height,
                      miniFrame.size.width, miniFrame.size.height,
                      NSStringFromRect(imageRect));

                [miniImage drawInRect:imageRect
                              fromRect:NSZeroRect
                             operation:NSCompositeSourceOver
                             fraction:1.0];
                NSLog(@"Standalone: Drew miniaturize button image with circular background at frame: %@", NSStringFromRect(miniFrame));
            } else {
                // Draw a simple minimize line if no image available
                [[NSColor blackColor] set];
                NSRect lineRect = NSMakeRect(miniFrame.origin.x + 2,
                                           miniFrame.origin.y + miniFrame.size.height/2 - 1,
                                           miniFrame.size.width - 4, 2);
                NSRectFill(lineRect);
                NSLog(@"Standalone: Drew fallback minimize line at frame: %@", NSStringFromRect(miniFrame));
            }
        }

        if (styleMask & NSResizableWindowMask) {
            NSButton *zoomButton = [theme standardWindowButton:NSWindowZoomButton forStyleMask:styleMask];
            if (zoomButton) {
                NSRect zoomFrame;
                if (isRikTheme) {
                    // Authentic Rik positioning: zoom button after miniaturize button
                    zoomFrame = NSMakeRect(
                        RIK_TITLEBAR_PADDING_LEFT + (RIK_TITLEBAR_BUTTON_SIZE + 4) * 2, // After miniaturize button
                        drawRect.size.height - RIK_TITLEBAR_BUTTON_SIZE - RIK_TITLEBAR_PADDING_TOP,
                        RIK_TITLEBAR_BUTTON_SIZE, RIK_TITLEBAR_BUTTON_SIZE);
                    NSLog(@"Standalone: Authentic Rik zoomFrame: %@", NSStringFromRect(zoomFrame));
                } else {
                    // Calculate zoom button position based on miniaturize button + some spacing
                    NSRect miniFrame = [theme miniaturizeButtonFrameForBounds:drawRect];
                    float buttonSpacing = 2.0; // Small gap between buttons

                    zoomFrame = NSMakeRect(
                        miniFrame.origin.x + miniFrame.size.width + buttonSpacing,
                        miniFrame.origin.y,
                        miniFrame.size.width,
                        miniFrame.size.height
                    );
                    NSLog(@"Standalone: Calculated zoom frame based on miniaturize: %@", NSStringFromRect(zoomFrame));
                }

                NSImage *buttonImage = [zoomButton image];
                if (buttonImage) {
                    // Add authentic Rik button background - make it exactly image size
                    // Center a 12x12 ball within the 15x15 frame to exactly match image width
                    NSRect ballFrame = NSMakeRect(
                        zoomFrame.origin.x + 1.5,
                        zoomFrame.origin.y + 1.5,
                        12.0, 12.0);
                    [[NSColor colorWithCalibratedRed:0.9 green:0.9 blue:0.9 alpha:1.0] set];
                    NSBezierPath *ovalPath = [NSBezierPath bezierPathWithOvalInRect:ballFrame];
                    [ovalPath fill];

                    // Add a border
                    [[NSColor darkGrayColor] set];
                    [ovalPath stroke];

                    // Draw the image centered in the 15x15 frame (most zoom images are also 12x13)
                    NSRect imageRect = NSMakeRect(
                        zoomFrame.origin.x + (zoomFrame.size.width - buttonImage.size.width) / 2,
                        zoomFrame.origin.y + (zoomFrame.size.height - buttonImage.size.height) / 2,
                        buttonImage.size.width, buttonImage.size.height);
                    [buttonImage drawInRect:imageRect
                                   fromRect:NSZeroRect
                                  operation:NSCompositeSourceOver
                                   fraction:1.0];
                    NSLog(@"Standalone: Drew zoom button with circular background at frame: %@", NSStringFromRect(zoomFrame));
                } else {
                    NSLog(@"Standalone: No zoom button image available");
                }
            }
        }

        [titlebarImage unlockFocus];

        // Transfer the image to the titlebar
        BOOL success = [self transferImage:titlebarImage toTitlebar:titlebar];

        if (success) {
            NSLog(@"Standalone GSTheme titlebar rendered successfully for: %@", title);
        } else {
            NSLog(@"Failed to transfer standalone GSTheme titlebar for: %@", title);
        }

        return success;

    } @catch (NSException *exception) {
        NSLog(@"Standalone GSTheme titlebar rendering failed: %@", exception.reason);
        return NO;
    }
}

#pragma mark - Titlebar Management

+ (void)refreshAllTitlebars {
    URSThemeIntegration *integration = [URSThemeIntegration sharedInstance];

    if (!integration.enabled) {
        return;
    }

    for (XCBTitleBar *titlebar in integration.managedTitlebars) {
        // Determine if window is active (simplified for now)
        BOOL isActive = YES; // TODO: Implement proper active window detection

        [self renderGSThemeTitlebar:titlebar
                              title:titlebar.windowTitle
                             active:isActive];
    }

    NSLog(@"Refreshed %lu titlebars with GSTheme decorations", (unsigned long)[integration.managedTitlebars count]);
}

#pragma mark - Event Handlers

- (void)handleWindowCreated:(XCBTitleBar*)titlebar {
    if (!self.enabled || !titlebar) {
        return;
    }

    // Add to managed windows list
    if (![self.managedTitlebars containsObject:titlebar]) {
        [self.managedTitlebars addObject:titlebar];
        NSLog(@"Added titlebar to GSTheme management: %@", titlebar.windowTitle);
    }

    // Render GSTheme decoration
    [URSThemeIntegration renderGSThemeTitlebar:titlebar
                                         title:titlebar.windowTitle
                                        active:YES];
}

- (void)handleWindowFocusChanged:(XCBTitleBar*)titlebar isActive:(BOOL)active {
    if (!self.enabled || !titlebar) {
        return;
    }

    // Re-render with updated active state
    [URSThemeIntegration renderGSThemeTitlebar:titlebar
                                         title:titlebar.windowTitle
                                        active:active];
}


#pragma mark - Configuration

- (void)setEnabled:(BOOL)enabled {
    if (_enabled == enabled) {
        return; // Prevent recursion
    }

    _enabled = enabled;

    // Set user default to inform XCBKit about GSTheme status
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:enabled forKey:@"UROSWMGSThemeEnabled"];
    [defaults synchronize];

    if (enabled) {
        NSLog(@"GSTheme integration enabled - XCBKit will skip Cairo button drawing");
        // Don't call refreshAllTitlebars here - let the periodic timer handle it
    } else {
        NSLog(@"GSTheme integration disabled - falling back to Cairo rendering");
    }
}

#pragma mark - Cleanup

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (void)disableXCBTitleBarDrawing:(XCBTitleBar*)titlebar {
    // This method was declared but not used in our independent implementation
    NSLog(@"URSThemeIntegration: disableXCBTitleBarDrawing called (not needed for independent system)");
}

@end