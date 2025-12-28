//
//  XNamespaceConfigPanel.m
//  uroswm - XNamespace Configuration Panel
//
//  Implementation of the GNUstep-based configuration interface for
//  managing XNamespace settings.
//

#import "XNamespaceConfigPanel.h"
#import "XNamespaceManager.h"

@interface XNamespaceConfigPanel ()

@property (strong, nonatomic) NSMutableArray *currentRules;
@property (strong, nonatomic) NSTabView *tabView;

@end


@implementation XNamespaceConfigPanel

#pragma mark - Initialization

- (instancetype)initWithManager:(XNamespaceManager *)manager {
    // Create the window
    NSRect windowRect = NSMakeRect(0, 0, 600, 500);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:windowRect
                                                   styleMask:NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    [window setTitle:@"XNamespace Configuration"];
    [window setMinSize:NSMakeSize(500, 400)];
    
    self = [super initWithWindow:window];
    if (self) {
        _namespaceManager = manager;
        _namespaces = [[NSMutableArray alloc] init];
        _currentRules = [[NSMutableArray alloc] init];
        
        [self setupUI];
        [self reloadData];
        
        // Center window on screen
        [window center];
    }
    return self;
}

#pragma mark - UI Setup

- (void)setupUI {
    NSView *contentView = [[self window] contentView];
    
    // Create tab view for different configuration sections
    _tabView = [[NSTabView alloc] initWithFrame:NSMakeRect(10, 50, 580, 440)];
    [_tabView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    
    // Tab 1: Namespaces
    NSTabViewItem *namespacesTab = [[NSTabViewItem alloc] initWithIdentifier:@"namespaces"];
    [namespacesTab setLabel:@"Namespaces"];
    [namespacesTab setView:[self createNamespacesTabView]];
    [_tabView addTabViewItem:namespacesTab];
    
    // Tab 2: Rules
    NSTabViewItem *rulesTab = [[NSTabViewItem alloc] initWithIdentifier:@"rules"];
    [rulesTab setLabel:@"Rules"];
    [rulesTab setView:[self createRulesTabView]];
    [_tabView addTabViewItem:rulesTab];
    
    // Tab 3: Settings
    NSTabViewItem *settingsTab = [[NSTabViewItem alloc] initWithIdentifier:@"settings"];
    [settingsTab setLabel:@"Settings"];
    [settingsTab setView:[self createSettingsTabView]];
    [_tabView addTabViewItem:settingsTab];
    
    // Tab 4: Security Log
    NSTabViewItem *securityTab = [[NSTabViewItem alloc] initWithIdentifier:@"security"];
    [securityTab setLabel:@"Security Log"];
    [securityTab setView:[self createSecurityLogTabView]];
    [_tabView addTabViewItem:securityTab];
    
    [contentView addSubview:_tabView];
    
    // Bottom buttons
    [self setupBottomButtons:contentView];
}

- (NSView *)createNamespacesTabView {
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 560, 400)];
    
    // Namespace list table
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(10, 100, 300, 280)];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setBorderType:NSBezelBorder];
    [scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    
    _namespaceTableView = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 280, 260)];
    [_namespaceTableView setDataSource:self];
    [_namespaceTableView setDelegate:self];
    [_namespaceTableView setRowHeight:24];
    
    // Color column
    NSTableColumn *colorColumn = [[NSTableColumn alloc] initWithIdentifier:@"color"];
    [colorColumn setWidth:30];
    [[colorColumn headerCell] setStringValue:@""];
    [_namespaceTableView addTableColumn:colorColumn];
    
    // Name column
    NSTableColumn *nameColumn = [[NSTableColumn alloc] initWithIdentifier:@"name"];
    [nameColumn setWidth:150];
    [[nameColumn headerCell] setStringValue:@"Namespace"];
    [_namespaceTableView addTableColumn:nameColumn];
    
    // ID column
    NSTableColumn *idColumn = [[NSTableColumn alloc] initWithIdentifier:@"id"];
    [idColumn setWidth:80];
    [[idColumn headerCell] setStringValue:@"ID"];
    [_namespaceTableView addTableColumn:idColumn];
    
    [scrollView setDocumentView:_namespaceTableView];
    [view addSubview:scrollView];
    
    // Namespace details panel on the right
    NSBox *detailsBox = [[NSBox alloc] initWithFrame:NSMakeRect(320, 100, 230, 280)];
    [detailsBox setTitle:@"Details"];
    [detailsBox setAutoresizingMask:NSViewMinXMargin | NSViewHeightSizable];
    
    // Name field
    NSTextField *nameLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 230, 60, 20)];
    [nameLabel setStringValue:@"Name:"];
    [nameLabel setBordered:NO];
    [nameLabel setEditable:NO];
    [nameLabel setDrawsBackground:NO];
    [[detailsBox contentView] addSubview:nameLabel];
    
    _namespaceNameField = [[NSTextField alloc] initWithFrame:NSMakeRect(70, 230, 140, 22)];
    [[detailsBox contentView] addSubview:_namespaceNameField];
    
    // Color picker
    NSTextField *colorLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 195, 60, 20)];
    [colorLabel setStringValue:@"Color:"];
    [colorLabel setBordered:NO];
    [colorLabel setEditable:NO];
    [colorLabel setDrawsBackground:NO];
    [[detailsBox contentView] addSubview:colorLabel];
    
    _colorWell = [[NSColorWell alloc] initWithFrame:NSMakeRect(70, 190, 50, 30)];
    [_colorWell setTarget:self];
    [_colorWell setAction:@selector(colorChanged:)];
    [[detailsBox contentView] addSubview:_colorWell];
    
    // Namespace info
    NSTextField *infoLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 100, 200, 80)];
    [infoLabel setStringValue:@"Select a namespace to view and edit its settings."];
    [infoLabel setBordered:NO];
    [infoLabel setEditable:NO];
    [infoLabel setDrawsBackground:NO];
    [[infoLabel cell] setWraps:YES];
    [[detailsBox contentView] addSubview:infoLabel];
    
    [view addSubview:detailsBox];
    
    // Refresh button
    NSButton *refreshButton = [[NSButton alloc] initWithFrame:NSMakeRect(10, 60, 100, 30)];
    [refreshButton setTitle:@"Refresh"];
    [refreshButton setBezelStyle:NSRoundedBezelStyle];
    [refreshButton setTarget:self];
    [refreshButton setAction:@selector(refreshNamespaces:)];
    [view addSubview:refreshButton];
    
    // Extension status
    NSTextField *statusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(120, 65, 300, 20)];
    [statusLabel setBordered:NO];
    [statusLabel setEditable:NO];
    [statusLabel setDrawsBackground:NO];
    
    if (_namespaceManager.extensionAvailable) {
        [statusLabel setStringValue:@"✓ XNamespace extension available"];
        [statusLabel setTextColor:[NSColor colorWithCalibratedRed:0.0 green:0.6 blue:0.0 alpha:1.0]];
    } else {
        [statusLabel setStringValue:@"⚠ XNamespace extension not available (using simulation)"];
        [statusLabel setTextColor:[NSColor colorWithCalibratedRed:0.8 green:0.5 blue:0.0 alpha:1.0]];
    }
    [view addSubview:statusLabel];
    
    return view;
}

