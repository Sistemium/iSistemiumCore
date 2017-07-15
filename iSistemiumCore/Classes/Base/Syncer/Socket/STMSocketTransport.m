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

@property (nonatomic,strong) dispatch_queue_t handleQueue;

@end


@implementation STMSocketTransport

+ (instancetype)transportWithUrl:(NSString *)socketUrlString andEntityResource:(NSString *)entityResource owner:(id <STMSocketConnectionOwner>)owner remoteDataEventHandling:(id <STMRemoteDataEventHandling>)remoteDataEventHandling{
    
    STMLogger *logger = [STMLogger sharedLogger];
    
    socketUrlString = [socketUrlString isKindOfClass:[NSNull class]] ? nil : socketUrlString;
    entityResource = [entityResource isKindOfClass:[NSNull class]] ? nil : entityResource;

    if (!socketUrlString || !entityResource || !owner) {
        
        NSString *logMessage = [NSString stringWithFormat:@"have not enough parameters to init socket transport"];
        [logger errorMessage:logMessage];

        return nil;
        
    }
    
    STMSocketTransport *socketTransport = [[self alloc] init];
    
    socketTransport.socketUrl = socketUrlString;
    socketTransport.entityResource = entityResource;
    socketTransport.owner = owner;
    socketTransport.logger = logger;
    socketTransport.remoteDataEventHandling = remoteDataEventHandling;
    
    [socketTransport startSocket];
    
    return socketTransport;
    
}

- (NSTimeInterval)timeout {
    return [self.owner timeout];
}

- (void)startSocket {
    
    [self.logger infoMessage:CurrentMethodName];

    NSURL *socketUrl = [NSURL URLWithString:self.socketUrl];
    NSString *path = [socketUrl.path stringByAppendingString:@"/"];

    if (!self.handleQueue) {
        self.handleQueue = dispatch_queue_create("com.sistemium.STMSocketTransport", DISPATCH_QUEUE_CONCURRENT);
    }
    
    NSDictionary *config = @{
                             @"handleQueue"        : self.handleQueue,
                             @"doubleEncodeUTF8"   : @YES,
                             @"voipEnabled"        : @YES,
                             @"log"                : @NO,
                             @"forceWebsockets"    : @NO,
                             @"path"               : path,
                             @"reconnects"         : @YES
                             };
    
    self.socket = [[SocketIOClient alloc] initWithSocketURL:socketUrl config:config];

    [self addEventObservers];
    
    [self.socket connect];
    
}


- (void)closeSocket {
    
    [self.logger infoMessage:CurrentMethodName];
    [self.socket removeAllHandlers];
    [self.socket disconnect];
    [self.owner socketWillClosed];
    
    self.socket = nil;
    self.isAuthorized = NO;
    
}


- (void)reconnectSocket {
    
    [self closeSocket];
    [self startSocket];
    
}


