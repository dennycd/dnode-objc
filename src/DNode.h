//
//  DNode.h
//  dnode-objc
//
//  Created by Denny C. Dai on 2013-06-07.
//  Copyright (c) 2013 Denny C. Dai. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Emitter.h"

#define QUOTEME_(x) #x
#define QUOTEME(x) QUOTEME_(x)

#define DECLARE_SERVER_METHOD(x)  \
-(void)dnode_server_##x:(NSArray*)args :(NSString*)callback; \
-(void)dnode_server_callback_##x:(id)args :(id)callback; \

#define DEFINE_SERVER_METHOD_WITH_CALLBACK(x) \
-(void)dnode_server_##x:(NSArray*)args :(NSString*)callback \
{ \
[self invokeRemoteWithFuncName:NSStringFromSelector(_cmd) Args:args Callback:callback]; \
} \
-(void)dnode_server_callback_##x:(id)args :(id)callback

#define CALL_SERVER_METHOD(name, arg)  \
[self dnode_server_##name: arg :@QUOTEME(dnode_server_callback_)QUOTEME(name)QUOTEME(::)];

#define DECLARE_CLIENT_METHOD(name) \
-(void)dnode_client_##name:(id)args :(id)callback

#define DEFINE_CLIENT_METHOD(name) \
-(void)dnode_client_##name:(id)args :(id)callback


typedef enum : NSInteger{
  SCEC_NONE,
  SCEC_SERVER_OFFLINE, 
  SCEC_NETWORK_SWITCH,
  SCEC_NETWORK_LOST
}DNODE_CONNECTION_ERR_CODES;

typedef void(^DNodeConnectCallback)(BOOL success, NSNumber* err);

/**
 DNode Client Service Class
 **/
@protocol DNodeDelegate;
@interface DNode : Emitter
-(id)init;
-(void)connectToHost:(NSString*)host Port:(UInt16)port Callback:(DNodeConnectCallback)clk;
-(void)disconnect; //drop link
-(void)invokeRemoteWithFuncName:(NSString*)name Args:(NSArray*)args Callback:(NSString*)callback;  //call remote 
@property(nonatomic, assign) BOOL remoteReady;
-(BOOL)isConnected; //is connected to remote
@end


/**
 DNode Layer Callback Delegation
**/
@protocol DNodeDelegate <NSObject>
@optional
-(void)connectSuccess;
-(void)connectFailed:(NSNumber*)code;
-(void)disconnected;
-(void)receiveData:(NSString*)data; //debug callback
-(void)remoteReady;
@end