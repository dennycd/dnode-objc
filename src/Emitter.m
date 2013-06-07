//
//  Emitter.m
//  dnode-objc
//
//  Created by Denny C. Dai on 2013-06-07.
//  Copyright (c) 2013 Denny C. Dai. All rights reserved.
//

#import "Emitter.h"
#import <objc/runtime.h>

/**
  Listener Wrapper
 **/
@interface EmitterListener : NSObject
@property(nonatomic,weak) dispatch_queue_t queue; // queue mem is managed by ARC - http://stackoverflow.com/questions/8618632/does-arc-support-dispatch-queues
@property(nonatomic,weak) id listener;
-(id)initWithListener:(id)ls CallbackQueue:(dispatch_queue_t)q;
+(EmitterListener*)listenerWithListener:(id)ls CallbackQueue:(dispatch_queue_t)q;
@end


@interface Emitter()
@property(nonatomic,strong) NSMutableArray* listeners;
@end

@implementation Emitter


//execute a block on all subscribed listeners
//REFERENCE http://stackoverflow.com/questions/14643456/objective-c-blocks-in-arc
//REFERENCE http://developer.apple.com/library/mac/#releasenotes/ObjectiveC/RN-TransitioningToARC/Introduction/Introduction.html
-(void)emitCallWithBlock:(EmitterListenerCallback)blk
{
    //invoke the block on each listener on each listener's queue
    NSArray* ls = [NSArray arrayWithArray:_listeners];
    for(EmitterListener* listener in ls)
    {
        dispatch_async(listener.queue, ^{
            blk(listener.listener);
        });
    }
}

//execute a method call on all subscribed listeners
//REFERENCE for supressing the performSelector warning
//http://stackoverflow.com/questions/10793116/to-prevent-warning-from-performselect-may-cause-a-leak-because-its-selector-is
-(void)emitCallWithMethod:(SEL)method Obj:(id)obj
{
    for(EmitterListener* listener in _listeners)
    {
        if([listener.listener respondsToSelector:method]){
            dispatch_async(listener.queue, ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [listener.listener performSelector:method withObject:obj];
#pragma clang diagnostic pop
            });
        }
    }
}

//syntax call a method on all listeners with passed object arguments
// form: method(obj1,obj2)
-(void)emitCallWithMethod:(SEL)method Obj:(id)obj1 Obj:(id)obj2
{
    for(EmitterListener* listener in _listeners)
    {
        if([listener.listener respondsToSelector:method]){
            dispatch_async(listener.queue, ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [listener.listener performSelector:method withObject:obj1 withObject:obj2];
#pragma clang diagnostic pop
            });
        }
    }
}


-(void)addListener:(id)listener CallbackQueue:(dispatch_queue_t)queue
{
    NSAssert(listener!=nil,@"listener invalid!!");
    [_listeners addObject:[EmitterListener listenerWithListener:listener CallbackQueue:queue]];
}

-(void)removeListener:(id)listener
{
    EmitterListener* target = nil;
    for(EmitterListener* l in _listeners)
    {
        if([listener isEqual:l.listener])
        {
            target = l;
            break;
        }
    }
    
    if(target)
        [_listeners removeObject:target];
}



-(id)init{
    self = [super init];
    if (self) {
        _listeners = [NSMutableArray array];
    }
    
    return self;
}




@end




#pragma mark - MonobListener
@implementation EmitterListener

-(id)initWithListener:(id)ls CallbackQueue:(dispatch_queue_t)q
{
    self = [super init];
    if (self) {
        _queue = q;
        _listener = ls;
    }
    return self;
}

+(EmitterListener*)listenerWithListener:(id)ls CallbackQueue:(dispatch_queue_t)q
{
    EmitterListener* l = [[EmitterListener alloc] initWithListener:ls CallbackQueue:q];
    return l;
}

@end








//TODO Need to resolve this variadic argument issue in order to fully implement it
//http://developer.apple.com/library/mac/#qa/qa1405/_index.html
//http://cocoawithlove.com/2009/05/variable-argument-lists-in-cocoa.html
//http://developer.apple.com/library/mac/#documentation/Cocoa/Reference/ObjCRuntimeRef/Reference/reference.html
//
//-(void)emitCallWithMethod:(SEL)method, ...
//{
//    NSAssert(nil,@"not yet implemented !");
/*
 va_list args;
 va_start(args, method);
 for(id arg = va_arg(args, id); arg != nil; arg = va_arg(args, id))
 {
 
 }
 va_end(args);
 
 for(MonobListener* listener in _listeners)
 {
 dispatch_async(listener.queue, ^{
 
 Class cls = [listener.listener class];
 Method m = class_getInstanceMethod(cls,method);
 if(m)
 {
 unsigned argC = method_getNumberOfArguments(m);
 
 objc_msgSend(listener.listener, method, );
 }
 });
 }
 */
//}





