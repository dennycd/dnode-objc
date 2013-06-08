//
//  TestClient.m
//  dnode-objc
//
//  Created by Denny C. Dai on 2013-06-07.
//  Copyright (c) 2013 Denny C. Dai. All rights reserved.
//

#import "TestClient.h"


@implementation TestClient

-(void)foo
{
    id arg = @[@"hello from client"];
    CALL_SERVER_METHOD(echo, arg);
}

//the direct call from remote dnode
DEFINE_CLIENT_METHOD(hello) {
    NSLog(@"hello: %@ ", args);
}

//the callback from a previous local-to-remote call
DEFINE_SERVER_METHOD_WITH_CALLBACK(echo) {
    NSLog(@"callback from server %@", args);
}

@end
