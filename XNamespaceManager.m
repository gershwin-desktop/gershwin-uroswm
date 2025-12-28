//
//  XNamespaceManager.m
//  uroswm - XNamespace Extension Integration
//
//  Implementation of XNamespace extension support for the window manager.
//  Provides namespace detection, querying, visual indicators, and security isolation.
//
//  See: https://github.com/X11Libre/xserver/blob/master/doc/Xnamespace.md
//

#import "XNamespaceManager.h"
#import "XNamespaceConfigPanel.h"
#import <xcb/xcb.h>
#import <objc/runtime.h>

// Notification names
NSString * const XNamespaceDidChangeNotification = @"XNamespaceDidChangeNotification";
NSString * const XNamespaceWindowAssignedNotification = @"XNamespaceWindowAssignedNotification";
NSString * const XNamespaceSecurityViolationNotification = @"XNamespaceSecurityViolationNotification";
NSString * const XNamespaceExtensionAvailableNotification = @"XNamespaceExtensionAvailableNotification";

// XNamespace extension name (as defined in X11Libre/xserver)
static NSString * const kXNamespaceExtensionName = @"XNAMESPACE";

// Atom names for XNamespace communication
static NSString * const kXNamespaceAtomNamespace = @"_XNAMESPACE_NAMESPACE";
static NSString * const kXNamespaceAtomNamespaceId = @"_XNAMESPACE_NAMESPACE_ID";
static NSString * const kXNamespaceAtomNamespaceName = @"_XNAMESPACE_NAMESPACE_NAME";
static NSString * const kXNamespaceAtomClientNamespace = @"_XNAMESPACE_CLIENT_NAMESPACE";
static NSString * const kXNamespaceAtomWindowNamespace = @"_XNAMESPACE_WINDOW_NAMESPACE";
static NSString * const kXNamespaceAtomNamespaceList = @"_XNAMESPACE_NAMESPACE_LIST";
static NSString * const kXNamespaceAtomSwitchRequest = @"_XNAMESPACE_SWITCH_REQUEST";
static NSString * const kXNamespaceAtomAuthToken = @"_XNAMESPACE_AUTH_TOKEN";

// Default namespace colors (for visual distinction)
static NSColor *defaultNamespaceColors[8];

#pragma mark - XNamespaceInfo Implementation

@implementation XNamespaceInfo

- (instancetype)initWithId:(NSString *)nsId name:(NSString *)name {
    self = [super init];
    if (self) {
        _namespaceId = nsId ?: @"default";
        _namespaceName = name ?: @"Default Namespace";
        _isRoot = [nsId isEqualToString:@"root"] || [nsId isEqualToString:@"0"];
        _isActive = NO;
        _windowIds = @[];
        _permissions = @{};
        
        // Assign default color based on namespace ID hash
        NSUInteger colorIndex = [nsId hash] % 8;
        _namespaceColor = defaultNamespaceColors[colorIndex];
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<XNamespaceInfo: id=%@, name=%@, isRoot=%d, isActive=%d, windows=%lu>",
            _namespaceId, _namespaceName, _isRoot, _isActive, (unsigned long)[_windowIds count]];
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[XNamespaceInfo class]]) {
        return NO;
    }
    XNamespaceInfo *other = (XNamespaceInfo *)object;
    return [self.namespaceId isEqualToString:other.namespaceId];
}

- (NSUInteger)hash {
    return [self.namespaceId hash];
}

@end


#pragma mark - XNamespaceManager Implementation

@interface XNamespaceManager ()

// Cached atoms
@property (assign, nonatomic) xcb_atom_t atomNamespace;
@property (assign, nonatomic) xcb_atom_t atomNamespaceId;
@property (assign, nonatomic) xcb_atom_t atomNamespaceName;
@property (assign, nonatomic) xcb_atom_t atomClientNamespace;
@property (assign, nonatomic) xcb_atom_t atomWindowNamespace;
@property (assign, nonatomic) xcb_atom_t atomNamespaceList;
@property (assign, nonatomic) xcb_atom_t atomSwitchRequest;
@property (assign, nonatomic) xcb_atom_t atomAuthToken;

// Internal state
@property (strong, nonatomic) NSMutableDictionary<NSString *, XNamespaceInfo *> *namespaceCache;
@property (strong, nonatomic) NSMutableDictionary<NSNumber *, NSString *> *windowNamespaceMap;
@property (strong, nonatomic) NSMutableDictionary<NSString *, NSColor *> *namespaceColorMap;
@property (strong, nonatomic) NSMutableDictionary<NSString *, NSDictionary *> *namespaceRulesMap;
@property (strong, nonatomic) NSMutableArray *securityViolationLog;
@property (strong, nonatomic) XNamespaceInfo *defaultNamespace;

// Configuration panel
@property (strong, nonatomic) XNamespaceConfigPanel *configPanel;

@end


@implementation XNamespaceManager

static XNamespaceManager *sharedManager = nil;

#pragma mark - Class Initialization

