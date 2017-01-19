//
//  STMSocketTransport.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 11/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMSocketTransport.h"

#import <Reachability/Reachability.h>

#import "STMClientDataController.h"
#import "STMCoreRootTBC.h"


typedef NS_ENUM(NSInteger, STMSocketEvent) {
    STMSocketEventConnect,
    STMSocketEventDisconnect,
    STMSocketEventError,
    STMSocketEventReconnect,
    STMSocketEventReconnectAttempt,
    STMSocketEventStatusChange,
    STMSocketEventInfo,
    STMSocketEventAuthorization,
    STMSocketEventRemoteCommands,
    STMSocketEventData,
    STMSocketEventJSData
};

static NSString *kSocketFindAllMethod = @"findAll";
static NSString *kSocketFindMethod = @"find";
static NSString *kSocketUpdateMethod = @"update";
static NSString *kSocketDestroyMethod = @"destroy";


@interface STMSocketTransport()

@property (nonatomic, weak) STMSyncer *syncer;
@property (nonatomic, weak) STMLogger *logger;
@property (nonatomic, strong) SocketIOClient *socket;
@property (nonatomic, strong) NSString *socketUrl;
@property (nonatomic, strong) NSString *entityResource;
@property (nonatomic) BOOL isAuthorized;

//@property (nonatomic) NSTimeInterval findAllTimeout;
//@property (nonatomic, strong) NSDate *findAllStartTime;


@end


@implementation STMSocketTransport

+ (instancetype)initWithUrl:(NSString *)socketUrlString andEntityResource:(NSString *)entityResource forSyncer:(STMSyncer *)syncer {
    
    STMLogger *logger = [STMLogger sharedLogger];

    if (!socketUrlString || !entityResource || !syncer) {
        
        NSString *logMessage = [NSString stringWithFormat:@"have not enough parameters to init socket transport"];
        [logger saveLogMessageWithText:logMessage
                               numType:STMLogMessageTypeError];

        return nil;
        
    }
    
    STMSocketTransport *socketTransport = [[self alloc] init];
    
    socketTransport.socketUrl = socketUrlString;
    socketTransport.entityResource = entityResource;
    socketTransport.syncer = syncer;
    socketTransport.logger = [STMLogger sharedLogger];
    
    [socketTransport startSocket];
    
    return socketTransport;
    
}

- (BOOL)isReady {
    return self.socket.status == SocketIOClientStatusConnected && self.isAuthorized;
}

- (void)startSocket {
    
    [self.logger saveLogMessageWithText:CurrentMethodName
                                numType:STMLogMessageTypeInfo];

    NSURL *socketUrl = [NSURL URLWithString:self.socketUrl];
    NSString *path = [socketUrl.path stringByAppendingString:@"/"];

    self.socket = [[SocketIOClient alloc] initWithSocketURL:socketUrl
                                                     config:@{@"voipEnabled"         : @YES,
                                                              @"log"                : @NO,
                                                              @"forceWebsockets"    : @NO,
                                                              @"path"               : path,
                                                              @"reconnects"         : @YES}];

    [self addEventObservers];
    
    [self.socket connect];
    
}

- (void)closeSocket {
    
    [self.logger saveLogMessageWithText:CurrentMethodName
                                numType:STMLogMessageTypeInfo];

    [self.socket disconnect];
    [self flushSocket];
    
}

- (void)reconnectSocket {
    
    [self closeSocket];
    [self startSocket];
    
}

- (void)flushSocket {
    
    self.socket = nil;
    self.isAuthorized = NO;
    
}

- (void)addEventObservers {
    
    [self.socket removeAllHandlers];
    
    NSString *logMessage = [NSString stringWithFormat:@"addEventObserversToSocket %@", self.socket];
    [self.logger saveLogMessageWithText:logMessage
                                numType:STMLogMessageTypeInfo];
    
    
#ifdef DEBUG
    [self addOnAnyEventHandler];
#endif
    
    NSArray *events = @[@(STMSocketEventConnect),
                        @(STMSocketEventDisconnect),
                        @(STMSocketEventError),
                        @(STMSocketEventReconnect),
                        @(STMSocketEventReconnectAttempt),
                        @(STMSocketEventRemoteCommands),
                        @(STMSocketEventData),
                        @(STMSocketEventJSData)];
    
    for (NSNumber *eventNum in events) {
        [self addHandlerForEvent:eventNum.integerValue];
    }

}

