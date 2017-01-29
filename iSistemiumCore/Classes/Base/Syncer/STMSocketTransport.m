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
#import "STMRemoteController.h"


@interface STMSocketTransport()

@property (nonatomic, weak) id <STMSocketTransportOwner> owner;
@property (nonatomic, weak) STMLogger *logger;
@property (nonatomic, strong) SocketIOClient *socket;
@property (nonatomic, strong) NSString *socketUrl;
@property (nonatomic, strong) NSString *entityResource;
@property (nonatomic) BOOL isAuthorized;
@property (nonatomic) NSTimeInterval timeout;


@end


@implementation STMSocketTransport

+ (instancetype)initWithUrl:(NSString *)socketUrlString andEntityResource:(NSString *)entityResource owner:(id <STMSocketTransportOwner>)owner {
    
    STMLogger *logger = [STMLogger sharedLogger];

    if (!socketUrlString || !entityResource || !owner) {
        
        NSString *logMessage = [NSString stringWithFormat:@"have not enough parameters to init socket transport"];
        [logger saveLogMessageWithText:logMessage
                               numType:STMLogMessageTypeError];

        return nil;
        
    }
    
    STMSocketTransport *socketTransport = [[self alloc] init];
    
    socketTransport.socketUrl = socketUrlString;
    socketTransport.entityResource = entityResource;
    socketTransport.owner = owner;
    socketTransport.logger = [STMLogger sharedLogger];
    
    [socketTransport startSocket];
    
    return socketTransport;
    
}