+ (void)initialize {
    if (self == [XNamespaceManager class]) {
        // Initialize default namespace colors
        defaultNamespaceColors[0] = [NSColor colorWithCalibratedRed:0.2 green:0.4 blue:0.8 alpha:1.0]; // Blue
        defaultNamespaceColors[1] = [NSColor colorWithCalibratedRed:0.8 green:0.2 blue:0.2 alpha:1.0]; // Red
        defaultNamespaceColors[2] = [NSColor colorWithCalibratedRed:0.2 green:0.7 blue:0.3 alpha:1.0]; // Green
        defaultNamespaceColors[3] = [NSColor colorWithCalibratedRed:0.8 green:0.6 blue:0.1 alpha:1.0]; // Yellow/Orange
        defaultNamespaceColors[4] = [NSColor colorWithCalibratedRed:0.6 green:0.2 blue:0.6 alpha:1.0]; // Purple
        defaultNamespaceColors[5] = [NSColor colorWithCalibratedRed:0.1 green:0.6 blue:0.6 alpha:1.0]; // Cyan
        defaultNamespaceColors[6] = [NSColor colorWithCalibratedRed:0.5 green:0.5 blue:0.5 alpha:1.0]; // Gray
        defaultNamespaceColors[7] = [NSColor colorWithCalibratedRed:0.9 green:0.4 blue:0.6 alpha:1.0]; // Pink
    }
}

#pragma mark - Singleton Access

+ (instancetype)sharedManager {
    if (sharedManager == nil) {
        sharedManager = [[XNamespaceManager alloc] init];
    }
    return sharedManager;
}

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        _namespaceCache = [[NSMutableDictionary alloc] init];
        _windowNamespaceMap = [[NSMutableDictionary alloc] init];
        _namespaceColorMap = [[NSMutableDictionary alloc] init];
        _namespaceRulesMap = [[NSMutableDictionary alloc] init];
        _securityViolationLog = [[NSMutableArray alloc] init];
        
        _visualIndicatorsEnabled = YES;
        _securityWarningsEnabled = YES;
        _crossNamespaceBlockingEnabled = YES;
        
        _extensionAvailable = NO;
        
        // Create default namespace
        _defaultNamespace = [[XNamespaceInfo alloc] initWithId:@"default" name:@"Default"];
        _defaultNamespace.isRoot = YES;
        _defaultNamespace.isActive = YES;
        _namespaceCache[@"default"] = _defaultNamespace;
        
        // Load saved configuration
        [self loadConfiguration];
        
        NSLog(@"XNamespaceManager: Initialized");
    }
    return self;
}

- (instancetype)initWithConnection:(XCBConnection *)connection {
    self = [self init];
    if (self) {
        _connection = connection;
        
        // Check for XNamespace extension
        [self checkExtensionAvailability];
        
        // Initialize atoms for namespace communication
        [self initializeNamespaceAtoms];
        
        NSLog(@"XNamespaceManager: Initialized with connection, extension available: %d", _extensionAvailable);
    }
    return self;
}

#pragma mark - Extension Detection

- (BOOL)checkExtensionAvailability {
    if (!self.connection) {
        NSLog(@"XNamespaceManager: No connection available for extension check");
        _extensionAvailable = NO;
        return NO;
    }
    
    @try {
        xcb_connection_t *conn = [self.connection connection];
        
        // Query for XNamespace extension
        const char *extensionName = [kXNamespaceExtensionName UTF8String];
        xcb_query_extension_cookie_t cookie = xcb_query_extension(conn, 
                                                                   strlen(extensionName), 
                                                                   extensionName);
        xcb_query_extension_reply_t *reply = xcb_query_extension_reply(conn, cookie, NULL);
        
        if (reply) {
            _extensionAvailable = reply->present;
            if (_extensionAvailable) {
                _extensionMajorOpcode = reply->major_opcode;
                _extensionFirstEvent = reply->first_event;
                _extensionFirstError = reply->first_error;
                
                NSLog(@"XNamespaceManager: XNamespace extension found - opcode:%d, event:%d, error:%d",
                      _extensionMajorOpcode, _extensionFirstEvent, _extensionFirstError);
                
                // Notify delegate and observers
                if ([self.delegate respondsToSelector:@selector(namespaceManagerExtensionBecameAvailable:)]) {
                    [self.delegate namespaceManagerExtensionBecameAvailable:self];
                }
                [[NSNotificationCenter defaultCenter] postNotificationName:XNamespaceExtensionAvailableNotification
                                                                    object:self];
            } else {
                NSLog(@"XNamespaceManager: XNamespace extension not available on this server");
                NSLog(@"XNamespaceManager: Will use atom-based namespace simulation for compatibility");
                
                if ([self.delegate respondsToSelector:@selector(namespaceManagerExtensionNotAvailable:)]) {
                    [self.delegate namespaceManagerExtensionNotAvailable:self];
                }
            }
            free(reply);
        } else {
            NSLog(@"XNamespaceManager: Failed to query XNamespace extension");
            _extensionAvailable = NO;
        }
        
    } @catch (NSException *exception) {
        NSLog(@"XNamespaceManager: Exception checking extension: %@", exception.reason);
        _extensionAvailable = NO;
    }
    
    return _extensionAvailable;
}