- (void)addOnAnyEventHandler {
    
    [self.socket onAny:^(SocketAnyEvent *event) {
        
        NSLog(@"%@ %@ ___ event %@", self.socket, self.socket.sid, event.event);
        NSLog(@"%@ %@ ___ items (", self.socket, self.socket.sid);
        
        for (id item in event.items) NSLog(@"    %@", item);
        
        NSLog(@"%@ %@           )", self.socket, self.socket.sid);
        
    }];
    
}

- (void)addHandlerForEvent:(STMSocketEvent)event {
    
    NSString *eventString = [STMSocketTransport stringValueForEvent:event];
    
    [self.socket on:eventString callback:^(NSArray *data, SocketAckEmitter *ack) {
        
        switch (event) {
            case STMSocketEventConnect: {
                [self connectEventHandleWithData:data ack:ack];
                break;
            }

            case STMSocketEventDisconnect:
            case STMSocketEventError:
            case STMSocketEventReconnect:
            case STMSocketEventReconnectAttempt:
            case STMSocketEventStatusChange:
            case STMSocketEventInfo:
            case STMSocketEventAuthorization:
            case STMSocketEventRemoteCommands:
            case STMSocketEventData:
            case STMSocketEventJSData:
            default:
                break;
                
        }
        
    }];
    
}


#pragma mark - socket events handlers

- (void)connectEventHandleWithData:(NSArray *)data ack:(SocketAckEmitter *)ack {
    
    [self startDelayedAuthorizationCheck];
    
    STMClientData *clientData = [STMClientDataController clientData];
    NSMutableDictionary *dataDic = [STMCoreObjectsController dictionaryForJSWithObject:clientData].mutableCopy;
    
    NSDictionary *authDic = @{@"userId"         : [STMCoreAuthController authController].userID,
                              @"accessToken"    : [STMCoreAuthController authController].accessToken};
    
    [dataDic addEntriesFromDictionary:authDic];
    
    NSString *logMessage = [NSString stringWithFormat:@"send authorization data %@ with socket %@ %@", dataDic, self.socket, self.socket.sid];
    [self.logger saveLogMessageWithText:logMessage
                                numType:STMLogMessageTypeInfo];
    
    STMSocketEvent eventNum = STMSocketEventAuthorization;
    NSString *event = [STMSocketTransport stringValueForEvent:eventNum];
    
    [self.socket emitWithAck:event with:@[dataDic]](0, ^(NSArray *data) {
        [self receiveAckWithData:data forEventNum:eventNum];
    });

}


#pragma mark - ack handlers

- (void)receiveAckWithData:(NSArray *)data forEvent:(NSString *)event {
    
    STMSocketEvent eventNum = [STMSocketTransport eventForString:event];
    [self receiveAckWithData:data forEventNum:eventNum];
    
}

- (void)receiveAckWithData:(NSArray *)data forEventNum:(STMSocketEvent)eventNum {
    
    switch (eventNum) {
        case STMSocketEventAuthorization: {
            [self receiveAuthorizationAckWithData:data];
            break;
        }
        case STMSocketEventConnect:
        case STMSocketEventDisconnect:
        case STMSocketEventError:
        case STMSocketEventReconnect:
        case STMSocketEventReconnectAttempt:
        case STMSocketEventStatusChange:
        case STMSocketEventInfo:
        case STMSocketEventRemoteCommands:
        case STMSocketEventData:
        case STMSocketEventJSData:
        default:
            NSLog(@"%@ %@ ___ receive Ack, event: %@, data: %@", self.socket, self.socket.sid, eventNum, data);
            break;
            
    }

}

