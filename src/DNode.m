//
//  DNode.m
//  dnode-objc
//
//  Created by Denny C. Dai on 2013-06-07.
//  Copyright (c) 2013 Denny C. Dai. All rights reserved.
//
#import <objc/runtime.h>
#import <SystemConfiguration/SCNetworkReachability.h>

#import "DNode.h"
#import "GCDAsyncSocket.h"
#import "SBJson.h"

#define DNodeClientAPIPrefix @"dnode_client_"
#define DNodeServerCallbackPrefix @"dnode_server_callback_"
#define DNodeServerAPIPrefix @"dnode_server_"

#define MAX_DNODE_SRV_FUNCTION_IDX 100
#define MAX_DNODE_CLIENT_FUNCTION_IDX 100
#define TIMEOUT_NONE -1

#define TAG_DATAREAD 0
#define TAG_DATAWRITE 1
#define TAG_HANDSHAKE 9

#define DNODE_DEBUG 0
#define DNODE_LOG(fmt, ...)  {if(DNODE_DEBUG) NSLog(fmt, ##__VA_ARGS__);}

//private interface
@interface DNode()
{    
    BOOL handshaked;
    //Reachability* internetReach;
    //NetworkStatus curStatus;
}
@property(nonatomic, strong) GCDAsyncSocket* socket;
@property(nonatomic, strong) dispatch_queue_t workqueue; //dedicated dnode worker queue
@property(nonatomic, strong) SBJsonParser *parser; //json parser
@property(nonatomic, strong) SBJsonWriter *writer; //json writer
@property(nonatomic, strong) NSMutableArray* apiMap; //server-to-client callback api array
@property(nonatomic, strong) NSMutableArray* srvApiMap; //server side API callback map
@property(nonatomic, strong) DNodeConnectCallback conClk;

@end

@implementation DNode


#pragma mark - Life Cycle

-(id)init
{
    self = [super init];
    if(self)
    {
        _workqueue = dispatch_queue_create("dnode-objc.workqueue", NULL);
        _socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue: _workqueue];
        
        _parser = [[SBJsonParser alloc] init];
        _writer = [[SBJsonWriter alloc] init];
        _apiMap = [[NSMutableArray alloc] init];
        _srvApiMap = [[NSMutableArray alloc] init];
        
        //add null object as placeholder
        for(int i=0;i<MAX_DNODE_SRV_FUNCTION_IDX;i++)
            [_srvApiMap addObject:[NSNull null]];
        
        for(int i=0;i<MAX_DNODE_CLIENT_FUNCTION_IDX;i++)
            [_apiMap addObject:[NSNull null]];
    }
    return self;
}


 
#pragma mark - Status Query
-(BOOL)isConnected
{
    return [self.socket isConnected];
}

#pragma mark - connection manage

-(void)disconnect
{
    //////NSLog(@"disconnecting from server");
    [self.socket disconnect];
    
    [self emitCallWithBlock:^(id listener){
        if([listener respondsToSelector:@selector(disconnected)])
            [(id<DNodeDelegate>)listener disconnected];
    }];
    
    self.remoteReady = NO;
}

-(void)connectToHost:(NSString*)host Port:(UInt16)port
{
    self.remoteReady = NO;
    NSError *err;
    [self.socket connectToHost:host onPort:port error:&err];
}

-(void)connectToHost:(NSString*)host Port:(UInt16)port Callback:(DNodeConnectCallback)clk
{
    self.conClk = clk;
    [self connectToHost:host Port:port];
}


