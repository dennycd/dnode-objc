//
//  Emitter.h
//  dnode-objc
//
//  Created by Denny C. Dai on 2013-06-07.
//  Copyright (c) 2013 Denny C. Dai. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^EmitterListenerCallback)(id listener);

/**
 Event Emitter Base Class
 **/
@interface Emitter : NSObject
-(void)addListener:(id)listener CallbackQueue:(dispatch_queue_t)queue;  //subscribe the listener
-(void)removeListener:(id)listener; //unsubscribe the listener
-(void)emitCallWithBlock:(EmitterListenerCallback)blk;   //invoke block for all listeners
-(void)emitCallWithMethod:(SEL)method Obj:(id)obj;
-(void)emitCallWithMethod:(SEL)method Obj:(id)obj1 Obj:(id)obj2; //invoke block for all listeners;
-(id)init;
@end