#pragma mark - Atom Initialization

- (void)initializeNamespaceAtoms {
    if (!self.connection) {
        NSLog(@"XNamespaceManager: No connection for atom initialization");
        return;
    }
    
    xcb_connection_t *conn = [self.connection connection];
    
    // Intern all namespace-related atoms
    NSArray *atomNames = @[
        kXNamespaceAtomNamespace,
        kXNamespaceAtomNamespaceId,
        kXNamespaceAtomNamespaceName,
        kXNamespaceAtomClientNamespace,
        kXNamespaceAtomWindowNamespace,
        kXNamespaceAtomNamespaceList,
        kXNamespaceAtomSwitchRequest,
        kXNamespaceAtomAuthToken
    ];
    
    // Send all atom intern requests
    NSMutableArray *cookies = [[NSMutableArray alloc] init];
    for (NSString *atomName in atomNames) {
        const char *name = [atomName UTF8String];
        xcb_intern_atom_cookie_t cookie = xcb_intern_atom(conn, 0, strlen(name), name);
        [cookies addObject:@(cookie.sequence)];
    }
    
    // Collect replies
    xcb_atom_t *atoms[] = {
        &_atomNamespace,
        &_atomNamespaceId,
        &_atomNamespaceName,
        &_atomClientNamespace,
        &_atomWindowNamespace,
        &_atomNamespaceList,
        &_atomSwitchRequest,
        &_atomAuthToken
    };
    
    for (NSUInteger i = 0; i < [atomNames count]; i++) {
        const char *name = [atomNames[i] UTF8String];
        xcb_intern_atom_cookie_t cookie = xcb_intern_atom(conn, 0, strlen(name), name);
        xcb_intern_atom_reply_t *reply = xcb_intern_atom_reply(conn, cookie, NULL);
        
        if (reply) {
            *atoms[i] = reply->atom;
            NSLog(@"XNamespaceManager: Interned atom %@ = %u", atomNames[i], reply->atom);
            free(reply);
        } else {
            NSLog(@"XNamespaceManager: Failed to intern atom %@", atomNames[i]);
            *atoms[i] = XCB_ATOM_NONE;
        }
    }
    
    NSLog(@"XNamespaceManager: Namespace atoms initialized");
}

#pragma mark - Namespace Detection and Querying

- (XNamespaceInfo *)namespaceForWindow:(xcb_window_t)windowId {
    // Check cache first
    NSNumber *windowKey = @(windowId);
    NSString *cachedNamespaceId = self.windowNamespaceMap[windowKey];
    if (cachedNamespaceId) {
        return self.namespaceCache[cachedNamespaceId];
    }
    
    if (!self.connection || self.atomWindowNamespace == XCB_ATOM_NONE) {
        return self.defaultNamespace;
    }
    
    @try {
        xcb_connection_t *conn = [self.connection connection];
        
        // Query the _XNAMESPACE_WINDOW_NAMESPACE property on the window
        xcb_get_property_cookie_t cookie = xcb_get_property(conn, 0, windowId,
                                                            self.atomWindowNamespace,
                                                            XCB_ATOM_STRING, 0, 256);
        xcb_get_property_reply_t *reply = xcb_get_property_reply(conn, cookie, NULL);
        
        if (reply && xcb_get_property_value_length(reply) > 0) {
            char *namespaceId = (char *)xcb_get_property_value(reply);
            NSString *nsId = [[NSString alloc] initWithBytes:namespaceId
                                                      length:xcb_get_property_value_length(reply)
                                                    encoding:NSUTF8StringEncoding];
            free(reply);
            
            // Look up or create namespace info
            XNamespaceInfo *nsInfo = self.namespaceCache[nsId];
            if (!nsInfo) {
                nsInfo = [[XNamespaceInfo alloc] initWithId:nsId name:nil];
                self.namespaceCache[nsId] = nsInfo;
            }
            
            // Update cache
            self.windowNamespaceMap[windowKey] = nsId;
            
            NSLog(@"XNamespaceManager: Window %u belongs to namespace %@", windowId, nsId);
            return nsInfo;
        }
        
        if (reply) {
            free(reply);
        }
        
    } @catch (NSException *exception) {
        NSLog(@"XNamespaceManager: Exception querying window namespace: %@", exception.reason);
    }
    
    // Default namespace if not found
    self.windowNamespaceMap[windowKey] = self.defaultNamespace.namespaceId;
    return self.defaultNamespace;
}

- (XNamespaceInfo *)namespaceForClient:(xcb_window_t)clientId {
    // For clients, we query the _XNAMESPACE_CLIENT_NAMESPACE property
    // This is similar to window namespace but specifically for client identification
    return [self namespaceForWindow:clientId];
}

