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

@property (nonatomic, weak) STMLogger *logger;
@property (nonatomic, strong) SocketIOClient *socket;
@property (nonatomic, strong) NSString *socketUrl;
@property (nonatomic, strong) NSString *entityResource;
@property (nonatomic) BOOL isAuthorized;
@property (nonatomic) NSTimeInterval timeout;


@end


@implementation STMSocketTransport

+ (instancetype)transportWithUrl:(NSString *)socketUrlString andEntityResource:(NSString *)entityResource owner:(id <STMSocketConnectionOwner>)owner {
    
    STMLogger *logger = [STMLogger sharedLogger];
    
    socketUrlString = [socketUrlString isKindOfClass:[NSNull class]] ? nil : socketUrlString;
    entityResource = [entityResource isKindOfClass:[NSNull class]] ? nil : entityResource;

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

    [self.owner socketWillClosed];

    [self.socket disconnect];
    [self flushSocket];
    
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


#pragma mark - STMSocketConnection protocol

@synthesize isReady = _isReady;
@synthesize owner = _owner;


- (BOOL)isReady {
    return self.socket.status == SocketIOClientStatusConnected && self.isAuthorized;
}

- (void)checkSocket {
    
    if (!self.isReady) {
        [self reconnectSocket];
    }
    
}

- (void)closeSocketInBackground {
    
    STMLogger *logger = [STMLogger sharedLogger];
    
    [logger saveLogMessageWithText:@"close socket in background"
                           numType:STMLogMessageTypeInfo];
    
    [self closeSocket];
    
}

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
                        [STMFunctions error:&error withMessage:@"ack timeout"];
                        
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
        [STMFunctions error:&error
                withMessage:errorMessage];
        
        if (completionHandler) {
            completionHandler(NO, nil, error);
        }
        
    }
    
}

#pragma mark - socket events handlers

- (void)connectEventHandleWithData:(NSArray *)data ack:(SocketAckEmitter *)ack {
    
    [self startDelayedAuthorizationCheck];
    
    // TODO: Maybe we need here persistence delegate
    
    NSMutableDictionary *dataDic = [STMClientDataController clientDataDictionary].mutableCopy;
    
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

    [self.logger saveLogMessageWithText:infoString
                                numType:STMLogMessageTypeInfo];
    
    [self checkReachabilityAndSocketStatus];
    
    [self.owner socketLostConnection];
    
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