- (NSView *)createRulesTabView {
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 560, 400)];
    
    // Rules description
    NSTextField *descLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 350, 540, 40)];
    [descLabel setStringValue:@"Configure rules for cross-namespace operations. Rules define which operations are allowed between different namespaces."];
    [descLabel setBordered:NO];
    [descLabel setEditable:NO];
    [descLabel setDrawsBackground:NO];
    [[descLabel cell] setWraps:YES];
    [view addSubview:descLabel];
    
    // Rules table
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(10, 60, 540, 280)];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setBorderType:NSBezelBorder];
    [scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    
    _rulesTableView = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 520, 260)];
    [_rulesTableView setDataSource:self];
    [_rulesTableView setDelegate:self];
    [_rulesTableView setRowHeight:24];
    
    // Source namespace column
    NSTableColumn *sourceColumn = [[NSTableColumn alloc] initWithIdentifier:@"source"];
    [sourceColumn setWidth:150];
    [[sourceColumn headerCell] setStringValue:@"Source Namespace"];
    [_rulesTableView addTableColumn:sourceColumn];
    
    // Target namespace column
    NSTableColumn *targetColumn = [[NSTableColumn alloc] initWithIdentifier:@"target"];
    [targetColumn setWidth:150];
    [[targetColumn headerCell] setStringValue:@"Target Namespace"];
    [_rulesTableView addTableColumn:targetColumn];
    
    // Operation column
    NSTableColumn *opColumn = [[NSTableColumn alloc] initWithIdentifier:@"operation"];
    [opColumn setWidth:100];
    [[opColumn headerCell] setStringValue:@"Operation"];
    [_rulesTableView addTableColumn:opColumn];
    
    // Allowed column
    NSTableColumn *allowedColumn = [[NSTableColumn alloc] initWithIdentifier:@"allowed"];
    [allowedColumn setWidth:60];
    [[allowedColumn headerCell] setStringValue:@"Allowed"];
    [_rulesTableView addTableColumn:allowedColumn];
    
    [scrollView setDocumentView:_rulesTableView];
    [view addSubview:scrollView];
    
    // Add/Remove buttons
    NSButton *addButton = [[NSButton alloc] initWithFrame:NSMakeRect(10, 20, 80, 30)];
    [addButton setTitle:@"Add Rule"];
    [addButton setBezelStyle:NSRoundedBezelStyle];
    [addButton setTarget:self];
    [addButton setAction:@selector(addRule:)];
    [view addSubview:addButton];
    
    NSButton *removeButton = [[NSButton alloc] initWithFrame:NSMakeRect(100, 20, 100, 30)];
    [removeButton setTitle:@"Remove Rule"];
    [removeButton setBezelStyle:NSRoundedBezelStyle];
    [removeButton setTarget:self];
    [removeButton setAction:@selector(removeRule:)];
    [view addSubview:removeButton];
    
    return view;
}