- (void)receiveAuthorizationAckWithData:(NSArray *)data {
    
    NSString *logMessage = [NSString stringWithFormat:@"socket %@ %@ receiveAuthorizationAckWithData %@", self.socket, self.socket.sid, data];
    [self.logger saveLogMessageWithText:logMessage
                                numType:STMLogMessageTypeInfo];

    if ([data.firstObject isKindOfClass:[NSDictionary class]]) {
        
        NSDictionary *dataDic = data.firstObject;
        BOOL isAuthorized = [dataDic[@"isAuthorized"] boolValue];
        
        if (isAuthorized) {
            
            [self cancelDelayedAuthorizationCheck];
            
            logMessage = [NSString stringWithFormat:@"socket %@ %@ authorized", self.socket, self.socket.sid];
            [self.logger saveLogMessageWithText:logMessage
                                        numType:STMLogMessageTypeInfo];
            
            self.isAuthorized = YES;

            [self.syncer socketReceiveAuthorization];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SOCKET_AUTHORIZATION_SUCCESS
                                                                object:self];
            [self checkAppState];
            
        } else {
            [self notAuthorizedWithError:@"socket receiveAuthorizationAck with dataDic.isAuthorized.boolValue == NO"];
        }
        
    } else {
        [self notAuthorizedWithError:@"socket receiveAuthorizationAck with data.firstObject is not a NSDictionary"];
    }
    
}

- (void)checkAppState {
    
    NSString *appState = [STMFunctions appStateString];
    
    [self sendEvent:STMSocketEventStatusChange withValue:appState];
    
    if ([appState isEqualToString:@"UIApplicationStateActive"]) {
        
        UIViewController *selectedVC = [STMCoreRootTBC sharedRootVC].selectedViewController;
        
        if ([selectedVC class]) {
            
            Class _Nonnull rootVCClass = (Class _Nonnull)[selectedVC class];
            
            NSString *value = [NSString stringWithFormat:@"selectedViewController: %@ %@ %@", selectedVC.title, selectedVC, NSStringFromClass(rootVCClass)];
            
            [self sendEvent:STMSocketEventStatusChange withValue:value];
            
        }
        
    }

}


#pragma mark - send events

- (void)sendEvent:(STMSocketEvent)event withValue:(id)value context:(NSDictionary *)context completionHandler:(void (^)(BOOL success, NSArray *data, NSError *error))completionHandler {
    
    [self logSendEvent:event withValue:value];
    
    if (self.isReady) {
        
        if (event == STMSocketEventJSData) {
            
            if ([value isKindOfClass:[NSDictionary class]]) {
                
//                NSLog(@"STMSocketEventJSData value: %@", value);
                
                NSString *eventStringValue = [STMSocketTransport stringValueForEvent:event];

                NSMutableDictionary *dataDic = [(NSDictionary *)value mutableCopy];

                [self.socket emitWithAck:eventStringValue with:@[dataDic]](0, ^(NSArray *data) {

                    [self cancelCheckRequestTimeoutWithContext:context];
                    completionHandler(YES, data, nil);

                });
                
            } else {
                
            }
            
        } else {
            
        }
        
    } else {
        
        NSString *errorMessage = @"socket not connected while sendEvent";
        
        [self socketLostConnection:errorMessage];
        
        NSError *error = nil;
        [STMCoreObjectsController error:&error
                            withMessage:errorMessage];
        
        completionHandler(NO, nil, error);
        
    }

}

