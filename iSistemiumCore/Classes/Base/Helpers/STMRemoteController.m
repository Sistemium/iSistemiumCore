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
#import "STMCoreSessionFiler.h"

@implementation STMRemoteController

+ (STMCoreSession *)session {
    return [STMCoreSessionManager sharedManager].currentSession;
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

    if (![remoteCommands isKindOfClass:[NSDictionary class]]) {

        [STMFunctions error:error withMessage:@"remoteCommands is not an NSDictionary class"];
        return NO;

    }


    for (NSString *className in remoteCommands.allKeys) {

        Class theClass = NSClassFromString(className);

        if (!theClass) {

            NSString *message = [NSString stringWithFormat:@"%@ does not exist", className];
            errorMessage = errorMessage ? [[errorMessage stringByAppendingString:@"\n"] stringByAppendingString:message] : message;
            continue;

        }

        id payload = remoteCommands[className];

        if ([payload isKindOfClass:[NSString class]]) {

            [self performMethod:payload onClass:theClass error:error];

        } else if ([payload isKindOfClass:[NSDictionary class]]) {

            NSDictionary *methodsDic = (NSDictionary *) payload;

            for (NSString *methodName in methodsDic.allKeys) {
                [self performMethod:methodName withObject:methodsDic[methodName] onClass:theClass error:error];
            }

        } else {

            errorMessage = [NSString stringWithFormat:@"notification's payload for %@ is not a string or dictionary", className];

        }

    }

    if (errorMessage) [STMFunctions error:error withMessage:errorMessage];

    return (error == nil);

}

+ (id)performMethod:(NSString *)methodName onClass:(Class)theClass error:(NSError *__autoreleasing *)error {

    return [self performMethod:methodName withObject:nil onClass:theClass error:error];

}

+ (id)performMethod:(NSString *)methodName withObject:(id)object onClass:(Class)theClass error:(NSError *__autoreleasing *)error {

    NSArray *arguments;

    if (object) {
        arguments = @[object];
    }

    return [self performMethod:methodName withArguments:arguments onClass:theClass error:error];

}

+ (id)performMethod:(NSString *)methodName withArguments:(NSArray *)arguments onClass:(Class)theClass error:(NSError *__autoreleasing *)error {

    SEL selector = NSSelectorFromString(methodName);

    if ([theClass respondsToSelector:selector]) {

        return [self invokeWithSelector:selector withArguments:arguments onReceiver:theClass];

    } else if ([theClass instancesRespondToSelector:selector]) {

        id instance = [self instanceForClass:theClass error:error];

        if (instance) return [self invokeWithSelector:selector withArguments:arguments onReceiver:instance];

    } else {

        NSString *logMessage = [NSString stringWithFormat:@"%@ has no method %@", NSStringFromClass([theClass class]), methodName];
        [STMFunctions error:error withMessage:logMessage];

    }

    return nil;

}

+ (id)instanceForClass:(Class)class error:(NSError *__autoreleasing *)error {

    if ([class isSubclassOfClass:[STMSyncer class]]) {

        return self.session.syncer;

    } else if ([class isSubclassOfClass:[STMCoreBatteryTracker class]]) {

        return self.session.batteryTracker;

    } else if ([class isSubclassOfClass:[STMCoreLocationTracker class]]) {

        return self.session.locationTracker;

    } else if ([class isSubclassOfClass:[STMCoreSessionFiler class]]) {

        return self.session.filing;

    }

    NSString *logMessage = [NSString stringWithFormat:@"no registered instance for class %@", NSStringFromClass([class class])];
    [STMFunctions error:error withMessage:logMessage];

    return nil;
}

+ (NSDictionary *)receiveRemoteRequests:(NSDictionary *)remoteRequests {

    NSError *error = nil;

    NSMutableDictionary *response = @{}.mutableCopy;

    if (![remoteRequests isKindOfClass:[NSDictionary class]]) {

        [STMFunctions error:&error withMessage:@"remoteRequests is not an NSDictionary class"];
        return @{@"error": [error localizedDescription]};

    }

    for (NSString *className in remoteRequests.allKeys) {

        Class theClass = NSClassFromString(className);

        if (!theClass) {

            NSString *message = [NSString stringWithFormat:@"%@ does not exist", className];

            [STMFunctions error:&error withMessage:message];

            response[className] = @{@"error": [error localizedDescription]};

            continue;

        }

        error = nil;

        id payload = remoteRequests[className];

        if ([payload isKindOfClass:[NSString class]]) {

            id answer = [self performMethod:payload onClass:theClass error:&error];

            if (error) {
                response[className] = @{@"error": [error localizedDescription]};
            } else {
                response[className] = answer;
            }

        } else if ([payload isKindOfClass:[NSDictionary class]]) {

            NSDictionary *methodsDic = (NSDictionary *) payload;

            NSMutableDictionary *classAnswer = @{}.mutableCopy;

            for (NSString *methodName in methodsDic.allKeys) {

                id answer = [self performMethod:methodName withObject:methodsDic[methodName] onClass:theClass error:&error];

                if (error) {
                    answer = @{@"error": [error localizedDescription]};
                    error = nil;
                }

                classAnswer[methodName] = answer;

            }

            response[className] = classAnswer.copy;

        } else {

            [STMFunctions error:&error withMessage:[NSString stringWithFormat:@"notification's payload for %@ is not a string or dictionary", className]];

            response[className] = @{@"error": [error localizedDescription]};

        }

        error = nil;

    }

    return response.copy;

}

+ (id)invokeWithSelector:(SEL)selector withArguments:(NSArray *)arguments onReceiver:(id)receiver {

    NSMethodSignature *signature;

    if ([receiver respondsToSelector:selector]) {

        signature = [receiver methodSignatureForSelector:selector];

    } else {

        signature = [receiver instanceMethodSignatureForSelector:selector];

    }

    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];;

    [invocation setTarget:receiver];

    [invocation setSelector:selector];

    int index = 2;

    for (id argument in arguments) {

        if (index == [signature numberOfArguments]) break;
        [invocation setArgument:(void *_Nonnull) &argument atIndex:index];
        index++;
    }
    @try {

        [invocation invoke];

    }
    @catch (NSException *exception) {

        return @{@"error": [exception description]};

    }

    if ([signature methodReturnLength]) {

        void *pointer;

        [invocation getReturnValue:&pointer];

        id result = (__bridge id) pointer;

        return result;

    }

    return nil;

}

@end