- (NSTimeInterval)timeout {
    return [self.owner timeout];
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

- (void)closeSocketInBackground {
    
    STMLogger *logger = [STMLogger sharedLogger];
    
    [logger saveLogMessageWithText:@"close socket in background"
                           numType:STMLogMessageTypeInfo];
    
//    self.wasClosedInBackground = YES;
//    [STMSocketController socketLostConnection:@"closeSocketInBackground"];
    
    [self closeSocket];
    
}

- (void)reconnectSocket {
    
    [self closeSocket];
    [self startSocket];
    
}

- (void)flushSocket {
    
    [self.socket removeAllHandlers];

    self.socket = nil;
    self.isAuthorized = NO;
    
}

- (void)checkSocket {
    
    if (!self.isReady) {
        [self reconnectSocket];
    }
    
//    if (self.wasClosedInBackground) {
//        
//        self.wasClosedInBackground = NO;
//        [self startSocket];
//        
//    } else if (![STMSocketController socketIsAvailable]) {
//        [self reconnectSocket];
//    }
    
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

            case STMSocketEventDisconnect: {
                [self disconnectEventHandleWithData:data ack:ack];
                break;
            }

            case STMSocketEventReconnect: {
                [self reconnectEventHandleWithData:data ack:ack];
                break;
            }

            case STMSocketEventRemoteCommands: {
                [self remoteCommandsEventHandleWithData:data ack:ack];
                break;
            }
                
            case STMSocketEventReconnectAttempt:
            case STMSocketEventError:
            case STMSocketEventStatusChange:
            case STMSocketEventInfo:
            case STMSocketEventAuthorization:
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
    
    [[self.socket emitWithAck:event with:@[dataDic]] timingOutAfter:0 callback:^(NSArray *data) {
        [self receiveAckWithData:data forEventNum:eventNum];
    }];

}

- (void)disconnectEventHandleWithData:(NSArray *)data ack:(SocketAckEmitter *)ack {
    [self.owner socketLostConnection];
}

- (void)reconnectEventHandleWithData:(NSArray *)data ack:(SocketAckEmitter *)ack {
    [self.owner socketLostConnection];
}

- (void)remoteCommandsEventHandleWithData:(NSArray *)data ack:(SocketAckEmitter *)ack {
        
    if ([data.firstObject isKindOfClass:[NSDictionary class]]) {
        [STMRemoteController receiveRemoteCommands:data.firstObject];
    }

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

            [self.owner socketReceiveAuthorization];
            
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
    
    [self socketSendEvent:STMSocketEventStatusChange withValue:appState];
    
    if ([appState isEqualToString:@"UIApplicationStateActive"]) {
        
        UIViewController *selectedVC = [STMCoreRootTBC sharedRootVC].selectedViewController;
        
        if ([selectedVC class]) {
            
            Class _Nonnull rootVCClass = (Class _Nonnull)[selectedVC class];
            
            NSString *value = [NSString stringWithFormat:@"selectedViewController: %@ %@ %@", selectedVC.title, selectedVC, NSStringFromClass(rootVCClass)];
            
            [self socketSendEvent:STMSocketEventStatusChange withValue:value];
            
        }
        
    }

}


#pragma mark - send events

- (void)socketSendEvent:(STMSocketEvent)event withValue:(id)value {
    
    [self socketSendEvent:event
                withValue:value
        completionHandler:nil];
    
}

- (void)socketSendEvent:(STMSocketEvent)event withValue:(id)value completionHandler:(void (^)(BOOL success, NSArray *data, NSError *error))completionHandler {
    
    [self logSendEvent:event withValue:value];
    
    if (self.isReady) {
        
        if (event == STMSocketEventJSData) {
            
            if ([value isKindOfClass:[NSDictionary class]]) {
                
                NSString *eventStringValue = [STMSocketTransport stringValueForEvent:event];
                
                [[self.socket emitWithAck:eventStringValue with:@[value]] timingOutAfter:self.timeout callback:^(NSArray *data) {

                    if ([data.firstObject isEqual:@"NO ACK"]) {

                        NSError *error = nil;
                        [STMCoreObjectsController error:&error withMessage:@"ack timeout"];
                        
                        completionHandler(NO, nil, error);
                        
                    } else {
                    
                        completionHandler(YES, data, nil);

                    }
                    
                }];
                
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
        
        NSString *errorMessage = @"socket not connected while sendEvent";
        
        [self socketLostConnection:errorMessage];
        
        NSError *error = nil;
        [STMCoreObjectsController error:&error
                            withMessage:errorMessage];
        
        if (completionHandler) {
            completionHandler(NO, nil, error);
        }
        
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
    
    [self.owner socketLostConnection];
    
}


#pragma mark - STMPersistingWithHeadersAsync
#pragma mark find

- (void)findAsync:(NSString *)entityName identifier:(NSString *)identifier options:(NSDictionary *)options completionHandlerWithHeaders:(void (^)(BOOL success, NSDictionary *result, NSDictionary *headers, NSError *error))completionHandler {

    NSString *errorMessage = [self preFindAsyncCheckForEntityName:entityName
                                                       identifier:identifier];

    if (errorMessage) {
    
        [self completeFindAsyncHandler:completionHandler
                      withErrorMessage:errorMessage];
        return;
        
    }
    
    STMEntity *entity = [STMEntityController stcEntities][entityName];
    
    NSString *resource = [entity resource];

    NSDictionary *value = @{@"method"   : kSocketFindMethod,
                            @"resource" : resource,
                            @"id"       : identifier};
    
    [self socketSendEvent:STMSocketEventJSData withValue:value completionHandler:^(BOOL success, NSArray *data, NSError *error) {
        
        if (success) {
        
            NSDictionary *response = ([data.firstObject isKindOfClass:[NSDictionary class]]) ? data.firstObject : nil;
            
            if (!response) {
                
                [self completeFindAsyncHandler:completionHandler
                              withErrorMessage:@"ERROR: response contain no dictionary"];
                return;

            }
            
            if (response[@"error"]) {
                
                [self completeFindAsyncHandler:completionHandler
                              withErrorMessage:[NSString stringWithFormat:@"response got error: %@", response[@"error"]]];
                return;

            }
            
            completionHandler(YES, response, nil, nil);

        } else {
            completionHandler(NO, nil, nil, error);
        }
        
    }];
    
}

- (NSString *)preFindAsyncCheckForEntityName:(NSString *)entityName identifier:(NSString *)identifier {
    
    if (!self.isReady) {
        return @"socket is not ready (not connected or not authorize)";
    }
    
    STMEntity *entity = [STMEntityController stcEntities][entityName];

    if (!entity) {
        return [NSString stringWithFormat:@"have no such entity %@", entityName];
    }

    if (![entity resource]) {
        return [NSString stringWithFormat:@"no resource for entity %@", entityName];
    }
    
    if (!identifier) {
        return [NSString stringWithFormat:@"no identifier for findAsync: %@", entityName];
    }

    return nil;
    
}

- (void)completeFindAsyncHandler:(void (^)(BOOL success, NSDictionary *result, NSDictionary *headers, NSError *error))completionHandler withErrorMessage:(NSString *)errorMessage {
    
    NSError *localError = nil;
    [STMFunctions error:&localError withMessage:errorMessage];
    
    completionHandler(NO, nil, nil, localError);
    
}

#pragma mark findAll

- (void)findAllAsync:(NSString *)entityName predicate:(NSPredicate *)predicate options:(NSDictionary *)options completionHandlerWithHeaders:(void (^)(BOOL success, NSArray *result, NSDictionary *headers, NSError *error))completionHandler {
    
    NSString *errorMessage = [self preFindAllAsyncCheckForEntityName:entityName];
    
    if (errorMessage) {
        
        [self completeFindAllAsyncHandler:completionHandler
                         withErrorMessage:errorMessage];
        return;
        
    }
    
    STMEntity *entity = [STMEntityController stcEntities][entityName];
    NSString *resource = [entity resource];

    NSDictionary *value = @{@"method"   : kSocketFindAllMethod,
                            @"resource" : resource,
                            @"options"  : options
                            };
    
    [self socketSendEvent:STMSocketEventJSData withValue:value completionHandler:^(BOOL success, NSArray *data, NSError *error) {
        
        if (success) {
            
            NSDictionary *response = ([data.firstObject isKindOfClass:[NSDictionary class]]) ? data.firstObject : nil;

            if (!response) {

                [self completeFindAllAsyncHandler:completionHandler
                            withErrorMessage:@"ERROR: response contain no dictionary"];
                return;

            }

            NSNumber *errorCode = response[@"error"];
            
            if (errorCode) {

                [self completeFindAllAsyncHandler:completionHandler
                            withErrorMessage:[NSString stringWithFormat:@"    %@: ERROR: %@", entityName, errorCode]];
                return;

            }
            
            NSArray *responseData = ([response[@"data"] isKindOfClass:[NSArray class]]) ? response[@"data"] : nil;
            
            if (!responseData) {

                [self completeFindAllAsyncHandler:completionHandler
                            withErrorMessage:[NSString stringWithFormat:@"    %@: ERROR: find all response data is not an array", entityName]];
                return;

            }
            
            NSMutableDictionary *headers = @{}.mutableCopy;
            
            [response enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            
                if (![key isEqualToString:@"data"]) {
                    headers[key] = obj;
                }
                
            }];
            
            completionHandler(YES, responseData, headers, nil);

        } else {
            completionHandler(NO, nil, nil, error);
        }

    }];
    
}

- (NSString *)preFindAllAsyncCheckForEntityName:(NSString *)entityName {
    
    if (!self.isReady) {
        return @"socket is not ready (not connected or not authorize)";
    }
    
    STMEntity *entity = [STMEntityController stcEntities][entityName];
    
    if (!entity) {
        return [NSString stringWithFormat:@"have no such entity %@", entityName];
    }
    
    if (![entity resource]) {
        return [NSString stringWithFormat:@"no resource for entity %@", entityName];
    }
    
    return nil;
    
}

- (void)completeFindAllAsyncHandler:(void (^)(BOOL success, NSArray *result, NSDictionary *headers, NSError *error))completionHandler withErrorMessage:(NSString *)errorMessage {
    
    NSError *localError = nil;
    [STMFunctions error:&localError withMessage:errorMessage];
    
    completionHandler(NO, nil, nil, localError);
    
}

#pragma mark merge

- (void)mergeAsync:(NSString *)entityName attributes:(NSDictionary *)attributes options:(NSDictionary *)options completionHandlerWithHeaders:(void (^)(BOOL success, NSDictionary *result, NSDictionary *headers, NSError *error))completionHandler {

    if (!self.isReady) {
        
        [self completeMergeAsyncHandler:completionHandler
                       withErrorMessage:@"socket is not ready (not connected or not authorize)"];
        return;
        
    }
    
    STMEntity *entity = [STMEntityController stcEntities][entityName];
    
    NSString *resource = [entity resource];
    
    if (!resource) {

        [self completeMergeAsyncHandler:completionHandler
                       withErrorMessage:[NSString stringWithFormat:@"no url for entity %@", entityName]];
        return;
        
    }
    

    NSDictionary *value = @{@"method"   : kSocketUpdateMethod,
                            @"resource" : resource,
                            @"id"       : attributes[@"id"],
                            @"attrs"    : attributes};

    [self socketSendEvent:STMSocketEventJSData withValue:value completionHandler:^(BOOL success, NSArray *data, NSError *error) {
        
        if (success) {
            
            NSDictionary *response = ([data.firstObject isKindOfClass:[NSDictionary class]]) ? data.firstObject : nil;
            
            if (!response) {
                
                [self completeMergeAsyncHandler:completionHandler
                               withErrorMessage:@"ERROR: response contain no dictionary"];
                return;
                
            }
            
            completionHandler(YES, response, nil, nil);

        } else {
            completionHandler(NO, nil, nil, error);
        }
        
    }];
    
}

- (void)completeMergeAsyncHandler:(void (^)(BOOL success, NSDictionary *result, NSDictionary *headers, NSError *error))completionHandler withErrorMessage:(NSString *)errorMessage {
    
    NSError *localError = nil;
    [STMFunctions error:&localError withMessage:errorMessage];
    
    completionHandler(NO, nil, nil, localError);

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