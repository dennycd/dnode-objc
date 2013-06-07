//
//  AppDelegate.m
//  dnode-ios
//
//  Created by Denny C. Dai on 2013-06-07.
//  Copyright (c) 2013 Denny C. Dai. All rights reserved.
//

#import "AppDelegate.h"
#import "TestClient.h"

@interface AppDelegate()<DNodeDelegate>
{
    TestClient* _client;
}
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.

    _client = [[TestClient alloc] init];
    [_client addListener:self CallbackQueue:dispatch_get_main_queue()];
    [_client connectToHost:@"192.168.1.67" Port:8000 Callback:^(BOOL success, NSNumber* err){
        NSLog(@"connected %d with err %@", success, err);
    }];
    
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark - serverApiUpdated

//server API ready
-(void)remoteReady
{
    //NSAssert(dispatch_get_current_queue() == dispatch_get_main_queue(), @"not running on main queue");
    NSLog(@"remoteReady");
    [_client foo];
}


@end
