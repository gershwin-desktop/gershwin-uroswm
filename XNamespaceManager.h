//
//  XNamespaceManager.h
//  uroswm - XNamespace Extension Integration
//
//  This class provides XNamespace extension support for the window manager,
//  enabling client isolation into separate namespaces. XNamespace isolates
//  selections, resources, and interactions between clients.
//
//  See: https://github.com/X11Libre/xserver/blob/master/doc/Xnamespace.md
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <XCBKit/XCBConnection.h>
#import <XCBKit/XCBWindow.h>
#import <XCBKit/XCBFrame.h>
#import <xcb/xcb.h>

// Namespace information structure
@interface XNamespaceInfo : NSObject

@property (strong, nonatomic) NSString *namespaceId;
@property (strong, nonatomic) NSString *namespaceName;
@property (strong, nonatomic) NSColor *namespaceColor;
@property (assign, nonatomic) BOOL isRoot;
@property (assign, nonatomic) BOOL isActive;
@property (strong, nonatomic) NSString *authToken;
@property (strong, nonatomic) NSArray<NSNumber *> *windowIds;
@property (strong, nonatomic) NSDictionary *permissions;

- (instancetype)initWithId:(NSString *)nsId name:(NSString *)name;

@end


// Namespace event notification names
extern NSString * const XNamespaceDidChangeNotification;
extern NSString * const XNamespaceWindowAssignedNotification;
extern NSString * const XNamespaceSecurityViolationNotification;
extern NSString * const XNamespaceExtensionAvailableNotification;


// Protocol for namespace event delegation
@protocol XNamespaceManagerDelegate <NSObject>

@optional
- (void)namespaceManager:(id)manager didDetectNamespace:(XNamespaceInfo *)namespace;
- (void)namespaceManager:(id)manager didChangeActiveNamespace:(XNamespaceInfo *)namespace;
- (void)namespaceManager:(id)manager didAssignWindow:(xcb_window_t)windowId toNamespace:(XNamespaceInfo *)namespace;
- (void)namespaceManager:(id)manager didDetectSecurityViolation:(NSDictionary *)violationInfo;
- (void)namespaceManagerExtensionBecameAvailable:(id)manager;
- (void)namespaceManagerExtensionNotAvailable:(id)manager;

@end


@interface XNamespaceManager : NSObject

// Singleton access
+ (instancetype)sharedManager;

// Delegate for namespace events
@property (weak, nonatomic) id<XNamespaceManagerDelegate> delegate;

// XCB Connection
@property (strong, nonatomic) XCBConnection *connection;

// Extension availability
@property (assign, nonatomic, readonly) BOOL extensionAvailable;
@property (assign, nonatomic, readonly) uint8_t extensionMajorOpcode;
@property (assign, nonatomic, readonly) uint8_t extensionFirstEvent;
@property (assign, nonatomic, readonly) uint8_t extensionFirstError;

// Current namespace state
@property (strong, nonatomic, readonly) XNamespaceInfo *currentNamespace;
@property (strong, nonatomic, readonly) NSArray<XNamespaceInfo *> *availableNamespaces;

// Configuration
@property (assign, nonatomic) BOOL visualIndicatorsEnabled;
@property (assign, nonatomic) BOOL securityWarningsEnabled;
@property (assign, nonatomic) BOOL crossNamespaceBlockingEnabled;

#pragma mark - Initialization

// Initialize with XCB connection
- (instancetype)initWithConnection:(XCBConnection *)connection;

// Check for XNamespace extension availability
- (BOOL)checkExtensionAvailability;

// Initialize XNamespace atoms for communication
- (void)initializeNamespaceAtoms;

#pragma mark - Namespace Detection and Querying

// Query the namespace of a specific window
- (XNamespaceInfo *)namespaceForWindow:(xcb_window_t)windowId;

// Query the namespace of a specific client
- (XNamespaceInfo *)namespaceForClient:(xcb_window_t)clientId;

