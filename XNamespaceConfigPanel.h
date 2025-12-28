//
//  XNamespaceConfigPanel.h
//  uroswm - XNamespace Configuration Panel
//
//  A GNUstep-based configuration interface for managing XNamespace settings,
//  including namespace rules, colors, and security policies.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@class XNamespaceManager;
@class XNamespaceInfo;

@interface XNamespaceConfigPanel : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>

// Reference to the namespace manager
@property (weak, nonatomic) XNamespaceManager *namespaceManager;

// UI Components
@property (strong, nonatomic) NSTableView *namespaceTableView;
@property (strong, nonatomic) NSTableView *rulesTableView;
@property (strong, nonatomic) NSColorWell *colorWell;
@property (strong, nonatomic) NSTextField *namespaceNameField;
@property (strong, nonatomic) NSButton *visualIndicatorsCheckbox;
@property (strong, nonatomic) NSButton *securityWarningsCheckbox;
@property (strong, nonatomic) NSButton *crossBlockingCheckbox;
@property (strong, nonatomic) NSPopUpButton *defaultNamespacePopup;

// Currently selected namespace
@property (strong, nonatomic) XNamespaceInfo *selectedNamespace;

// Namespace data
@property (strong, nonatomic) NSMutableArray<XNamespaceInfo *> *namespaces;

// Initialization
- (instancetype)initWithManager:(XNamespaceManager *)manager;

// Actions
- (IBAction)applySettings:(id)sender;
- (IBAction)resetToDefaults:(id)sender;
- (IBAction)colorChanged:(id)sender;
- (IBAction)addRule:(id)sender;
- (IBAction)removeRule:(id)sender;
- (IBAction)refreshNamespaces:(id)sender;

// Panel management
- (void)reloadData;

@end
