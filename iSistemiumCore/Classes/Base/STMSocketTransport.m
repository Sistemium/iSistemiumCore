//
//  STMSocketTransport.m
//  iSisSales
//
//  Created by Maxim Grigoriev on 11/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMSocketTransport.h"

#import "STMClientDataController.h"


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


@interface STMSocketTransport()

@property (nonatomic, weak) STMSyncer *syncer;
@property (nonatomic, weak) STMLogger *logger;
@property (nonatomic, strong) SocketIOClient *socket;
@property (nonatomic, strong) NSString *socketUrl;
@property (nonatomic, strong) NSString *entityResource;
@property (nonatomic) BOOL isAuthorized;


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
            
            logMessage = [NSString stringWithFormat:@"socket %@ %@ authorized", self.socket, self.socket.sid];
            [self.logger saveLogMessageWithText:logMessage
                                        numType:STMLogMessageTypeInfo];
            
            self.isAuthorized = YES;

            [self.syncer socketReceiveAuthorization];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:@"socketAuthorizationSuccess"
                                                                object:self];
            
//            [self socket:socket sendEvent:STMSocketEventStatusChange withStringValue:[STMFunctions appStateString]];
//            
//            if ([[STMFunctions appStateString] isEqualToString:@"UIApplicationStateActive"]) {
//                
//                UIViewController *selectedVC = [STMCoreRootTBC sharedRootVC].selectedViewController;
//                
//                if ([selectedVC class]) {
//                    
//                    Class _Nonnull rootVCClass = (Class _Nonnull)[selectedVC class];
//                    
//                    NSString *stringValue = [NSString stringWithFormat:@"selectedViewController: %@ %@ %@", selectedVC.title, selectedVC, NSStringFromClass(rootVCClass)];
//                    
//                    [self socket:socket sendEvent:STMSocketEventStatusChange withStringValue:stringValue];
//                    
//                }
//                
//            }
            
        } else {
            [self notAuthorizedWithError:@"socket receiveAuthorizationAck with dataDic.isAuthorized.boolValue == NO"];
        }
        
    } else {
        [self notAuthorizedWithError:@"socket receiveAuthorizationAck with data.firstObject is not a NSDictionary"];
    }
    
}


#pragma mark - authorization check

- (void)startDelayedAuthorizationCheck {
    
    SEL checkAuthSel = @selector(checkAuthorization);
    
    [STMSocketTransport cancelPreviousPerformRequestsWithTarget:self
                                                       selector:checkAuthSel
                                                         object:nil];
    
    [self performSelector:checkAuthSel
               withObject:nil
               afterDelay:CHECK_SOCKET_AUTHORIZATION_DELAY];
    
}

- (void)checkAuthorization {
    
    NSLogMethodName;
    
//    
//    if ([self isItCurrentSocket:socket failString:@"checkAuthorization"]) {
//        
//        STMLogger *logger = [STMLogger sharedLogger];
//        
//        NSString *logMessage = [NSString stringWithFormat:@"checkAuthorizationForSocket: %@ %@", socket, socket.sid];
//        [logger saveLogMessageWithText:logMessage
//                               numType:STMLogMessageTypeInfo];
//        
//        if (socket.status == SocketIOClientStatusConnected) {
//            
//            if (self.isAuthorized) {
//                
//                logMessage = [NSString stringWithFormat:@"socket %@ %@ is authorized", socket, socket.sid];
//                [logger saveLogMessageWithText:logMessage
//                                       numType:STMLogMessageTypeInfo];
//                
//            } else {
//                
//                logMessage = [NSString stringWithFormat:@"socket %@ %@ is connected but don't receive authorization ack, reconnecting", socket, socket.sid];
//                [logger saveLogMessageWithText:logMessage
//                                       numType:STMLogMessageTypeError];
//                
//                [self reconnectSocket];
//                
//            }
//            
//        } else {
//            
//            logMessage = [NSString stringWithFormat:@"socket %@ %@ is not connected", socket, socket.sid];
//            [logger saveLogMessageWithText:logMessage
//                                   numType:STMLogMessageTypeInfo];
//            
//        }
//        
//    }
    
}

- (void)notAuthorizedWithError:(NSString *)errorString {
    
    NSString *logMessage = [NSString stringWithFormat:@"socket %@ %@ not authorized\n%@", self.socket, self.socket.sid, errorString];
    [self.logger saveLogMessageWithText:logMessage
                                numType:STMLogMessageTypeWarning];
    
//    [self sharedInstance].isAuthorized = NO;
    [[STMCoreAuthController authController] logout];
    
}


#pragma mark - socket events names

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


@end