- (void)sendEvent:(STMSocketEvent)event withValue:(id)value {
    
    [self logSendEvent:event withValue:value];
    
    if (self.socket.status == SocketIOClientStatusConnected) {
        
        if (event == STMSocketEventJSData) {
            
            if ([value isKindOfClass:[NSDictionary class]]) {
            
                NSLog(@"STMSocketEventJSData value: %@", value);
                
//                NSString *method = value[@"method"];
//    
//                if ([method isEqualToString:@"update"]) {
//    
//                    [self sharedInstance].isSendingData = YES;
//                    [self sharedInstance].sendingDate = [NSDate date];
//    
//                }
//    
//                NSString *eventStringValue = [STMSocketTransport stringValueForEvent:event];
//    
//                NSMutableDictionary *dataDic = [(NSDictionary *)value mutableCopy];
//    
//                [self.socket emitWithAck:eventStringValue with:@[dataDic]](0, ^(NSArray *data) {
//                    [self receiveJSDataEventAckWithData:data];
//                });

            } else {
                
            }
            
        } else {
            
            NSString *primaryKey = [STMSocketTransport primaryKeyForEvent:event];
            
            if (value && primaryKey) {
                
                NSDictionary *dataDic = @{primaryKey : value};
                
                dataDic = [STMFunctions validJSONDictionaryFromDictionary:dataDic];
                
                NSString *eventStringValue = [STMSocketTransport stringValueForEvent:event];

                if (dataDic) {
                    
                    [self.socket emit:eventStringValue
                                 with:@[dataDic]];
                    
                } else {
                    NSLog(@"%@ ___ no dataDic to send via socket for event: %@", self.socket, eventStringValue);
                }
                
            }
            
        }
        
    } else {
        [self socketLostConnection:@"socket sendEvent"];
    }

}

- (void)logSendEvent:(STMSocketEvent)event withValue:(id)value {
    
#ifdef DEBUG
    
    if (event == STMSocketEventData && [value isKindOfClass:[NSArray class]]) {
        
        //        NSArray *valueArray = [(NSArray *)value valueForKeyPath:@"name"];
        //        NSLog(@"socket:%@ sendEvent:%@ withObjects:%@", socket, [self stringValueForEvent:event], valueArray);
        
    } else if (event == STMSocketEventInfo || event == STMSocketEventStatusChange) {
        
        NSLog(@"socket:%@ %@ sendEvent:%@ withValue:%@", self.socket, self.socket.sid, [STMSocketTransport stringValueForEvent:event], value);
        
    }
    
#endif

}


#pragma mark - authorization check

- (void)startDelayedAuthorizationCheck {

    [self cancelDelayedAuthorizationCheck];

    SEL checkAuthSel = @selector(checkAuthorization);
    
    [self performSelector:checkAuthSel
               withObject:nil
               afterDelay:CHECK_SOCKET_AUTHORIZATION_DELAY];
    
}

- (void)cancelDelayedAuthorizationCheck {

    SEL checkAuthSel = @selector(checkAuthorization);
    
    [STMSocketTransport cancelPreviousPerformRequestsWithTarget:self
                                                       selector:checkAuthSel
                                                         object:nil];

}

- (void)checkAuthorization {
    
    NSLogMethodName;

    NSString *logMessage = [NSString stringWithFormat:@"checkAuthorizationForSocket: %@ %@", self.socket, self.socket.sid];
    [self.logger saveLogMessageWithText:logMessage
                           numType:STMLogMessageTypeInfo];

    if (self.socket.status == SocketIOClientStatusConnected) {

        if (self.isAuthorized) {

            logMessage = @"socket is authorized";
            [self.logger saveLogMessageWithText:logMessage
                                   numType:STMLogMessageTypeInfo];

        } else {

            logMessage = @"socket is connected but don't receive authorization ack, reconnecting";
            [self.logger saveLogMessageWithText:logMessage
                                   numType:STMLogMessageTypeError];

            [self reconnectSocket];

        }

    } else {

        logMessage = @"socket is not connected";
        [self.logger saveLogMessageWithText:logMessage
                               numType:STMLogMessageTypeInfo];
        
    }
    
}

- (void)notAuthorizedWithError:(NSString *)errorString {
    
    NSString *logMessage = [NSString stringWithFormat:@"socket %@ %@ not authorized\n%@", self.socket, self.socket.sid, errorString];
    [self.logger saveLogMessageWithText:logMessage
                                numType:STMLogMessageTypeWarning];
    
//    [self sharedInstance].isAuthorized = NO;
    [[STMCoreAuthController authController] logout];
    
}