- (NSArray<XNamespaceInfo *> *)queryAvailableNamespaces {
    if (!self.connection) {
        return @[self.defaultNamespace];
    }
    
    NSMutableArray *namespaces = [[NSMutableArray alloc] init];
    
    if (self.extensionAvailable) {
        // If XNamespace extension is available, query the server directly
        // Note: This would require XNamespace extension protocol requests
        // For now, we use atom-based querying as a fallback
        [self queryNamespacesViaAtoms:namespaces];
    } else {
        // Use atom-based namespace detection
        [self queryNamespacesViaAtoms:namespaces];
    }
    
    // Always include default namespace
    if (![namespaces containsObject:self.defaultNamespace]) {
        [namespaces insertObject:self.defaultNamespace atIndex:0];
    }
    
    // Update internal cache
    _availableNamespaces = [namespaces copy];
    
    NSLog(@"XNamespaceManager: Found %lu available namespaces", (unsigned long)[namespaces count]);
    return _availableNamespaces;
}

- (void)queryNamespacesViaAtoms:(NSMutableArray *)namespaces {
    if (!self.connection || self.atomNamespaceList == XCB_ATOM_NONE) {
        return;
    }
    
    @try {
        xcb_connection_t *conn = [self.connection connection];
        XCBScreen *screen = [[self.connection screens] objectAtIndex:0];
        xcb_window_t rootWindow = [screen screen]->root;
        
        // Query the namespace list from the root window
        xcb_get_property_cookie_t cookie = xcb_get_property(conn, 0, rootWindow,
                                                            self.atomNamespaceList,
                                                            XCB_ATOM_STRING, 0, 4096);
        xcb_get_property_reply_t *reply = xcb_get_property_reply(conn, cookie, NULL);
        
        if (reply && xcb_get_property_value_length(reply) > 0) {
            NSString *namespaceListStr = [[NSString alloc] initWithBytes:xcb_get_property_value(reply)
                                                                  length:xcb_get_property_value_length(reply)
                                                                encoding:NSUTF8StringEncoding];
            
            // Parse namespace list (format: "ns1:name1\nns2:name2\n...")
            NSArray *lines = [namespaceListStr componentsSeparatedByString:@"\n"];
            for (NSString *line in lines) {
                if ([line length] == 0) continue;
                
                NSArray *parts = [line componentsSeparatedByString:@":"];
                NSString *nsId = parts[0];
                NSString *nsName = [parts count] > 1 ? parts[1] : nsId;
                
                XNamespaceInfo *nsInfo = self.namespaceCache[nsId];
                if (!nsInfo) {
                    nsInfo = [[XNamespaceInfo alloc] initWithId:nsId name:nsName];
                    self.namespaceCache[nsId] = nsInfo;
                }
                
                [namespaces addObject:nsInfo];
            }
            
            free(reply);
        }
        
        if (reply) {
            free(reply);
        }
        
    } @catch (NSException *exception) {
        NSLog(@"XNamespaceManager: Exception querying namespace list: %@", exception.reason);
    }
}

- (NSArray<NSNumber *> *)windowsInNamespace:(XNamespaceInfo *)namespace {
    if (!namespace) {
        return @[];
    }
    
    NSMutableArray *windows = [[NSMutableArray alloc] init];
    
    for (NSNumber *windowKey in self.windowNamespaceMap) {
        NSString *nsId = self.windowNamespaceMap[windowKey];
        if ([nsId isEqualToString:namespace.namespaceId]) {
            [windows addObject:windowKey];
        }
    }
    
    return windows;
}

- (BOOL)window:(xcb_window_t)window1 inSameNamespaceAs:(xcb_window_t)window2 {
    XNamespaceInfo *ns1 = [self namespaceForWindow:window1];
    XNamespaceInfo *ns2 = [self namespaceForWindow:window2];
    
    return [ns1 isEqual:ns2];
}

#pragma mark - Namespace Assignment and Switching