- (void)addEventObservers {
    
    [self.socket removeAllHandlers];
    
    NSString *logMessage = [NSString stringWithFormat:@"addEventObserversToSocket %@", self.socket];
    [self.logger infoMessage:logMessage];
    
    
#ifdef DEBUG
    [self addOnAnyEventHandler];
#endif
    
    NSArray *events = @[@(STMSocketEventConnect),
                        @(STMSocketEventDisconnect),
                        @(STMSocketEventError),
                        @(STMSocketEventReconnect),
                        @(STMSocketEventReconnectAttempt),
                        @(STMSocketEventRemoteCommands),
                        @(STMSocketEventRemoteRequests),
                        @(STMSocketEventData),
                        @(STMSocketEventJSData),
                        @(STMSocketEventUpdate),
                        @(STMSocketEventUpdateCollection),
                        @(STMSocketEventDestroy)];
    
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
                
            case STMSocketEventRemoteRequests: {
                [self remoteRequestsEventHandleWithData:data ack:ack];
                break;
            }
            
            case STMSocketEventUpdateCollection:
            case STMSocketEventUpdate: {
                [self updateEventHandleWithData:data ack:ack];
                break;
            }
                
            case STMSocketEventDestroy: {
                [self destroyEventHandleWithData:data ack:ack];
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
@synthesize remoteDataEventHandling = _remoteDataEventHandling;


- (BOOL)isReady {
    return self.socket.status == SocketIOClientStatusConnected && self.isAuthorized;
}

- (void)checkSocket {
    
    if (!self.isReady) {
        [self reconnectSocket];
    }
    
}

- (void)socketSendEvent:(STMSocketEvent)event withValue:(id)value {
    
    [self socketSendEvent:event withValue:value completionHandler:^(BOOL success, NSArray *data, NSError *error) {}];
    
}

- (void)socketSendEvent:(STMSocketEvent)event withValue:(id)value completionHandler:(void (^)(BOOL success, NSArray *data, NSError *error))completionHandler {
    
    [self logSendEvent:event withValue:value];
    
    if (!self.isReady) {
        
        NSString *errorMessage = @"socket not connected while sendEvent";
        
        [self socketLostConnection:errorMessage];
        
        return completionHandler(NO, nil, [STMFunctions errorWithMessage:errorMessage]);
        
    }
        
    if (event == STMSocketEventJSData) {
        
        if (![value isKindOfClass:[NSDictionary class]]) {
            return completionHandler(NO, nil, [STMFunctions errorWithMessage:@"STMSocketEventJSData value is not NSDictionary"]);
        }
            
        NSString *eventStringValue = [STMSocketTransport stringValueForEvent:event];
        
        OnAckCallback *onAck = [self.socket emitWithAck:eventStringValue with:@[value]];
        
        return [onAck timingOutAfter:self.timeout callback:^(NSArray *data) {
            
            if ([data.firstObject isEqual:@"NO ACK"]) {
                return completionHandler(NO, nil, [STMFunctions errorWithMessage:@"ack timeout"]);
            }
            
            completionHandler(YES, data, nil);
        
        }];
        
    }
        
    NSString *primaryKey = [STMSocketTransport primaryKeyForEvent:event];
    
    NSString *eventStringValue = [STMSocketTransport stringValueForEvent:event];
    
    if (value && primaryKey) {
        
        NSDictionary *dataDic = @{primaryKey : value};
        
        dataDic = [STMFunctions validJSONDictionaryFromDictionary:dataDic];
        
        if (!dataDic) {
            NSString *message = [NSString stringWithFormat:@"%@ ___ no dataDic to send via socket for event: %@", self.socket, eventStringValue];
            NSLog(message);
            return completionHandler(NO, nil, [STMFunctions errorWithMessage:message]);
        }
        
        [self.socket emit:eventStringValue with:@[dataDic]];
        
    }else if (value){
    
        [self.socket emit:eventStringValue with:@[value]];
        
    }else{
        
        [self.socket emit:eventStringValue with:@[]];
        
    }
    
    
    
}

#pragma mark - socket events handlers

- (void)connectEventHandleWithData:(NSArray *)data ack:(SocketAckEmitter *)ack {
    
    NSMutableDictionary *dataDic = [STMClientDataController clientData].mutableCopy;
    
    NSDictionary *authDic = @{@"userId"         : [STMCoreAuthController authController].userID,
                              @"accessToken"    : [STMCoreAuthController authController].accessToken};
    
    [dataDic addEntriesFromDictionary:authDic];
    
    NSString *logMessage = [NSString stringWithFormat:@"send authorization data %@ with socket %@ %@", dataDic, self.socket, self.socket.sid];
    [self.logger infoMessage:logMessage];
    
    STMSocketEvent eventNum = STMSocketEventAuthorization;
    NSString *event = [STMSocketTransport stringValueForEvent:eventNum];
    
    [[self.socket emitWithAck:event with:@[dataDic]] timingOutAfter:self.timeout callback:^(NSArray *data) {
        
        [self receiveAckWithData:data forEventNum:eventNum];
        
        NSArray *downloadableEntityNames = [STMEntityController downloadableEntityNames];
        
        NSArray *downloadableEntityResources = [STMFunctions mapArray:downloadableEntityNames withBlock:^id _Nonnull(NSString *_Nonnull value) {
            return [STMEntityController resourceForEntity:value];
        }];
        
        [self socketSendEvent:STMSocketEventSubscribe withValue:downloadableEntityResources];
        
    }];

}

- (void)disconnectEventHandleWithData:(NSArray *)data ack:(SocketAckEmitter *)ack {
    [self.owner socketLostConnection];
}

- (void)reconnectEventHandleWithData:(NSArray *)data ack:(SocketAckEmitter *)ack {
    // May be it's too early to report lost connection because we'll reconnect soon
    // [self.owner socketLostConnection];
}

- (void)remoteCommandsEventHandleWithData:(NSArray *)data ack:(SocketAckEmitter *)ack {
        
    if ([data.firstObject isKindOfClass:[NSDictionary class]]) {
        [STMRemoteController receiveRemoteCommands:data.firstObject];
    }

}

- (void)remoteRequestsEventHandleWithData:(NSArray *)data ack:(SocketAckEmitter *)ack {
    
    if ([data.firstObject isKindOfClass:[NSDictionary class]]) {
        NSDictionary* response = [STMRemoteController receiveRemoteRequests:data.firstObject];
        
        response = [STMFunctions validJSONDictionaryFromDictionary:response];
        
        [ack with:@[response]];
    }
    
}

- (void)updateEventHandleWithData:(NSArray *)data ack:(SocketAckEmitter *)ack {
    
    NSDictionary *receivedData = data.firstObject;
    
    if ([STMFunctions isNotNull:receivedData[@"resource"]]){
        
        NSString *entityName = [receivedData[@"resource"] componentsSeparatedByString:@"/"].lastObject;
        
        NSDictionary *data = receivedData[@"data"];
        
        if (data && data[@"id"]){
            
            [self.remoteDataEventHandling remoteUpdated:entityName attributes:data];
            
        } else {
            [self.remoteDataEventHandling remoteHasNewData:entityName];
        }
        
    }
    
}

- (void)destroyEventHandleWithData:(NSArray *)data ack:(SocketAckEmitter *)ack {
    
    NSDictionary *receivedData = data.firstObject;
    
    if ([STMFunctions isNotNull:receivedData[@"resource"]]){
        
        NSString *entityName = [receivedData[@"resource"] componentsSeparatedByString:@"/"].lastObject;
        
        NSString *identifier = receivedData[@"data"][@"id"];
        
        if (identifier){
            
            [self.remoteDataEventHandling remoteDestroyed:entityName identifier:identifier];
            
        }
        
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
    
    if ([data.firstObject isEqual:@"NO ACK"]) {
        return [self notAuthorizedWithError:@"receiveAuthorizationAckWithData authorization timeout"];
    }

    NSString *logMessage = [NSString stringWithFormat:@"socket %@ %@ receiveAuthorizationAckWithData %@", self.socket, self.socket.sid, data];

    [self.logger infoMessage:logMessage];

    if (![data.firstObject isKindOfClass:[NSDictionary class]]) {
        return [self notAuthorizedWithError:@"socket receiveAuthorizationAck with data.firstObject is not a NSDictionary"];
    }
    
    NSDictionary *dataDic = data.firstObject;
    BOOL isAuthorized = [dataDic[@"isAuthorized"] boolValue];
    
    if (!isAuthorized) {
        return [self notAuthorizedWithError:@"socket receiveAuthorizationAck with dataDic.isAuthorized.boolValue == NO"];
    }
        
    self.isAuthorized = YES;
    logMessage = [NSString stringWithFormat:@"socket %@ %@ authorized", self.socket, self.socket.sid];
    
    [self.logger infoMessage:logMessage];

    [self.owner socketReceiveAuthorization];
    [self checkAppState];
    
}

- (void)checkAppState {
    
    NSString *appState = [STMFunctions appStateString];
    
    [self socketSendEvent:STMSocketEventStatusChange withValue:appState];
    
    if (![appState isEqualToString:@"UIApplicationStateActive"]) return;
        
    UIViewController *selectedVC = [STMCoreRootTBC sharedRootVC].selectedViewController;
    
    if (![selectedVC class]) return;
        
    Class _Nonnull rootVCClass = (Class _Nonnull)[selectedVC class];
    
    NSString *value = [NSString stringWithFormat:@"selectedViewController: %@ %@ %@", selectedVC.title, selectedVC, NSStringFromClass(rootVCClass)];
    
    [self socketSendEvent:STMSocketEventStatusChange withValue:value];

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

- (void)notAuthorizedWithError:(NSString *)errorString {
    
    NSString *logMessage = [NSString stringWithFormat:@"socket connection %@ not authorized: %@", self.socket.sid, errorString];
    self.isAuthorized = NO;
    [self.owner socketAuthorizationError:[STMFunctions errorWithMessage:logMessage]];
    
}


#pragma mark - checking connection

- (void)checkReachabilityAndSocketStatus {
    
    switch (self.socket.status) {
        case SocketIOClientStatusNotConnected:
        case SocketIOClientStatusDisconnected:
            
            if ([Reachability reachabilityWithHostname:self.socketUrl].isReachable) {
                
                [self.logger importantMessage:@"socket is not connected but host is reachable, reconnect it"];
                [self reconnectSocket];
                
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

    [self.logger infoMessage:infoString];
    
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
        case STMSocketEventRemoteRequests: {
            return @"remoteRequests";
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
        case STMSocketEventSubscribe: {
            return @"jsData:subscribe";
            break;
        }
        case STMSocketEventUpdate: {
            return @"jsData:update";
            break;
        }
        case STMSocketEventUpdateCollection: {
            return @"jsData:updateCollection";
            break;
        }
        case STMSocketEventDestroy: {
            return @"jsData:destroy";
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
        case STMSocketEventSubscribe:
            primaryKey = nil;
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
