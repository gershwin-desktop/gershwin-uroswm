# XNamespace Integration for gershwin-uroswm

## Overview

This document describes the XNamespace extension integration in gershwin-uroswm, providing client isolation into separate namespaces for enhanced security and usability.

XNamespace is an X11 extension from X11Libre/xserver that provides client isolation similar to Linux kernel namespaces. It isolates selections, resources, and interactions between X11 clients, with assignment based on authentication tokens and server-side configuration.

## Architecture

### Components

1. **XNamespaceManager** (`XNamespaceManager.h/m`)
   - Central manager for all namespace operations
   - Handles extension detection and atom-based communication
   - Manages namespace queries, assignments, and switching
   - Provides configuration persistence via NSUserDefaults

2. **XNamespaceConfigPanel** (`XNamespaceConfigPanel.h/m`)
   - GNUstep-based configuration GUI
   - Allows users to manage namespace colors, rules, and settings
   - Provides security log viewing

3. **XNamespaceVisualIndicator** (`XNamespaceVisualIndicator.h/m`)
   - Applies visual cues to windows based on their namespace
   - Supports border coloring, titlebar badges, and tooltips
   - Color-coded window borders for namespace identification

### Integration with URSHybridEventHandler

The XNamespace system is integrated into the main event handler:

```objc
// In URSHybridEventHandler
@property (strong, nonatomic) XNamespaceManager* namespaceManager;
@property (strong, nonatomic) XNamespaceVisualIndicator* namespaceIndicator;

// Initialization in applicationDidFinishLaunching:
[self initializeXNamespaceSupport];
```

## Features

### 1. Namespace Detection and Querying

The WM can detect and query namespaces via X atoms:

```objc
// Query namespace for a specific window
XNamespaceInfo *namespace = [namespaceManager namespaceForWindow:windowId];

// List all available namespaces
NSArray<XNamespaceInfo *> *namespaces = [namespaceManager queryAvailableNamespaces];

// Check if two windows are in the same namespace
BOOL sameNs = [namespaceManager window:window1 inSameNamespaceAs:window2];
```

### 2. Visual Indicators

Windows display color-coded borders based on their namespace:

```objc
// Apply namespace indicator to a window frame
[namespaceIndicator applyIndicatorToFrame:frame];

// Indicator styles available:
// - XNamespaceIndicatorStyleBorder (default)
// - XNamespaceIndicatorStyleTitlebarBadge
// - XNamespaceIndicatorStyleTitlebarStripe
// - XNamespaceIndicatorStyleOverlay
```

### 3. Namespace Switching

Users can switch namespaces via GUI:

```objc
// Create namespace status menu for menu bar
NSMenu *menu = [namespaceManager createNamespaceStatusMenu];

// Show namespace switch dialog
[namespaceManager showNamespaceSwitchDialog];

// Programmatic namespace switch
[namespaceManager requestNamespaceSwitch:targetNamespace];
```

### 4. Configuration GUI

A settings panel accessible via:

```objc
[namespaceManager showConfigurationPanel];
```

The panel includes:
- Namespace list with color configuration
- Cross-namespace rules management
- Visual indicator settings
- Security warning controls
- Security violation log

### 5. Security and Isolation

The WM enforces namespace isolation:

```objc
// Check if an operation is allowed between namespaces
BOOL allowed = [namespaceManager isOperationAllowed:@"reparent"
                                         fromWindow:sourceWindow
                                           toWindow:targetWindow];

// Block cross-namespace reparenting
BOOL shouldBlock = [namespaceManager shouldBlockReparenting:window toParent:newParent];

// Validate with optional user warning
[namespaceManager validateOperation:@"move"
                         fromWindow:source
                           toWindow:target
                        showWarning:YES];
```

## X Atoms Used

The following atoms are used for namespace communication:

| Atom Name | Purpose |
|-----------|---------|
| `_XNAMESPACE_NAMESPACE` | Namespace identifier |
| `_XNAMESPACE_NAMESPACE_ID` | Unique namespace ID |
| `_XNAMESPACE_NAMESPACE_NAME` | Human-readable name |
| `_XNAMESPACE_CLIENT_NAMESPACE` | Client's namespace assignment |
| `_XNAMESPACE_WINDOW_NAMESPACE` | Window's namespace assignment |
| `_XNAMESPACE_NAMESPACE_LIST` | List of available namespaces |
| `_XNAMESPACE_SWITCH_REQUEST` | Namespace switch request |
| `_XNAMESPACE_AUTH_TOKEN` | Authentication token |