- (BOOL)requestNamespaceSwitch:(XNamespaceInfo *)targetNamespace {
    if (!targetNamespace) {
        NSLog(@"XNamespaceManager: Cannot switch to nil namespace");
        return NO;
    }
    
    if (!self.connection) {
        NSLog(@"XNamespaceManager: No connection for namespace switch");
        return NO;
    }
    
    NSLog(@"XNamespaceManager: Requesting switch to namespace %@", targetNamespace.namespaceId);
    
    @try {
        xcb_connection_t *conn = [self.connection connection];
        XCBScreen *screen = [[self.connection screens] objectAtIndex:0];
        xcb_window_t rootWindow = [screen screen]->root;
        
        // Send namespace switch request via client message
        xcb_client_message_event_t event;
        memset(&event, 0, sizeof(event));
        event.response_type = XCB_CLIENT_MESSAGE;
        event.format = 32;
        event.window = rootWindow;
        event.type = self.atomSwitchRequest;
        
        // Pack namespace ID hash into data
        event.data.data32[0] = (uint32_t)[targetNamespace.namespaceId hash];
        
        xcb_send_event(conn, 0, rootWindow, XCB_EVENT_MASK_SUBSTRUCTURE_NOTIFY, (char *)&event);
        [self.connection flush];
        
        // Update current namespace (optimistic update)
        _currentNamespace.isActive = NO;
        _currentNamespace = targetNamespace;
        _currentNamespace.isActive = YES;
        
        // Notify observers
        [[NSNotificationCenter defaultCenter] postNotificationName:XNamespaceDidChangeNotification
                                                            object:self
                                                          userInfo:@{@"namespace": targetNamespace}];
        
        if ([self.delegate respondsToSelector:@selector(namespaceManager:didChangeActiveNamespace:)]) {
            [self.delegate namespaceManager:self didChangeActiveNamespace:targetNamespace];
        }
        
        NSLog(@"XNamespaceManager: Namespace switch request sent for %@", targetNamespace.namespaceId);
        return YES;
        
    } @catch (NSException *exception) {
        NSLog(@"XNamespaceManager: Exception during namespace switch: %@", exception.reason);
        return NO;
    }
}

- (BOOL)requestNamespaceForProcess:(NSString *)authToken namespace:(XNamespaceInfo *)targetNamespace {
    if (!authToken || !targetNamespace) {
        return NO;
    }
    
    NSLog(@"XNamespaceManager: Requesting namespace %@ for process with token", targetNamespace.namespaceId);
    
    // Store the auth token association
    // In a real implementation, this would communicate with the X server
    // to register the token for the target namespace
    
    return YES;
}

- (NSTask *)spawnProcessInNamespace:(NSString *)executablePath
                         arguments:(NSArray<NSString *> *)arguments
                         namespace:(XNamespaceInfo *)targetNamespace {
    
    if (!executablePath || !targetNamespace) {
        NSLog(@"XNamespaceManager: Invalid parameters for process spawn");
        return nil;
    }
    
    NSLog(@"XNamespaceManager: Spawning %@ in namespace %@", executablePath, targetNamespace.namespaceId);
    
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:executablePath];
    
    if (arguments) {
        [task setArguments:arguments];
    }
    
    // Set environment variables for namespace targeting
    NSMutableDictionary *env = [[[NSProcessInfo processInfo] environment] mutableCopy];
    env[@"XNAMESPACE_TARGET"] = targetNamespace.namespaceId;
    env[@"XNAMESPACE_AUTH"] = targetNamespace.authToken ?: @"";
    [task setEnvironment:env];
    
    @try {
        [task launch];
        NSLog(@"XNamespaceManager: Process spawned successfully in namespace %@", targetNamespace.namespaceId);
    } @catch (NSException *exception) {
        NSLog(@"XNamespaceManager: Failed to spawn process: %@", exception.reason);
        return nil;
    }
    
    return task;
}

#pragma mark - Visual Indicators

- (NSColor *)colorForNamespace:(XNamespaceInfo *)namespace {
    if (!namespace) {
        return [NSColor grayColor];
    }
    
    // Check for custom color first
    NSColor *customColor = self.namespaceColorMap[namespace.namespaceId];
    if (customColor) {
        return customColor;
    }
    
    return namespace.namespaceColor;
}

- (void)setColor:(NSColor *)color forNamespace:(XNamespaceInfo *)namespace {
    if (!namespace || !color) {
        return;
    }
    
    self.namespaceColorMap[namespace.namespaceId] = color;
    namespace.namespaceColor = color;
    
    // Save configuration
    [self saveConfiguration];
    
    NSLog(@"XNamespaceManager: Set color for namespace %@", namespace.namespaceId);
}

- (void)applyNamespaceIndicatorToWindow:(XCBWindow *)window {
    if (!self.visualIndicatorsEnabled || !window) {
        return;
    }
    
    xcb_window_t windowId = [window window];
    XNamespaceInfo *namespace = [self namespaceForWindow:windowId];
    NSColor *indicatorColor = [self colorForNamespace:namespace];
    
    // Apply color-coded border to window frame
    if ([window isKindOfClass:[XCBFrame class]]) {
        XCBFrame *frame = (XCBFrame *)window;
        
        // Convert NSColor to X11 pixel value
        CGFloat red, green, blue, alpha;
        [[indicatorColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace] 
            getRed:&red green:&green blue:&blue alpha:&alpha];
        
        uint32_t pixel = ((uint32_t)(red * 255) << 16) | 
                         ((uint32_t)(green * 255) << 8) | 
                         (uint32_t)(blue * 255);
        
        // Set border color
        xcb_change_window_attributes([self.connection connection],
                                     [frame window],
                                     XCB_CW_BORDER_PIXEL,
                                     &pixel);
        
        [self.connection flush];
        
        NSLog(@"XNamespaceManager: Applied namespace indicator color to window %u (namespace: %@)",
              windowId, namespace.namespaceId);
    }
}