- (NSView *)createSettingsTabView {
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 560, 400)];
    
    // Visual indicators section
    NSBox *visualBox = [[NSBox alloc] initWithFrame:NSMakeRect(10, 280, 540, 100)];
    [visualBox setTitle:@"Visual Indicators"];
    
    _visualIndicatorsCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(20, 40, 400, 20)];
    [_visualIndicatorsCheckbox setButtonType:NSSwitchButton];
    [_visualIndicatorsCheckbox setTitle:@"Enable color-coded window borders for namespace indication"];
    [_visualIndicatorsCheckbox setState:_namespaceManager.visualIndicatorsEnabled ? NSOnState : NSOffState];
    [[visualBox contentView] addSubview:_visualIndicatorsCheckbox];
    
    [view addSubview:visualBox];
    
    // Security section
    NSBox *securityBox = [[NSBox alloc] initWithFrame:NSMakeRect(10, 140, 540, 130)];
    [securityBox setTitle:@"Security"];
    
    _securityWarningsCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(20, 70, 400, 20)];
    [_securityWarningsCheckbox setButtonType:NSSwitchButton];
    [_securityWarningsCheckbox setTitle:@"Show warning alerts for blocked cross-namespace operations"];
    [_securityWarningsCheckbox setState:_namespaceManager.securityWarningsEnabled ? NSOnState : NSOffState];
    [[securityBox contentView] addSubview:_securityWarningsCheckbox];
    
    _crossBlockingCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(20, 40, 400, 20)];
    [_crossBlockingCheckbox setButtonType:NSSwitchButton];
    [_crossBlockingCheckbox setTitle:@"Block cross-namespace window operations (reparenting, etc.)"];
    [_crossBlockingCheckbox setState:_namespaceManager.crossNamespaceBlockingEnabled ? NSOnState : NSOffState];
    [[securityBox contentView] addSubview:_crossBlockingCheckbox];
    
    [view addSubview:securityBox];
    
    // Default namespace section
    NSBox *defaultBox = [[NSBox alloc] initWithFrame:NSMakeRect(10, 60, 540, 70)];
    [defaultBox setTitle:@"Default Namespace"];
    
    NSTextField *defaultLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 20, 150, 20)];
    [defaultLabel setStringValue:@"Default for new clients:"];
    [defaultLabel setBordered:NO];
    [defaultLabel setEditable:NO];
    [defaultLabel setDrawsBackground:NO];
    [[defaultBox contentView] addSubview:defaultLabel];
    
    _defaultNamespacePopup = [_namespaceManager createNamespaceSelectorWithTarget:self action:nil];
    [_defaultNamespacePopup setFrame:NSMakeRect(180, 15, 150, 25)];
    [[defaultBox contentView] addSubview:_defaultNamespacePopup];
    
    [view addSubview:defaultBox];
    
    return view;
}

