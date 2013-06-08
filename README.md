# DNode | ObjectiveC implementation for OSX and iOS

An Objective-C native implementation of [dnode](http://github.com/substack/dnode) asynchronous RPC protocol. It uses the following library 
* [CocoaAsyncSocket](https://github.com/robbiehanson/CocoaAsyncSocket) for TCP networking
* [SBJson](https://github.com/stig/json-framework) for JSON stream handling

## Usage

Start by subclassing DNode and define your local dnode interface in a header file.

'''objective-c
#import "DNode.h"

@interface TestClient : DNode
-(void)foo; //the method your would like to call on remote
@end
'''

To expose your local dnode interface to the remote, use C++ macro `DEFINE_CLIENT_METHOD(local_name)`. For example
'''objective-c
//the direct call from remote dnode
DEFINE_CLIENT_METHOD(hello) {
    NSLog(@"hello from server: %@ ", args); 
}
'''

To explicitly declared a method on remote and receive callback, use C++ macro `DEFINE_SERVER_METHOD_WITH_CALLBACK(remote_name)`. For example

'''objective-c
//the callback from a previous local-to-remote call
DEFINE_SERVER_METHOD_WITH_CALLBACK(echo) {
    NSLog(@"callback from server %@", args);
}
'''

To invoke a method on remote dnode object, use C++ macro `CALL_SERVER_METHOD(remote_name, arg)`. An example is 
'''objective-c
-(void)foo
{
    id arg = @[@"hello from client"];
    CALL_SERVER_METHOD(echo, arg);
}
```

A complete interface implementation may look like this 
'''objective-c
#import "TestClient.h"

@interface TestClient()
//local dnode interface declaration
DECLARE_CLIENT_METHOD(hello);
//remote dnode interface declaration
DECLARE_SERVER_METHOD(echo);
@end

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
```