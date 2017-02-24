//
//  STMRemoteController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 13/04/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMRemoteController.h"
#import "STMCoreSessionManager.h"
#import "STMCoreSession.h"
#import "STMSyncer.h"

@implementation STMRemoteController

+ (STMCoreSession *)session {
    return [STMCoreSessionManager sharedManager].currentSession;
}

+ (BOOL)error:(NSError **)error withMessage:(NSString *)errorMessage {
    
    NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;
    
    if (bundleId && error) *error = [NSError errorWithDomain:(NSString * _Nonnull)bundleId
                                                        code:1
                                                    userInfo:@{NSLocalizedDescriptionKey: errorMessage}];
    
    return (error == nil);
    
}

+ (void)loggingErrorMessage:(NSString *)logMessage {
    [STMLogger.sharedLogger saveLogMessageWithText:logMessage numType:STMLogMessageTypeError];
}

+ (void)receiveRemoteCommands:(NSDictionary *)remoteCommands {

    NSError *error = nil;
    [self receiveRemoteCommands:remoteCommands error:&error];
    
    if (error) [self loggingErrorMessage:error.localizedDescription];
    
}

+ (BOOL)receiveRemoteCommands:(NSDictionary *)remoteCommands error:(NSError *__autoreleasing *)error {
    
    NSString *errorMessage = nil;
    
    if ([remoteCommands isKindOfClass:[NSDictionary class]]) {
        
    for (NSString *className in remoteCommands.allKeys) {
        
        Class theClass = NSClassFromString(className);
        
        if (theClass) {
            
            id payload = remoteCommands[className];
            
            if ([payload isKindOfClass:[NSString class]]) {
                
                    [self performMethod:payload onClass:theClass error:error];
                
            } else if ([payload isKindOfClass:[NSDictionary class]]) {
                
                NSDictionary *methodsDic = (NSDictionary *)payload;
                
                for (NSString *methodName in methodsDic.allKeys) {
                        [self performMethod:methodName withObject:methodsDic[methodName] onClass:theClass error:error];
                }
                
            } else {
                
                    errorMessage = [NSString stringWithFormat:@"notification's payload for %@ is not a string or dictionary", className];
                
            }
            
        } else {
            
                errorMessage = [NSString stringWithFormat:@"%@ does not exist", className];
                
            }
            
        }
        
    } else {
        
        errorMessage = @"remoteCommands is not an NSDictionary class";
        
    }

    if (errorMessage) [self error:error withMessage:errorMessage];
    
    return (error == nil);
    
}

+ (BOOL)performMethod:(NSString *)methodName onClass:(Class)theClass error:(NSError *__autoreleasing *)error {
    
    [self performMethod:methodName withObject:nil onClass:theClass error:error];
    return (error == nil);
    
}

+ (BOOL)performMethod:(NSString *)methodName withObject:(id)object onClass:(Class)theClass error:(NSError *__autoreleasing *)error {

    SEL selector = NSSelectorFromString(methodName);
    
    if ([theClass respondsToSelector:selector]) {
        
        [self noWarningPerformSelector:selector withObject:object onReceiver:theClass];
        
    } else if ([theClass instancesRespondToSelector:selector]) {
        
        id instance = [self instanceForClass:theClass error:error];
        
        if (instance) [self noWarningPerformSelector:selector withObject:object onReceiver:instance];
        
    } else {
        
        NSString *logMessage = [NSString stringWithFormat:@"%@ have no method %@", NSStringFromClass([theClass class]), methodName];
        [self error:error withMessage:logMessage];
        
    }
    
    return (error == nil);

}

+ (id)instanceForClass:(Class)class error:(NSError *__autoreleasing *)error {

    if ([class isSubclassOfClass:[STMSyncer class]]) {
        
        return self.session.syncer;
        
    } else if ([class isSubclassOfClass:[STMCoreBatteryTracker class]]) {
        
        return self.session.batteryTracker;
        
    } else if ([class isSubclassOfClass:[STMCoreLocationTracker class]]) {

        return self.session.locationTracker;

    } else {
        
        NSString *logMessage = [NSString stringWithFormat:@"no registered instance for class %@", NSStringFromClass([class class])];
        [self error:error withMessage:logMessage];

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