- (NSView *)createSecurityLogTabView {
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 560, 400)];
    
    // Security log description
    NSTextField *descLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 360, 540, 30)];
    [descLabel setStringValue:@"Recent cross-namespace security violations:"];
    [descLabel setBordered:NO];
    [descLabel setEditable:NO];
    [descLabel setDrawsBackground:NO];
    [view addSubview:descLabel];
    
    // Log text view
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(10, 60, 540, 290)];
    [scrollView setHasVerticalScroller:YES];
    [scrollView setBorderType:NSBezelBorder];
    [scrollView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    
    NSTextView *logView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 520, 270)];
    [logView setEditable:NO];
    [logView setFont:[NSFont userFixedPitchFontOfSize:11]];
    
    // Populate with security log entries
    NSMutableString *logText = [[NSMutableString alloc] init];
    // TODO: Get actual security log entries from manager
    [logText appendString:@"No security violations recorded.\n"];
    [logView setString:logText];
    
    [scrollView setDocumentView:logView];
    [view addSubview:scrollView];
    
    // Clear log button
    NSButton *clearButton = [[NSButton alloc] initWithFrame:NSMakeRect(10, 20, 100, 30)];
    [clearButton setTitle:@"Clear Log"];
    [clearButton setBezelStyle:NSRoundedBezelStyle];
    [view addSubview:clearButton];
    
    return view;
}

- (void)setupBottomButtons:(NSView *)contentView {
    // Apply button
    NSButton *applyButton = [[NSButton alloc] initWithFrame:NSMakeRect(500, 10, 80, 30)];
    [applyButton setTitle:@"Apply"];
    [applyButton setBezelStyle:NSRoundedBezelStyle];
    [applyButton setTarget:self];
    [applyButton setAction:@selector(applySettings:)];
    [applyButton setKeyEquivalent:@"\r"];
    [applyButton setAutoresizingMask:NSViewMinXMargin | NSViewMaxYMargin];
    [contentView addSubview:applyButton];
    
    // Reset button
    NSButton *resetButton = [[NSButton alloc] initWithFrame:NSMakeRect(410, 10, 80, 30)];
    [resetButton setTitle:@"Reset"];
    [resetButton setBezelStyle:NSRoundedBezelStyle];
    [resetButton setTarget:self];
    [resetButton setAction:@selector(resetToDefaults:)];
    [resetButton setAutoresizingMask:NSViewMinXMargin | NSViewMaxYMargin];
    [contentView addSubview:resetButton];
}

#pragma mark - Data Loading

- (void)reloadData {
    [_namespaces removeAllObjects];
    
    NSArray *available = [_namespaceManager queryAvailableNamespaces];
    [_namespaces addObjectsFromArray:available];
    
    [_namespaceTableView reloadData];
    
    // Update settings checkboxes
    [_visualIndicatorsCheckbox setState:_namespaceManager.visualIndicatorsEnabled ? NSOnState : NSOffState];
    [_securityWarningsCheckbox setState:_namespaceManager.securityWarningsEnabled ? NSOnState : NSOffState];
    [_crossBlockingCheckbox setState:_namespaceManager.crossNamespaceBlockingEnabled ? NSOnState : NSOffState];
    
    NSLog(@"XNamespaceConfigPanel: Reloaded %lu namespaces", (unsigned long)[_namespaces count]);
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (tableView == _namespaceTableView) {
        return [_namespaces count];
    } else if (tableView == _rulesTableView) {
        return [_currentRules count];
    }
    return 0;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (tableView == _namespaceTableView) {
        if (row >= (NSInteger)[_namespaces count]) return nil;
        
        XNamespaceInfo *ns = _namespaces[row];
        NSString *columnId = [tableColumn identifier];
        
        if ([columnId isEqualToString:@"name"]) {
            return ns.namespaceName;
        } else if ([columnId isEqualToString:@"id"]) {
            return ns.namespaceId;
        } else if ([columnId isEqualToString:@"color"]) {
            // Return empty string, we'll draw the color in willDisplayCell
            return @"";
        }
    } else if (tableView == _rulesTableView) {
        if (row >= (NSInteger)[_currentRules count]) return nil;
        
        NSDictionary *rule = _currentRules[row];
        NSString *columnId = [tableColumn identifier];
        
        return rule[columnId] ?: @"";
    }
    
    return nil;
}

