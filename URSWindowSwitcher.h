//
//  URSWindowSwitcher.h
//  uroswm - Alt-Tab Window Switching
//
//  Created for implementing Alt-Tab and Shift-Alt-Tab functionality
//
//  Manages window cycling and focus switching for keyboard navigation
//

#import <Foundation/Foundation.h>
#import <XCBKit/XCBConnection.h>
#import <XCBKit/XCBWindow.h>
#import <XCBKit/XCBFrame.h>

@interface URSWindowSwitcher : NSObject

@property (strong, nonatomic) XCBConnection *connection;
@property (strong, nonatomic) NSMutableArray *windowStack;  // Ordered list of windows (most recent first)
@property (assign, nonatomic) NSInteger currentIndex;        // Current position in window stack during switching
@property (assign, nonatomic) BOOL isSwitching;             // Whether we're in the middle of switching
@property (strong, nonatomic) XCBFrame *previousFocus;      // Window that had focus before switching started

// Singleton access
+ (instancetype)sharedSwitcherWithConnection:(XCBConnection *)connection;

// Window stack management
- (void)updateWindowStack;
- (void)addWindowToStack:(XCBFrame *)frame;
- (void)removeWindowFromStack:(XCBFrame *)frame;
- (void)bringWindowToFront:(XCBFrame *)frame;

// Switching operations
- (void)startSwitching;
- (void)cycleForward;
- (void)cycleBackward;
- (void)completeSwitching;
- (void)cancelSwitching;

// Helper methods
- (NSArray *)getManagedWindows;
- (void)focusWindow:(XCBFrame *)frame;
- (XCBFrame *)getCurrentFocusedWindow;

@end