#pragma mark - GCDAsyncSocket Delegation

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
    DNODE_LOG(@"didConnectToHost %@:%d", host,port);

    //one-time only invocation
    if(self.conClk)
    {
        self.conClk(YES, nil);
        self.conClk = nil;
    }
    
    //notify connection success
    [self emitCallWithBlock:^(id listener){
        if([listener respondsToSelector:@selector(connectSuccess)])
            [(id<DNodeDelegate>)listener connectSuccess];
    }];
    
    //asynchronous two way handshake
    [self readNextChunk];
    [self handshake];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
	DNODE_LOG(@"socketDidDisconnect withError: %@", err);
    
    DNODE_CONNECTION_ERR_CODES code = SCEC_SERVER_OFFLINE;

    NSNumber* errCode = [NSNumber numberWithInt:code];
    
    [self emitCallWithBlock:^(id listener){
        if([listener respondsToSelector:@selector(connectFailed:)])
            [(id<DNodeDelegate>)listener connectFailed:errCode];
    }];
    
    if(self.conClk)
    {
        self.conClk(NO,errCode);
        self.conClk = nil;
    }
}

//once a data trunk is read, we comprehand it
//and then start a new read afterwards
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    DNODE_LOG(@"didReadData of length %ld, tag %ld", (unsigned long)[data length], tag);
    
    NSString* stream = [[NSString alloc] initWithBytes:[data bytes]
                                                length:[data length]-[[GCDAsyncSocket LFData] length]
                                              encoding:NSUTF8StringEncoding];
    
    //DEBUG ONLY
    #ifdef DNODE_DEBUG
    [self emitCallWithBlock:^(id listener){
        if([listener respondsToSelector:@selector(receiveData:)])
            [(id<DNodeDelegate>)listener receiveData:stream];
    }];
    #endif
    
    id obj = [self.parser objectWithString:stream];
    if(!obj)
        DNODE_LOG(@"json parser error [%@]", stream)
    else
    {
        NSAssert([obj isKindOfClass:[NSDictionary class]],@"dnode protocol stream not a dictionary !");
        [self parseProtocolStream:obj];
    }
    
    [self readNextChunk];
}


- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    DNODE_LOG(@"didWriteDataWithTag with tag: %ld", tag);
    
    if(tag == TAG_HANDSHAKE)
    {
        DNODE_LOG(@"HANDSHAKE SUCCESS");
        handshaked = true;
    }
}


#pragma mark - Utility Function

/**
 
 @param callback - the method name on this dnode object that handles the callback of this rmi
 **/
-(void)invokeRemoteWithFuncName:(NSString*)name Args:(NSArray*)args Callback:(NSString*)callback
{
    DNODE_LOG(@"invokeRemoteWithFuncName %@ with callback %@",name, callback);
    
    //append a callback function to the argument list
    NSMutableArray* arguments = [args mutableCopy];  
    [arguments addObject:@"Function"];
    
    //resever an anonymous local function serving the callback from remote
    int callbackArguPos = (int)[args count]; //the position of the callback in the argument list
    
    //assign next api index and add the callback name for callback executation
    int callbackBlockFuncIdex = [self assignNextClientAPIIndex];
    self.apiMap[callbackBlockFuncIdex] = callback;
    
    //tell remote the callback function id , and its index in the original local=>remote call's  argument list 
    NSDictionary* callbacks = @{ [NSString stringWithFormat:@"%d",callbackBlockFuncIdex] :  @[@(callbackArguPos)] };
    
    //make sure the target remote method must have been decaled in the server api map
    int serverFuncIdex = (int)[self.srvApiMap indexOfObject:name];
    if(!(serverFuncIdex >= 0 && serverFuncIdex < [self.srvApiMap count]))
    {
        DNODE_LOG(@"WARNING: failed to locate locate srv method %@", name);
        return;
    }
    
    //make the method call protocol and send as json
    // use remote's method callback id to identify the method
    // 
    NSDictionary* client = @{@"method" : @(serverFuncIdex), @"arguments" : arguments, @"callbacks" : callbacks};
    NSString* stream = [[self.writer stringWithObject:client] stringByAppendingString:@"\n"];     
    [self.socket writeData: [NSData dataWithBytes:[stream UTF8String] length:[stream length]]
               withTimeout: TIMEOUT_NONE 
                       tag: TAG_DATAWRITE];
}