// Get list of all available namespaces
- (NSArray<XNamespaceInfo *> *)queryAvailableNamespaces;

// Get windows belonging to a specific namespace
- (NSArray<NSNumber *> *)windowsInNamespace:(XNamespaceInfo *)namespace;

// Check if two windows are in the same namespace
- (BOOL)window:(xcb_window_t)window1 inSameNamespaceAs:(xcb_window_t)window2;

#pragma mark - Namespace Assignment and Switching

// Request namespace switch for the WM itself
- (BOOL)requestNamespaceSwitch:(XNamespaceInfo *)targetNamespace;

// Request namespace assignment for a child process
- (BOOL)requestNamespaceForProcess:(NSString *)authToken namespace:(XNamespaceInfo *)targetNamespace;

// Spawn a process in a specific namespace
- (NSTask *)spawnProcessInNamespace:(NSString *)executablePath
                         arguments:(NSArray<NSString *> *)arguments
                         namespace:(XNamespaceInfo *)targetNamespace;

#pragma mark - Visual Indicators

// Get the visual indicator color for a namespace
- (NSColor *)colorForNamespace:(XNamespaceInfo *)namespace;

// Set custom color for a namespace
- (void)setColor:(NSColor *)color forNamespace:(XNamespaceInfo *)namespace;

// Apply namespace visual indicator to a window's decorations
- (void)applyNamespaceIndicatorToWindow:(XCBWindow *)window;

// Get namespace indicator tooltip text
- (NSString *)tooltipForNamespace:(XNamespaceInfo *)namespace;

#pragma mark - Security and Isolation

// Check if an operation between two windows is allowed
- (BOOL)isOperationAllowed:(NSString *)operationType
               fromWindow:(xcb_window_t)sourceWindow
                 toWindow:(xcb_window_t)targetWindow;

// Block cross-namespace window operations (e.g., reparenting)
- (BOOL)shouldBlockReparenting:(xcb_window_t)window toParent:(xcb_window_t)newParent;

// Validate namespace operation with optional user warning
- (BOOL)validateOperation:(NSString *)operation
               fromWindow:(xcb_window_t)source
                 toWindow:(xcb_window_t)target
              showWarning:(BOOL)showWarning;

// Record security violation attempt
- (void)recordSecurityViolation:(NSDictionary *)violationDetails;

#pragma mark - Configuration Management

// Save namespace configuration to user defaults
- (void)saveConfiguration;

// Load namespace configuration from user defaults
- (void)loadConfiguration;

// Get namespace rules for a specific namespace
- (NSDictionary *)rulesForNamespace:(XNamespaceInfo *)namespace;

// Set namespace rules
- (void)setRules:(NSDictionary *)rules forNamespace:(XNamespaceInfo *)namespace;

// Get default namespace assignment for new clients
- (XNamespaceInfo *)defaultNamespaceForNewClients;

// Set default namespace for new clients
- (void)setDefaultNamespaceForNewClients:(XNamespaceInfo *)namespace;

#pragma mark - GUI Integration

// Create namespace status menu for menu bar
- (NSMenu *)createNamespaceStatusMenu;

// Create namespace selection popup button
- (NSPopUpButton *)createNamespaceSelectorWithTarget:(id)target action:(SEL)action;

// Show namespace configuration panel
- (void)showConfigurationPanel;

// Show namespace switching dialog
- (void)showNamespaceSwitchDialog;

// Show security violation alert
- (void)showSecurityViolationAlert:(NSDictionary *)violation;

#pragma mark - Event Handling

// Handle XCB events related to namespaces
- (BOOL)handleXCBEvent:(xcb_generic_event_t *)event;

// Handle property notify events for namespace changes
- (void)handlePropertyNotify:(xcb_property_notify_event_t *)event;

// Handle client message events for namespace operations
- (void)handleClientMessage:(xcb_client_message_event_t *)event;

#pragma mark - Cleanup

// Cleanup namespace resources
- (void)cleanup;

@end