- (NSString *)tooltipForNamespace:(XNamespaceInfo *)namespace {
    if (!namespace) {
        return @"Unknown Namespace";
    }
    
    return [NSString stringWithFormat:@"Namespace: %@\nID: %@\n%@",
            namespace.namespaceName,
            namespace.namespaceId,
            namespace.isRoot ? @"(Root Namespace)" : @""];
}

#pragma mark - Security and Isolation

- (BOOL)isOperationAllowed:(NSString *)operationType
               fromWindow:(xcb_window_t)sourceWindow
                 toWindow:(xcb_window_t)targetWindow {
    
    if (!self.crossNamespaceBlockingEnabled) {
        return YES;
    }
    
    XNamespaceInfo *sourceNs = [self namespaceForWindow:sourceWindow];
    XNamespaceInfo *targetNs = [self namespaceForWindow:targetWindow];
    
    // Same namespace operations are always allowed
    if ([sourceNs isEqual:targetNs]) {
        return YES;
    }
    
    // Root namespace can interact with any namespace
    if (sourceNs.isRoot) {
        return YES;
    }
    
    // Check namespace-specific rules
    NSDictionary *rules = [self rulesForNamespace:sourceNs];
    NSArray *allowedOperations = rules[@"allowedCrossNamespaceOperations"];
    
    if (allowedOperations && [allowedOperations containsObject:operationType]) {
        return YES;
    }
    
    NSLog(@"XNamespaceManager: Blocking %@ operation from namespace %@ to %@",
          operationType, sourceNs.namespaceId, targetNs.namespaceId);
    
    return NO;
}

- (BOOL)shouldBlockReparenting:(xcb_window_t)window toParent:(xcb_window_t)newParent {
    if (!self.crossNamespaceBlockingEnabled) {
        return NO;
    }
    
    BOOL allowed = [self isOperationAllowed:@"reparent" fromWindow:window toWindow:newParent];
    
    if (!allowed) {
        // Record the violation
        [self recordSecurityViolation:@{
            @"type": @"reparent_blocked",
            @"sourceWindow": @(window),
            @"targetWindow": @(newParent),
            @"timestamp": [NSDate date]
        }];
    }
    
    return !allowed;
}

- (BOOL)validateOperation:(NSString *)operation
               fromWindow:(xcb_window_t)source
                 toWindow:(xcb_window_t)target
              showWarning:(BOOL)showWarning {
    
    BOOL allowed = [self isOperationAllowed:operation fromWindow:source toWindow:target];
    
    if (!allowed && showWarning && self.securityWarningsEnabled) {
        XNamespaceInfo *sourceNs = [self namespaceForWindow:source];
        XNamespaceInfo *targetNs = [self namespaceForWindow:target];
        
        NSDictionary *violation = @{
            @"operation": operation,
            @"sourceNamespace": sourceNs.namespaceName,
            @"targetNamespace": targetNs.namespaceName,
            @"sourceWindow": @(source),
            @"targetWindow": @(target)
        };
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showSecurityViolationAlert:violation];
        });
    }
    
    return allowed;
}

- (void)recordSecurityViolation:(NSDictionary *)violationDetails {
    NSMutableDictionary *violation = [violationDetails mutableCopy];
    violation[@"timestamp"] = [NSDate date];
    
    [self.securityViolationLog addObject:violation];
    
    // Keep log size reasonable
    if ([self.securityViolationLog count] > 1000) {
        [self.securityViolationLog removeObjectAtIndex:0];
    }
    
    // Notify delegate
    if ([self.delegate respondsToSelector:@selector(namespaceManager:didDetectSecurityViolation:)]) {
        [self.delegate namespaceManager:self didDetectSecurityViolation:violation];
    }
    
    // Post notification
    [[NSNotificationCenter defaultCenter] postNotificationName:XNamespaceSecurityViolationNotification
                                                        object:self
                                                      userInfo:violation];
    
    NSLog(@"XNamespaceManager: Security violation recorded: %@", violationDetails);
}

#pragma mark - Configuration Management

- (void)saveConfiguration {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Save color mappings
    NSMutableDictionary *colorData = [[NSMutableDictionary alloc] init];
    for (NSString *nsId in self.namespaceColorMap) {
        NSColor *color = self.namespaceColorMap[nsId];
        NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:color];
        colorData[nsId] = archived;
    }
    [defaults setObject:colorData forKey:@"XNamespaceColorMap"];
    
    // Save rules
    [defaults setObject:self.namespaceRulesMap forKey:@"XNamespaceRulesMap"];
    
    // Save settings
    [defaults setBool:self.visualIndicatorsEnabled forKey:@"XNamespaceVisualIndicators"];
    [defaults setBool:self.securityWarningsEnabled forKey:@"XNamespaceSecurityWarnings"];
    [defaults setBool:self.crossNamespaceBlockingEnabled forKey:@"XNamespaceCrossBlocking"];
    
    // Save default namespace
    [defaults setObject:self.defaultNamespace.namespaceId forKey:@"XNamespaceDefaultId"];
    
    [defaults synchronize];
    
    NSLog(@"XNamespaceManager: Configuration saved");
}