-(int)assignNextClientAPIIndex
{
    for(id elem in self.apiMap)
    {
        if([elem isKindOfClass:[NSNull class]])
        {
            return (int)[self.apiMap indexOfObject:elem];
        }
    }
    
    NSAssert(nil,@"failed to allocate next client api callback index !");
    return -1;
}

-(int)assignNextServerAPIIndex
{
    for(id elem in self.srvApiMap)
    {
        if([elem isKindOfClass:[NSNull class]])
        {
            return (int)[self.srvApiMap indexOfObject:elem];
        }
    }
    
    NSAssert(nil,@"failed to allocate next server api callback index !");
    return -1;
}


-(void)buildAPIMap
{
    //clean up old api map 
    [self.apiMap removeAllObjects];
    for(int i=0;i<MAX_DNODE_CLIENT_FUNCTION_IDX;i++)
        [self.apiMap addObject:[NSNull null]];
    
    
    //inspect on self
    unsigned int outCount;
    Method* methods = class_copyMethodList([self class], &outCount);
    
    for(int i=0;i<outCount;i++)
    {
        SEL sel = method_getName(methods[i]);
        NSString* name = NSStringFromSelector(sel);
        if([name hasPrefix:DNodeClientAPIPrefix])
        {
            DNODE_LOG(@"adding local api %@", name);
            [self.apiMap replaceObjectAtIndex:i withObject:name]; //adding method name to map
        }
    } 
}



-(void)buildSrvAPIMapWithArgs:(id)args Callbacks:(id)callbacks
{
//    //reset placeholders
    [self.srvApiMap removeAllObjects];
    for(int i=0;i<MAX_DNODE_SRV_FUNCTION_IDX;i++)
        [self.srvApiMap addObject:[NSNull null]];

    NSAssert([args isKindOfClass:[NSArray class]], @"args not array");
    NSAssert([callbacks isKindOfClass:[NSDictionary class]], @"callbacks not dictionary");
    id funcList = [(NSArray*)args objectAtIndex:0];
    NSAssert(funcList && [funcList isKindOfClass:[NSDictionary class]], @"args's dictionary invalid");

    //validate remote method interface with local server API declaration
    for(id key in [(NSDictionary*)funcList allKeys] )
    {
        //ensure it returns "Function" in value field
        NSString* funcStr = [(NSDictionary*)funcList objectForKey:key];
        NSAssert( [funcStr isKindOfClass:[NSString class]] && [funcStr isEqualToString:@"[Function]"], @"non-Function returned in argument");
        
        //key must match a local api name declared on the dnode instance itself
        NSString* actualName = [NSString stringWithFormat:@"%@%@::",DNodeServerAPIPrefix, key];
        
        if(![self respondsToSelector:NSSelectorFromString(actualName)])
        {
            DNODE_LOG(@"WARNING: failed to match local server api declaration for %@", actualName);
        }
        else{
            DNODE_LOG(@"server API discovered: %@", actualName);
        }
    }

    //build up the index table for server callback
    for(id key in [(NSDictionary*)callbacks allKeys])
    {
        int idx = [(NSString*)key intValue]; //server side callback index ID
        NSAssert(idx >=0, @"invalid server side index ");
        
        
        id obj = [(NSDictionary*)callbacks objectForKey:key];
        NSAssert(obj && [obj isKindOfClass:[NSArray class]], @"obj invalid");
        
        //int pos = [(NSArray*)obj objectAtIndex:0];
        id funcName = [(NSArray*)obj objectAtIndex:1];
        NSAssert(funcName && [funcName isKindOfClass:[NSString class]], @"invalid function name");
        
        //remote method name must have matched a local server API definition
        NSString* actualName = [NSString stringWithFormat:@"%@%@::",DNodeServerAPIPrefix, funcName];
        if(![self respondsToSelector:NSSelectorFromString(actualName)])
        {
            DNODE_LOG(@"WARNING: failed to match local server api declaration for %@", actualName);
            continue;
        }
        
        //now add to srv map at correct idx
        [self.srvApiMap replaceObjectAtIndex:idx withObject:actualName];
    }
    
    self.remoteReady = YES;
    [self emitCallWithBlock:^(id listener){
        if([listener respondsToSelector:@selector(remoteReady)])
            [(id<DNodeDelegate>)listener remoteReady];
    }];
}

