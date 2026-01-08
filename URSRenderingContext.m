//
//  URSRenderingContext.m
//  uroswm - Unified Damage Notification
//
//  Implementation of automatic compositor notification for rendering operations.
//

#import "URSRenderingContext.h"
#import "URSCompositingManager.h"

@interface URSRenderingContext ()

@property (assign, nonatomic) xcb_window_t windowId;
@property (assign, nonatomic) BOOL active;
@property (assign, nonatomic) NSRect damageRegion;
@property (assign, nonatomic) BOOL hasDamageRegion;

@end

@implementation URSRenderingContext

#pragma mark - Initialization

- (instancetype)initWithWindow:(xcb_window_t)windowId {
    self = [super init];
    if (self) {
        _windowId = windowId;
        _active = NO;
        _hasDamageRegion = NO;
        _damageRegion = NSZeroRect;
        [self beginRendering];
    }
    return self;
}

- (instancetype)initWithWindow:(xcb_window_t)windowId 
                        region:(NSRect)damageRegion {
    self = [super init];
    if (self) {
        _windowId = windowId;
        _active = NO;
        _hasDamageRegion = YES;
        _damageRegion = damageRegion;
        [self beginRendering];
    }
    return self;
}

#pragma mark - Rendering Control

- (void)beginRendering {
    if (_active) {
        return;  // Already active
    }
    _active = YES;
    // Context is now active - rendering can proceed
}

- (void)endRendering {
    if (!_active) {
        return;  // Already ended
    }
    _active = NO;
    
    // Notify compositor that this window needs repainting
    URSCompositingManager *compositor = [URSCompositingManager sharedManager];
    if ([compositor compositingActive]) {
        [compositor updateWindow:_windowId];
        [compositor scheduleComposite];
    }
}

- (void)addDamageRect:(NSRect)rect {
    if (_hasDamageRegion) {
        // Union with existing damage region
        _damageRegion = NSUnionRect(_damageRegion, rect);
    } else {
        _damageRegion = rect;
        _hasDamageRegion = YES;
    }
}

#pragma mark - Cleanup

- (void)dealloc {
    // Auto-notify on context release if still active
    if (_active) {
        [self endRendering];
    }
}

#pragma mark - Convenience Class Methods

+ (void)notifyRenderingComplete:(xcb_window_t)windowId {
    URSCompositingManager *compositor = [URSCompositingManager sharedManager];
    if ([compositor compositingActive]) {
        [compositor updateWindow:windowId];
        [compositor scheduleComposite];
    }
}

+ (void)notifyRenderingComplete:(xcb_window_t)windowId 
                         region:(NSRect)damageRegion {
    // For now, we notify the whole window
    // Future optimization: use the specific region
    [self notifyRenderingComplete:windowId];
}

@end
