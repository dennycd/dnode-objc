# DNode | ObjectiveC implementation for OSX and iOS

An Objective-C native implementation of [dnode](http://github.com/substack/dnode) asynchronous RPC protocol. It uses the following library 
* [CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket) for TCP networking
* [SBJson](https://github.com/stig/json-framework) for JSON stream handling

## Usage

Start by subclassing DNode and define your local dnode interface in a header file.

```objective-c
#import "DNode.h"

@interface TestClient : DNode
-(void)foo; //the method your would like to call on remote
@end
```

To expose your local dnode interface to the remote, use C++ macro `DEFINE_CLIENT_METHOD(local_name)`. For example
```objective-c
//the direct call from remote dnode
DEFINE_CLIENT_METHOD(hello) {
    NSLog(@"hello from server: %@ ", args); 
}
```

To explicitly declare a method on remote and receive callback, use `DEFINE_SERVER_METHOD_WITH_CALLBACK(remote_name)` 

```objective-c
//the callback from a previous local-to-remote call
DEFINE_SERVER_METHOD_WITH_CALLBACK(echo) {
    NSLog(@"callback from server %@", args);
}
```

To invoke a method on remote, use  `CALL_SERVER_METHOD(remote_name, arg)` whose remote_name must match the name defined in `DEFINE_SERVER_METHOD_WITH_CALLBACK`. For example 
```objective-c
-(void)foo
{
    id arg = @[@"hello from client"];
    CALL_SERVER_METHOD(echo, arg);
}
```

To create a dnode instance and connect to a remote 
```objective-c
TestClient* client = [[TestClient alloc] init];
[client connectToHost:@"192.168.1.100" Port:8000 Callback:^(BOOL success, NSNumber* err){
        NSLog(@"connected %d with err %@", success, err);
    }];
```
Set up a delegate object to get notified on connection status 
```objective-c
[client addListener:self CallbackQueue:dispatch_get_main_queue()];
```

A number of delegate callbacks are 
```objective-c
-(void)connectSuccess; //connected to remote
-(void)connectFailed:(NSNumber*)code; 
-(void)disconnected; 
-(void)remoteReady; //remote interface ready
```

For detailed examples please look into the test directory for OSX and iOS xcode demos. 