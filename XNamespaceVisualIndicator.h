//
//  XNamespaceVisualIndicator.h
//  uroswm - XNamespace Visual Indicators
//
//  Provides visual cues for namespace identification through color-coded
//  window borders, overlays, and tooltips.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <XCBKit/XCBConnection.h>
#import <XCBKit/XCBWindow.h>
#import <XCBKit/XCBFrame.h>
#import <XCBKit/XCBTitleBar.h>

@class XNamespaceManager;
@class XNamespaceInfo;

// Visual indicator styles
typedef NS_ENUM(NSInteger, XNamespaceIndicatorStyle) {
    XNamespaceIndicatorStyleBorder,          // Color-coded window border
    XNamespaceIndicatorStyleTitlebarBadge,   // Small badge in titlebar
    XNamespaceIndicatorStyleTitlebarStripe,  // Colored stripe in titlebar
    XNamespaceIndicatorStyleOverlay          // Semi-transparent overlay
};


@interface XNamespaceVisualIndicator : NSObject

// Reference to manager and connection
@property (weak, nonatomic) XNamespaceManager *namespaceManager;
@property (weak, nonatomic) XCBConnection *connection;

// Configuration
@property (assign, nonatomic) XNamespaceIndicatorStyle indicatorStyle;
@property (assign, nonatomic) CGFloat borderWidth;
@property (assign, nonatomic) CGFloat badgeSize;
@property (assign, nonatomic) BOOL showTooltips;
@property (assign, nonatomic) BOOL animateTransitions;

// Singleton access
+ (instancetype)sharedIndicator;

// Initialization
- (instancetype)initWithManager:(XNamespaceManager *)manager
                     connection:(XCBConnection *)connection;

#pragma mark - Indicator Application

// Apply namespace indicator to a window/frame
- (void)applyIndicatorToFrame:(XCBFrame *)frame;
- (void)applyIndicatorToWindow:(XCBWindow *)window;

// Update indicator when namespace changes
- (void)updateIndicatorForWindow:(xcb_window_t)windowId;

// Remove indicator from window
- (void)removeIndicatorFromWindow:(xcb_window_t)windowId;

// Refresh all indicators (e.g., after color change)
- (void)refreshAllIndicators;

#pragma mark - Border Indicators

// Apply color-coded border to frame
- (void)applyBorderIndicator:(XCBFrame *)frame 
               withNamespace:(XNamespaceInfo *)namespace;

// Get border color for namespace
- (uint32_t)borderPixelForNamespace:(XNamespaceInfo *)namespace;

#pragma mark - Titlebar Indicators

// Draw namespace badge in titlebar
- (void)drawNamespaceBadgeInTitlebar:(XCBTitleBar *)titlebar
                       withNamespace:(XNamespaceInfo *)namespace;

// Draw namespace stripe in titlebar
- (void)drawNamespaceStripeInTitlebar:(XCBTitleBar *)titlebar
                        withNamespace:(XNamespaceInfo *)namespace;

#pragma mark - Tooltip Support

// Generate tooltip text for namespace
- (NSString *)tooltipTextForNamespace:(XNamespaceInfo *)namespace;

// Set tooltip on window
- (void)setTooltip:(NSString *)tooltip forWindow:(xcb_window_t)windowId;

#pragma mark - Color Utilities

// Convert NSColor to X11 pixel value
- (uint32_t)pixelForColor:(NSColor *)color;

// Generate contrasting text color for namespace
- (NSColor *)contrastingTextColorForNamespace:(XNamespaceInfo *)namespace;

// Darken or lighten namespace color for inactive state
- (NSColor *)inactiveColorForNamespace:(XNamespaceInfo *)namespace;

@end
