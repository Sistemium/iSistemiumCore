//
//  STMRemoteController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 13/04/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMRemoteController.h"
#import "STMSessionManager.h"
#import "STMSession.h"


@implementation STMRemoteController

+ (STMSession *)session {
    return [STMSessionManager sharedManager].currentSession;
}

+ (void)receiveRemoteCommands:(NSDictionary *)remoteCommands {

    for (NSString *className in remoteCommands.allKeys) {
        
        Class theClass = NSClassFromString(className);
        
        if (theClass) {
            
            id payload = remoteCommands[className];
            
            if ([payload isKindOfClass:[NSString class]]) {
                
                // payload is method name
                [self performMethod:payload onClass:theClass];
                
            } else if ([payload isKindOfClass:[NSDictionary class]]) {
                
                // payload is dic of method:object
                NSDictionary *methodsDic = (NSDictionary *)payload;
                
                for (NSString *methodName in methodsDic.allKeys) {
                    [self performMethod:methodName withObject:methodsDic[methodName] onClass:theClass];
                }
                
            } else {
                
                NSString *logMessage = [NSString stringWithFormat:@"notification's payload for %@ is not a string or dictionary", className];
                [STMLogger.sharedLogger saveLogMessageWithText:logMessage type:@"error"];
                
            }
            
        } else {
            
            NSString *logMessage = [NSString stringWithFormat:@"%@ does not exist", className];
            [STMLogger.sharedLogger saveLogMessageWithText:logMessage type:@"error"];
            
        }
        
    }

}

+ (void)performMethod:(NSString *)methodName onClass:(Class)theClass {
    [self performMethod:methodName withObject:nil onClass:theClass];
}

+ (void)performMethod:(NSString *)methodName withObject:(id)object onClass:(Class)theClass {

    SEL selector = NSSelectorFromString(methodName);
    
    if ([theClass respondsToSelector:selector]) {
        
        [self noWarningPerformSelector:selector withObject:object onReceiver:theClass];
        
    } else if ([theClass instancesRespondToSelector:selector]) {
        
        id instance = [self instanceForClass:theClass];
        
        if (instance) [self noWarningPerformSelector:selector withObject:object onReceiver:instance];
        
    } else {
        
        NSString *logMessage = [NSString stringWithFormat:@"%@ have no method %@", NSStringFromClass([theClass class]), methodName];
        [STMLogger.sharedLogger saveLogMessageWithText:logMessage type:@"error"];
        
    }

}

+ (id)instanceForClass:(Class)class {

    if ([class isSubclassOfClass:[STMSyncer class]]) {
        
        return self.session.syncer;
        
    } else if ([class isSubclassOfClass:[STMBatteryTracker class]]) {
        
        return self.session.batteryTracker;
        
    } else if ([class isSubclassOfClass:[STMLocationTracker class]]) {

        return self.session.locationTracker;

    } else {
        
        NSString *logMessage = [NSString stringWithFormat:@"no registered instance for class %@", NSStringFromClass([class class])];
        [STMLogger.sharedLogger saveLogMessageWithText:logMessage type:@"error"];

        return nil;
        
    }
}

+ (void)noWarningPerformSelector:(SEL)selector withObject:(id)object onReceiver:(id)receiver {

    [receiver performSelector:selector withObject:object afterDelay:0];
    
//    IMP imp = [receiver methodForSelector:selector];
//    
//// --- if need to get return value from method then use this two lines instead of imp()
////    id (*func)(id, SEL, id) = (id (*)(id,SEL,id))imp;
////    id value = func(receiver, selector, object);
//    
//    imp(receiver, selector, object);


// another way to remove warning
// ----
// remove the warning about potential memory leak
// in the _response selector because the compiler
// doesn't know in ARC mode if it needs to apply
// a retain or release.
//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
// ----
    
}


@end