## Configuration Storage

Settings are stored via NSUserDefaults:

```objc
// Keys used:
// - XNamespaceColorMap: Dictionary of namespace colors
// - XNamespaceRulesMap: Dictionary of namespace rules
// - XNamespaceVisualIndicators: BOOL for visual indicators
// - XNamespaceSecurityWarnings: BOOL for security warnings
// - XNamespaceCrossBlocking: BOOL for cross-namespace blocking
// - XNamespaceDefaultId: Default namespace ID
```

## Extension Compatibility

The implementation works with or without the XNamespace extension:

1. **Extension Available**: Uses XCB extension protocol for full functionality
2. **Extension Not Available**: Falls back to atom-based namespace simulation

Detection is performed at startup:

```objc
BOOL available = [namespaceManager checkExtensionAvailability];
```

## Delegate Protocol

Implement `XNamespaceManagerDelegate` for event notifications:

```objc
@protocol XNamespaceManagerDelegate <NSObject>
@optional
- (void)namespaceManager:(id)manager didDetectNamespace:(XNamespaceInfo *)namespace;
- (void)namespaceManager:(id)manager didChangeActiveNamespace:(XNamespaceInfo *)namespace;
- (void)namespaceManager:(id)manager didAssignWindow:(xcb_window_t)windowId toNamespace:(XNamespaceInfo *)namespace;
- (void)namespaceManager:(id)manager didDetectSecurityViolation:(NSDictionary *)violationInfo;
- (void)namespaceManagerExtensionBecameAvailable:(id)manager;
- (void)namespaceManagerExtensionNotAvailable:(id)manager;
@end
```

## Notifications

The following notifications are posted:

| Notification | Description |
|--------------|-------------|
| `XNamespaceDidChangeNotification` | Active namespace changed |
| `XNamespaceWindowAssignedNotification` | Window assigned to namespace |
| `XNamespaceSecurityViolationNotification` | Security violation detected |
| `XNamespaceExtensionAvailableNotification` | Extension became available |

## Future Enhancements

1. **Namespace-based window grouping**: Group windows by namespace in the workspace
2. **Per-namespace keyboard layouts**: Integration with XKB for different layouts per namespace
3. **Namespace templates**: Pre-configured namespace settings for common use cases
4. **Multi-user session management**: Spawn separate sessions in different namespaces
5. **Namespace persistence**: Remember namespace assignments across restarts

## References

- [XNamespace Documentation](https://github.com/X11Libre/xserver/blob/master/doc/Xnamespace.md)
- [X11Libre Server](https://github.com/X11Libre/xserver)
- [gershwin-uroswm](https://github.com/gershwin-desktop/gershwin-uroswm)
- [gershwin-xcbkit](https://github.com/gershwin-desktop/gershwin-xcbkit)
- [GNUstep Documentation](https://gnustep.github.io/)

## Building

The XNamespace integration is built as part of the Gershwin desktop system using [gershwin-build](https://github.com/gershwin-desktop/gershwin-build).

### Supported Operating Systems

- FreeBSD
- GhostBSD
- Arch Linux
- Debian

### Build Instructions

```bash
# Clone the build system
git clone https://github.com/gershwin-desktop/gershwin-build.git
cd gershwin-build

# Install build dependencies
sudo ./bootstrap.sh

# Checkout all Gershwin components (including gershwin-uroswm)
./checkout.sh

# Build and install the complete Gershwin system
sudo make install
```

For more details, see the [gershwin-build README](https://github.com/gershwin-desktop/gershwin-build/blob/main/README.md).

## Testing

### Unit Testing

Run XCB connection tests in a Xephyr session:

```bash
# Start Xephyr
Xephyr -ac -br -screen 1300x900 -reset :1 &

# Set display
export DISPLAY=:1

# Run window manager
./WindowManager.app/WindowManager
```

### Integration Testing

1. Start the WM in Xephyr
2. Open multiple applications
3. Verify namespace indicators appear
4. Test configuration panel
5. Verify security blocking (if enabled)

## License

This XNamespace integration is part of gershwin-uroswm and follows the same license.