#pragma mark - Private API
-(void)handshake
{
    [self buildAPIMap];

    NSMutableDictionary* argumentsDict = [NSMutableDictionary dictionary];
    NSMutableDictionary* callbacks = [NSMutableDictionary dictionary];

    //construct callback dictionary and argument array
    for(int i=0;i < [self.apiMap count]; i++)
    {
        NSString* name = [self.apiMap objectAtIndex:i];
        if([name isKindOfClass:[NSNull class]]) continue;
        name = [name stringByReplacingOccurrencesOfString:@":" withString:@""]; //trim :: function name
        name = [name stringByReplacingOccurrencesOfString:DNodeClientAPIPrefix withString:@""]; //trim dnode prefix
        [argumentsDict setObject: @"Function" forKey:name]; //api name as key, Function string as object value 
        [callbacks setObject:[NSArray arrayWithObjects:@"0", name, nil] //api index as key, api name as object value
                      forKey: [NSString stringWithFormat:@"%d",i]];
    }
    NSArray* arguments = [NSArray arrayWithObject:argumentsDict];
    
    
    //make a dictionary and send over to 
    NSArray* keys = [NSArray arrayWithObjects:@"method", @"arguments", @"callbacks", nil];
    NSArray* objs = [NSArray arrayWithObjects:@"methods", arguments, callbacks, nil];
    NSDictionary *client = [NSDictionary dictionaryWithObjects:objs forKeys:keys];

    NSString* stream = [[self.writer stringWithObject:client] stringByAppendingString:@"\n"];
    
    [self.socket writeData: [NSData dataWithBytes:[stream UTF8String] length:[stream length]]
               withTimeout: TIMEOUT_NONE 
                       tag: TAG_HANDSHAKE];
}


//read next data trunk with newline termination
-(void)readNextChunk
{
    [self.socket readDataToData: [GCDAsyncSocket LFData]
                    withTimeout: TIMEOUT_NONE 
                            tag: TAG_DATAREAD];
}


//parsing dnode protocol and trigger appropriate callback to delegates
//REFERENCE https://github.com/substack/dnode-protocol/blob/master/doc/protocol.markdown#the-protocol
-(void)parseProtocolStream:(NSDictionary*)protocol
{
    id method = protocol[@"method"]; //string or integer
    id arguments = protocol[@"arguments"]; //array
    id callbacks = protocol[@"callbacks"]; // object
    //id links = protocol[@"links"];
    
    //method referes a named method at the remote
    if([method isKindOfClass:[NSString class]])
    {
        //interface API handshake
        if([method isEqualToString:@"methods"])
        {
            [self buildSrvAPIMapWithArgs:arguments Callbacks:callbacks];
        }
        else
        if([method isEqualToString:@"error"])
        {
            DNODE_LOG(@"an error in protocol");
        }
        else
        {
            DNODE_LOG(@"unkown returns, methods : %@", method);
        }        
    }
    //otherwise a remote method invocation call from the remote to this client 
    else if([method isKindOfClass:[NSNumber class]])
    {
        //determine the intended method on self
        NSAssert([method isKindOfClass:[NSNumber class]], @"invalid method index");
        
        //validate the method exist on self
        int idx = (int)[(NSNumber*)method integerValue]; 
        NSAssert(idx >=0 && idx <  [self.apiMap count], @"callback function index not valid");
        
        //invoke on the method
        id localMethod = [self.apiMap objectAtIndex:idx];
        
        NSAssert([localMethod isKindOfClass:[NSString class]], @"callback method is not a string");
        

        
        NSString* actualMethod = localMethod; 
        
        //make sure we have it
        NSAssert( [self respondsToSelector:NSSelectorFromString(actualMethod)],@"callback method not implemented on self");
        
        //invoke the method and pass in both arguments and callbacks        
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:NSSelectorFromString(actualMethod) withObject:arguments withObject:callbacks];
        #pragma clang diagnostic pop
        
        //check if the method is a server callback, remove it after called
        if([actualMethod hasPrefix:DNodeServerCallbackPrefix])
        {
            //NSLog(@"removing callback api %@", actualMethod);
            [self.apiMap replaceObjectAtIndex:idx withObject:[NSNull null]];
        }

    }
    else NSAssert(false, @"invalid protocol method");

}