- (void)loadConfiguration {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Load color mappings
    NSDictionary *colorData = [defaults objectForKey:@"XNamespaceColorMap"];
    if (colorData) {
        for (NSString *nsId in colorData) {
            NSData *archived = colorData[nsId];
            NSColor *color = [NSKeyedUnarchiver unarchiveObjectWithData:archived];
            if (color) {
                self.namespaceColorMap[nsId] = color;
            }
        }
    }
    
    // Load rules
    NSDictionary *rulesData = [defaults objectForKey:@"XNamespaceRulesMap"];
    if (rulesData) {
        [self.namespaceRulesMap addEntriesFromDictionary:rulesData];
    }
    
    // Load settings
    if ([defaults objectForKey:@"XNamespaceVisualIndicators"]) {
        self.visualIndicatorsEnabled = [defaults boolForKey:@"XNamespaceVisualIndicators"];
    }
    if ([defaults objectForKey:@"XNamespaceSecurityWarnings"]) {
        self.securityWarningsEnabled = [defaults boolForKey:@"XNamespaceSecurityWarnings"];
    }
    if ([defaults objectForKey:@"XNamespaceCrossBlocking"]) {
        self.crossNamespaceBlockingEnabled = [defaults boolForKey:@"XNamespaceCrossBlocking"];
    }
    
    NSLog(@"XNamespaceManager: Configuration loaded");
}

- (NSDictionary *)rulesForNamespace:(XNamespaceInfo *)namespace {
    if (!namespace) {
        return @{};
    }
    return self.namespaceRulesMap[namespace.namespaceId] ?: @{};
}

- (void)setRules:(NSDictionary *)rules forNamespace:(XNamespaceInfo *)namespace {
    if (!namespace) {
        return;
    }
    self.namespaceRulesMap[namespace.namespaceId] = rules ?: @{};
    [self saveConfiguration];
}

- (XNamespaceInfo *)defaultNamespaceForNewClients {
    return self.defaultNamespace;
}

- (void)setDefaultNamespaceForNewClients:(XNamespaceInfo *)namespace {
    if (namespace) {
        self.defaultNamespace = namespace;
        [self saveConfiguration];
    }
}

#pragma mark - GUI Integration

- (NSMenu *)createNamespaceStatusMenu {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Namespaces"];
    
    // Current namespace indicator
    NSMenuItem *currentItem = [[NSMenuItem alloc] initWithTitle:
        [NSString stringWithFormat:@"Current: %@", self.currentNamespace.namespaceName ?: @"Default"]
                                                         action:nil
                                                  keyEquivalent:@""];
    [currentItem setEnabled:NO];
    [menu addItem:currentItem];
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Available namespaces
    NSArray *namespaces = [self queryAvailableNamespaces];
    for (XNamespaceInfo *ns in namespaces) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:ns.namespaceName
                                                      action:@selector(switchToNamespace:)
                                               keyEquivalent:@""];
        [item setTarget:self];
        [item setRepresentedObject:ns];
        
        // Add color indicator
        NSImage *colorSwatch = [[NSImage alloc] initWithSize:NSMakeSize(12, 12)];
        [colorSwatch lockFocus];
        [[self colorForNamespace:ns] set];
        NSRectFill(NSMakeRect(0, 0, 12, 12));
        [colorSwatch unlockFocus];
        [item setImage:colorSwatch];
        
        // Mark current namespace
        if ([ns isEqual:self.currentNamespace]) {
            [item setState:NSOnState];
        }
        
        [menu addItem:item];
    }
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Configuration option
    NSMenuItem *configItem = [[NSMenuItem alloc] initWithTitle:@"Configure Namespaces..."
                                                        action:@selector(showConfigurationPanel)
                                                 keyEquivalent:@","];
    [configItem setTarget:self];
    [menu addItem:configItem];
    
    return menu;
}

- (void)switchToNamespace:(NSMenuItem *)sender {
    XNamespaceInfo *namespace = [sender representedObject];
    if (namespace) {
        [self requestNamespaceSwitch:namespace];
    }
}

- (NSPopUpButton *)createNamespaceSelectorWithTarget:(id)target action:(SEL)action {
    NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 150, 25) pullsDown:NO];
    
    NSArray *namespaces = [self queryAvailableNamespaces];
    for (XNamespaceInfo *ns in namespaces) {
        [popup addItemWithTitle:ns.namespaceName];
        [[popup lastItem] setRepresentedObject:ns];
        
        // Add color indicator
        NSImage *colorSwatch = [[NSImage alloc] initWithSize:NSMakeSize(12, 12)];
        [colorSwatch lockFocus];
        [[self colorForNamespace:ns] set];
        NSRectFill(NSMakeRect(0, 0, 12, 12));
        [colorSwatch unlockFocus];
        [[popup lastItem] setImage:colorSwatch];
    }
    
    [popup setTarget:target];
    [popup setAction:action];
    
    // Select current namespace
    for (NSInteger i = 0; i < [popup numberOfItems]; i++) {
        XNamespaceInfo *ns = [[popup itemAtIndex:i] representedObject];
        if ([ns isEqual:self.currentNamespace]) {
            [popup selectItemAtIndex:i];
            break;
        }
    }
    
    return popup;
}

