//
//  AppDelegate.m
//  dnode-objc
//
//  Created by Denny C. Dai on 2013-06-06.
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

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    _client = [[TestClient alloc] init];
    [_client addListener:self CallbackQueue:dispatch_get_main_queue()];
    [_client connectToHost:@"192.168.1.67" Port:8000 Callback:^(BOOL success, NSNumber* err){
        NSLog(@"connected %d with err %@", success, err);
    }];

}

#pragma mark - serverApiUpdated

//server API ready 
-(void)remoteReady
{
    NSAssert(dispatch_get_current_queue() == dispatch_get_main_queue(), @"not running on main queue");
    NSLog(@"remoteReady");

    [_client foo];
}

@end