#pragma mark - checking connection

- (void)checkReachabilityAndSocketStatus {
    
    switch (self.socket.status) {
        case SocketIOClientStatusNotConnected:
        case SocketIOClientStatusDisconnected:
            
            if ([Reachability reachabilityWithHostname:self.socketUrl].isReachable) {
                
                [[STMLogger sharedLogger] saveLogMessageWithText:@"socket is not connected but host is reachable, reconnect it"
                                                         numType:STMLogMessageTypeImportant];
                
                [self closeSocket];
                [self startSocket];
                
            }
            
            break;
            
        case SocketIOClientStatusConnecting:
        case SocketIOClientStatusConnected:
        default:
            break;
    }
    
}

- (void)socketLostConnection:(NSString *)infoString {
    
    NSLogMethodName;
    
    [self checkReachabilityAndSocketStatus];

//    STMSyncer *syncer = [self syncer];
//    
//    if (syncer.syncerState == STMSyncerSendData || syncer.syncerState == STMSyncerSendDataOnce) {
//        
//        NSString *errorString = [NSString stringWithFormat:@"%@: socket not connected while sending data", infoString];
//        [self sendFinishedWithError:errorString
//                          abortSync:@(YES)];
//        
//    }
    
    [self.syncer socketLostConnection];
    
}


#pragma mark - receiving data
#pragma mark findAll

- (void)findAllFromResource:(NSString *)resourceString withETag:(NSString *)eTag fetchLimit:(NSInteger)fetchLimit timeout:(NSTimeInterval)timeout params:(NSDictionary *)params completionHandler:(void (^)(BOOL success, NSArray *data, NSError *error))completionHandler {
    
    if (!self.isReady) {
        
        NSString *errorMessage = @"socket is not ready (not connected or not authorize)";
        
        [self completeHandler:completionHandler
             withErrorMessage:errorMessage];
        
        return;
        
    }
    
    NSMutableDictionary *value = @{@"method"   : kSocketFindAllMethod,
                                   @"resource" : resourceString
                                   }.mutableCopy;
    
    NSMutableDictionary *options = @{@"pageSize" : @(fetchLimit)}.mutableCopy;
    if (eTag) options[@"offset"] = eTag;
    
    [options setValue:@"500" forKey:@"pageSize"];
    
    value[@"options"] = options;
    
    if (params) value[@"params"] = params;
    
    NSDictionary *context = @{@"startTime"           : [NSDate date],
                              @"timeout"             : @(timeout),
                              @"completionHandler"   : completionHandler};
    
    [self performSelector:@selector(checkRequestTimeout:)
               withObject:context
               afterDelay:timeout];
    
    [self sendEvent:STMSocketEventJSData withValue:value context:context completionHandler:completionHandler];
    
}


#pragma mark find

- (void)findFromResource:(NSString *)resource objectId:(NSString *)objectId timeout:(NSTimeInterval)timeout completionHandler:(void (^)(BOOL success, NSArray *data, NSError *error))completionHandler {
    
    if (!self.isReady) {
        
        NSString *errorMessage = @"socket is not ready (not connected or not authorize)";
        
        [self completeHandler:completionHandler
             withErrorMessage:errorMessage];
        
        return;
        
    }

    NSDictionary *value = @{@"method"   : kSocketFindMethod,
                            @"resource" : resource,
                            @"id"       : objectId};

    NSDictionary *context = @{@"startTime"           : [NSDate date],
                              @"timeout"             : @(timeout),
                              @"completionHandler"   : completionHandler};
    
    [self performSelector:@selector(checkRequestTimeout:)
               withObject:context
               afterDelay:timeout];
    
    [self sendEvent:STMSocketEventJSData withValue:value context:context completionHandler:completionHandler];
    
}


#pragma mark check timeouts