#pragma mark - NSTableViewDelegate

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSTableView *tableView = [notification object];
    
    if (tableView == _namespaceTableView) {
        NSInteger selectedRow = [tableView selectedRow];
        
        if (selectedRow >= 0 && selectedRow < (NSInteger)[_namespaces count]) {
            _selectedNamespace = _namespaces[selectedRow];
            
            // Update details panel
            [_namespaceNameField setStringValue:_selectedNamespace.namespaceName ?: @""];
            [_colorWell setColor:[_namespaceManager colorForNamespace:_selectedNamespace]];
            
            NSLog(@"XNamespaceConfigPanel: Selected namespace %@", _selectedNamespace.namespaceId);
        } else {
            _selectedNamespace = nil;
            [_namespaceNameField setStringValue:@""];
        }
    }
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (tableView == _namespaceTableView && 
        [[tableColumn identifier] isEqualToString:@"color"]) {
        
        if (row < (NSInteger)[_namespaces count]) {
            XNamespaceInfo *ns = _namespaces[row];
            NSColor *color = [_namespaceManager colorForNamespace:ns];
            
            // Create a colored image for the cell
            NSImage *colorImage = [[NSImage alloc] initWithSize:NSMakeSize(16, 16)];
            [colorImage lockFocus];
            [color set];
            NSRectFill(NSMakeRect(2, 2, 12, 12));
            [[NSColor blackColor] set];
            NSFrameRect(NSMakeRect(2, 2, 12, 12));
            [colorImage unlockFocus];
            
            if ([cell isKindOfClass:[NSImageCell class]]) {
                [(NSImageCell *)cell setImage:colorImage];
            }
        }
    }
}

#pragma mark - Actions

- (IBAction)applySettings:(id)sender {
    // Apply visual indicator setting
    _namespaceManager.visualIndicatorsEnabled = ([_visualIndicatorsCheckbox state] == NSOnState);
    
    // Apply security settings
    _namespaceManager.securityWarningsEnabled = ([_securityWarningsCheckbox state] == NSOnState);
    _namespaceManager.crossNamespaceBlockingEnabled = ([_crossBlockingCheckbox state] == NSOnState);
    
    // Apply selected namespace color
    if (_selectedNamespace && _colorWell) {
        [_namespaceManager setColor:[_colorWell color] forNamespace:_selectedNamespace];
    }
    
    // Apply default namespace
    if (_defaultNamespacePopup) {
        XNamespaceInfo *defaultNs = [[_defaultNamespacePopup selectedItem] representedObject];
        if (defaultNs) {
            [_namespaceManager setDefaultNamespaceForNewClients:defaultNs];
        }
    }
    
    // Save configuration
    [_namespaceManager saveConfiguration];
    
    NSLog(@"XNamespaceConfigPanel: Settings applied");
    
    // Show confirmation
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Settings Applied"];
    [alert setInformativeText:@"XNamespace configuration has been saved."];
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

- (IBAction)resetToDefaults:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Reset to Defaults?"];
    [alert setInformativeText:@"This will reset all XNamespace settings to their default values. This action cannot be undone."];
    [alert addButtonWithTitle:@"Reset"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert setAlertStyle:NSWarningAlertStyle];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        // Reset settings
        _namespaceManager.visualIndicatorsEnabled = YES;
        _namespaceManager.securityWarningsEnabled = YES;
        _namespaceManager.crossNamespaceBlockingEnabled = YES;
        
        [_namespaceManager saveConfiguration];
        [self reloadData];
        
        NSLog(@"XNamespaceConfigPanel: Settings reset to defaults");
    }
}

- (IBAction)colorChanged:(id)sender {
    if (_selectedNamespace && _colorWell) {
        [_namespaceManager setColor:[_colorWell color] forNamespace:_selectedNamespace];
        [_namespaceTableView reloadData];
    }
}

- (IBAction)addRule:(id)sender {
    NSLog(@"XNamespaceConfigPanel: Add rule requested");
    
    // Create a simple dialog for adding a rule
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:@"Add Cross-Namespace Rule"];
    [alert setInformativeText:@"Configure rules for cross-namespace operations in the Rules tab."];
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
    
    // TODO: Implement full rule creation dialog
}

- (IBAction)removeRule:(id)sender {
    NSInteger selectedRow = [_rulesTableView selectedRow];
    
    if (selectedRow >= 0 && selectedRow < (NSInteger)[_currentRules count]) {
        [_currentRules removeObjectAtIndex:selectedRow];
        [_rulesTableView reloadData];
        NSLog(@"XNamespaceConfigPanel: Rule removed at index %ld", (long)selectedRow);
    }
}

- (IBAction)refreshNamespaces:(id)sender {
    [self reloadData];
    
    NSLog(@"XNamespaceConfigPanel: Namespaces refreshed");
}

@end
