//
//  URSWindowSwitcherOverlay.h
//  uroswm - Alt-Tab Window Switcher Overlay
//
//  Visual overlay showing application icons and names during Alt-Tab cycling
//  Displays a horizontal strip of icons with app names below
//

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>

@interface URSWindowSwitcherOverlay : NSWindow

// Singleton access
+ (instancetype)sharedOverlay;

// Display management
- (void)showCenteredOnScreen;
- (void)hide;

// Update display with current titles and selection
- (void)updateWithTitles:(NSArray *)titles currentIndex:(NSInteger)index;

@end