/*
-(void)addAdditionalSrvAPIMap:(NSDictionary*)session
{
    //    NSLog(@"addAdditionalSrvAPIMap");
    
    for(id idx in [session allKeys])
    {
        int serverFuncIdx = (int)[(NSString*)idx integerValue];
        NSAssert(serverFuncIdx > 0 && serverFuncIdx < [self.srvApiMap count],@"server function index out of bound");
        
        NSArray* arr = (NSArray*)[session objectForKey:idx];
        NSAssert([arr isKindOfClass:[NSArray class]],@"invalid array");
        
        NSString* srvFuncName = [arr objectAtIndex:1];
        
        //validate existence in local server method definition
        //key must match a local api name
        NSString* actualName = [NSString stringWithFormat:@"%@%@::",DNodeServerAPIPrefix, srvFuncName];
        if(![self respondsToSelector:NSSelectorFromString(actualName)])
        {
            //NSLog(@"failed to match local server api declaration for %@", actualName);
            continue;
        }
        
        //avoid duplicate key!
        if([self.srvApiMap indexOfObject:actualName] != NSNotFound)
        {
            //NSLog(@"duplicating existing local server api");
            continue;
        }
        
        //insert the api name to the map at cooresponding position
        [self.srvApiMap replaceObjectAtIndex:serverFuncIdx withObject:actualName];
        
        //        NSLog(@"insert method %@ at index %d",actualName,serverFuncIdx);
    }
    
    //        //NSLog(@"srvApiMap: %@", srvApiMap);
}
*/



/*
#pragma mark - Reachability Handler
//Called by Reachability whenever status changes.
- (void) reachabilityChanged: (NSNotification* )note
{
	Reachability* curReach = [note object];
	NSParameterAssert([curReach isKindOfClass: [Reachability class]]);
    NetworkStatus netStatus = [curReach currentReachabilityStatus];
    
    switch (netStatus)
    {
        case NotReachable:
        {
            //NSLog(@"Access Not Available");
            [self emitCallWithBlock:^(id listener){
                if([listener respondsToSelector:@selector(connectFailed:)])
                    [(id<DNodeDelegate>)listener connectFailed:[NSNumber numberWithInt:SCEC_NETWORK_LOST]];
            }];
            
            curStatus = NotReachable;

            break;
        }break;
        
        case ReachableViaWWAN:
        {
             ////NSLog(@"Reachable WWAN");
            
            //if previously reachable, yet received another reachable, meanning swithcing network
            [self emitCallWithBlock:^(id listener){
                if([listener respondsToSelector:@selector(connectFailed:)])
                    [(id<DNodeDelegate>)listener connectFailed:[NSNumber numberWithInt:SCEC_NETWORK_SWITCH]];
            }];
            
            curStatus = ReachableViaWWAN;
        }break;
        
        case ReachableViaWiFi:
        {
            ////NSLog(@"Reachable WiFi");
            
            //if previously reachable, yet received another reachable, meanning swithcing netowkr
            [self emitCallWithBlock:^(id listener){
                if([listener respondsToSelector:@selector(connectFailed:)])
                    [(id<DNodeDelegate>)listener connectFailed:[NSNumber numberWithInt:SCEC_NETWORK_SWITCH]];
            }];
            
            curStatus = ReachableViaWiFi;
        }break;
    }

}
*/


@end