- (void)showConfigurationPanel {
    if (!self.configPanel) {
        self.configPanel = [[XNamespaceConfigPanel alloc] initWithManager:self];
    }
    [self.configPanel showWindow:nil];
    [[self.configPanel window] makeKeyAndOrderFront:nil];
}

- (void)showNamespaceSwitchDialog {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Switch Namespace"];
    [alert setInformativeText:@"Select a namespace to switch to:"];
    
    // Add namespace selector
    NSPopUpButton *selector = [self createNamespaceSelectorWithTarget:nil action:nil];
    [alert setAccessoryView:selector];
    
    [alert addButtonWithTitle:@"Switch"];
    [alert addButtonWithTitle:@"Cancel"];
    
    NSModalResponse response = [alert runModal];
    
    if (response == NSAlertFirstButtonReturn) {
        XNamespaceInfo *selected = [[selector selectedItem] representedObject];
        if (selected) {
            [self requestNamespaceSwitch:selected];
        }
    }
}

- (void)showSecurityViolationAlert:(NSDictionary *)violation {
    if (!self.securityWarningsEnabled) {
        return;
    }
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert setMessageText:@"Cross-Namespace Operation Blocked"];
    [alert setInformativeText:[NSString stringWithFormat:
        @"An operation from namespace '%@' to namespace '%@' was blocked for security reasons.\n\nOperation: %@",
        violation[@"sourceNamespace"] ?: @"Unknown",
        violation[@"targetNamespace"] ?: @"Unknown",
        violation[@"operation"] ?: @"Unknown"]];
    
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Don't Show Again"];
    
    NSModalResponse response = [alert runModal];
    
    if (response == NSAlertSecondButtonReturn) {
        self.securityWarningsEnabled = NO;
        [self saveConfiguration];
    }
}

#pragma mark - Event Handling

- (BOOL)handleXCBEvent:(xcb_generic_event_t *)event {
    if (!event) {
        return NO;
    }
    
    uint8_t responseType = event->response_type & ~0x80;
    
    switch (responseType) {
        case XCB_PROPERTY_NOTIFY:
            [self handlePropertyNotify:(xcb_property_notify_event_t *)event];
            return YES;
            
        case XCB_CLIENT_MESSAGE:
            [self handleClientMessage:(xcb_client_message_event_t *)event];
            return YES;
            
        default:
            // Check if this is an XNamespace extension event
            if (self.extensionAvailable && 
                responseType >= self.extensionFirstEvent &&
                responseType < self.extensionFirstEvent + 10) {
                NSLog(@"XNamespaceManager: Handling extension event %d", responseType);
                // Handle XNamespace-specific events here
                return YES;
            }
            break;
    }
    
    return NO;
}

- (void)handlePropertyNotify:(xcb_property_notify_event_t *)event {
    if (!event) {
        return;
    }
    
    // Check if this is a namespace-related property change
    if (event->atom == self.atomWindowNamespace ||
        event->atom == self.atomClientNamespace) {
        
        xcb_window_t windowId = event->window;
        
        // Clear cached namespace for this window
        [self.windowNamespaceMap removeObjectForKey:@(windowId)];
        
        // Re-query namespace
        XNamespaceInfo *newNs = [self namespaceForWindow:windowId];
        
        NSLog(@"XNamespaceManager: Window %u namespace changed to %@", windowId, newNs.namespaceId);
        
        // Notify delegate
        if ([self.delegate respondsToSelector:@selector(namespaceManager:didAssignWindow:toNamespace:)]) {
            [self.delegate namespaceManager:self didAssignWindow:windowId toNamespace:newNs];
        }
        
        // Post notification
        [[NSNotificationCenter defaultCenter] postNotificationName:XNamespaceWindowAssignedNotification
                                                            object:self
                                                          userInfo:@{
                                                              @"windowId": @(windowId),
                                                              @"namespace": newNs
                                                          }];
    }
}

- (void)handleClientMessage:(xcb_client_message_event_t *)event {
    if (!event) {
        return;
    }
    
    // Handle namespace switch responses
    if (event->type == self.atomSwitchRequest) {
        NSLog(@"XNamespaceManager: Received namespace switch response");
        // Process switch response
    }
}

#pragma mark - Cleanup

- (void)cleanup {
    [self saveConfiguration];
    
    [self.namespaceCache removeAllObjects];
    [self.windowNamespaceMap removeAllObjects];
    [self.securityViolationLog removeAllObjects];
    
    if (self.configPanel) {
        [[self.configPanel window] close];
        self.configPanel = nil;
    }
    
    NSLog(@"XNamespaceManager: Cleanup completed");
}

- (void)dealloc {
    [self cleanup];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
