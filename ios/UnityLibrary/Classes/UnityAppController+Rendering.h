#pragma once

#include "UnityForwardDecls.h"
#include "UnityAppController.h"
#include "UnityRendering.h"

#if UNITY_USES_METAL_DISPLAY_LINK
@interface UnityAppController (Rendering) <CAMetalDisplayLinkDelegate>
#else
@interface UnityAppController (Rendering)
#endif

- (void)createDisplayLink;
- (void)repaintDisplayLink;
- (void)destroyDisplayLink;
- (void)destroyCADisplayLink;

- (void)pauseDisplayLink;
- (void)unpauseDisplayLink;

- (void)repaint;

#if UNITY_USES_METAL_DISPLAY_LINK
- (void)metalDisplayLink:(CAMetalDisplayLink *)link needsUpdate:(CAMetalDisplayLinkUpdate *)update API_AVAILABLE(ios(17.0), tvos(17.0));
#endif

- (void)selectRenderingAPI;
@property (readonly, nonatomic) UnityRenderingAPI   renderingAPI;

@end

// helper to run unity loop along with proper handling of the rendering
#ifdef __cplusplus
extern "C" {
#endif

void UnityRepaint();

#ifdef __cplusplus
} // extern "C"
#endif