- (void)checkRequestTimeout:(NSDictionary *)context {
    
    NSTimeInterval timeout = [context[@"timeout"] doubleValue];
    NSDate *startTime = context[@"startTime"];
    NSTimeInterval elapsedTime = -startTime.timeIntervalSinceNow;
    
    if (elapsedTime >= timeout) {
        
        NSString *errorMessage = @"socket receive objects timeout";
        [self sendEvent:STMSocketEventInfo
              withValue:errorMessage];
        
        void (^completionHandler)(BOOL success, NSArray *data, NSError *error) = context[@"completionHandler"];
        
        [self completeHandler:completionHandler
             withErrorMessage:errorMessage];
                
    }
    
}

- (void)cancelCheckRequestTimeoutWithContext:(NSDictionary *)context {
    
    [STMSocketTransport cancelPreviousPerformRequestsWithTarget:self
                                                       selector:@selector(checkRequestTimeout:)
                                                         object:context];
    
}

- (void)completeHandler:(void (^)(BOOL success, NSArray *data, NSError *error))completionHandler withErrorMessage:(NSString *)errorMessage {
    
    NSError *error = nil;
    
    [STMCoreObjectsController error:&error
                        withMessage:errorMessage];
    
    completionHandler(NO, nil, error);

}


#pragma mark - socket events names and keys

+ (NSString *)stringValueForEvent:(STMSocketEvent)event {
    
    switch (event) {
        case STMSocketEventConnect: {
            return @"connect";
            break;
        }
        case STMSocketEventDisconnect: {
            return @"disconnect";
            break;
        }
        case STMSocketEventError: {
            return @"error";
            break;
        }
        case STMSocketEventReconnect: {
            return @"reconnect";
            break;
        }
        case STMSocketEventReconnectAttempt: {
            return @"reconnectAttempt";
            break;
        }
        case STMSocketEventStatusChange: {
            return @"status:change";
            break;
        }
        case STMSocketEventInfo: {
            return @"info";
            break;
        }
        case STMSocketEventAuthorization: {
            return @"authorization";
            break;
        }
        case STMSocketEventRemoteCommands: {
            return @"remoteCommands";
            break;
        }
        case STMSocketEventData: {
            return @"data:v1";
            break;
        }
        case STMSocketEventJSData: {
            return @"jsData";
            break;
        }
        default: {
            return nil;
            break;
        }
    }
    
}

+ (STMSocketEvent)eventForString:(NSString *)stringValue {
    
    if ([stringValue isEqualToString:@"connect"]) {
        return STMSocketEventConnect;
    } else if ([stringValue isEqualToString:@"disconnect"]) {
        return STMSocketEventDisconnect;
    } else if ([stringValue isEqualToString:@"error"]) {
        return STMSocketEventError;
    } else if ([stringValue isEqualToString:@"reconnect"]) {
        return STMSocketEventReconnect;
    } else if ([stringValue isEqualToString:@"reconnectAttempt"]) {
        return STMSocketEventReconnectAttempt;
    } else if ([stringValue isEqualToString:@"status:change"]) {
        return STMSocketEventStatusChange;
    } else if ([stringValue isEqualToString:@"info"]) {
        return STMSocketEventInfo;
    } else if ([stringValue isEqualToString:@"authorization"]) {
        return STMSocketEventAuthorization;
    } else if ([stringValue isEqualToString:@"remoteCommands"]) {
        return STMSocketEventRemoteCommands;
    } else if ([stringValue isEqualToString:@"data:v1"]) {
        return STMSocketEventData;
    } else if ([stringValue isEqualToString:@"jsData"]) {
        return STMSocketEventJSData;
    } else {
        return STMSocketEventInfo;
    }
    
}

+ (NSString *)primaryKeyForEvent:(STMSocketEvent)event {
    
    NSString *primaryKey = @"url";
    
    switch (event) {
        case STMSocketEventConnect:
        case STMSocketEventStatusChange:
        case STMSocketEventInfo:
        case STMSocketEventAuthorization:
        case STMSocketEventRemoteCommands:
            break;
        case STMSocketEventData: {
            primaryKey = @"data";
            break;
        }
        default: {
            break;
        }
    }
    return primaryKey;
    
}


@end
