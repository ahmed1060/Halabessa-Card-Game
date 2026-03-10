#import "UnityScene.h"
#import "UnityViewControllerBase.h"
#include "UnityAppController.h"

@implementation UnityScene

- (void)sceneDidBecomeActive:(UIScene *)scene {
    ::printf("-> sceneDidBecomeActive()\n");
    auto appController = GetAppController();
    if ([appController respondsToSelector:@selector(applicationDidBecomeActive:)])
    {
        [appController applicationDidBecomeActive:UIApplication.sharedApplication];
    }
}

- (void)sceneWillResignActive:(UIScene *)scene {
    ::printf("-> sceneWillResignActive()\n");
    auto appController = GetAppController();
    if ([appController respondsToSelector:@selector(applicationWillResignActive:)])
    {
        [appController applicationWillResignActive:UIApplication.sharedApplication];
    }
}

- (void)sceneWillEnterForeground:(UIScene *)scene {
    ::printf("-> sceneWillEnterForeground()\n");
    auto appController = GetAppController();
    UIWindowScene *windowScene = (UIWindowScene *)scene;
    [appController initUnityWithScene: windowScene];

    if ([appController respondsToSelector:@selector(applicationWillEnterForeground:)])
    {
        [appController applicationWillEnterForeground:UIApplication.sharedApplication];
    }
}

- (void)sceneDidEnterBackground:(UIScene *)scene {
    ::printf("-> sceneDidEnterBackground()\n");
    auto appController = GetAppController();
    if ([appController respondsToSelector:@selector(applicationDidEnterBackground:)])
    {
        [appController applicationDidEnterBackground:UIApplication.sharedApplication];
    }
}

@end
