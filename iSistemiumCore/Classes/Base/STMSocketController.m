//
//  STMSocketController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 10/10/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMSocketController.h"
#import "STMCoreAuthController.h"
#import "STMClientDataController.h"
#import "STMCoreObjectsController.h"
#import "STMRemoteController.h"
#import "STMEntityController.h"

#import "STMCoreSessionManager.h"

#import "STMCoreRootTBC.h"

#import "STMFunctions.h"


#define SOCKET_URL @"https://socket.sistemium.com/socket.io-client"
#define CHECK_AUTHORIZATION_DELAY 15
#define CHECK_SENDING_TIME_INTERVAL 600


@interface STMSocketController() <NSFetchedResultsControllerDelegate>

@property (nonatomic, strong) SocketIOClient *socket;
@property (nonatomic, strong) NSString *socketUrl;
@property (nonatomic, strong) NSString *entityResource;
@property (nonatomic) BOOL isRunning;
@property (nonatomic, strong) NSMutableDictionary *syncDataDictionary;
@property (nonatomic, strong) NSMutableArray *resultsControllers;
@property (nonatomic) BOOL controllersDidChangeContent;
@property (nonatomic) BOOL isAuthorized;
@property (nonatomic) BOOL isSendingData;
@property (nonatomic, strong) NSDate *sendingDate;
@property (nonatomic) BOOL shouldSendData;
@property (nonatomic) BOOL isReconnecting;


@end


@implementation STMSocketController


#pragma mark - class methods

+ (STMSocketController *)sharedInstance {
    
    static dispatch_once_t pred = 0;
    __strong static id _sharedInstance = nil;
    
    dispatch_once(&pred, ^{
        _sharedInstance = [[self alloc] init];
    });
    
    return _sharedInstance;
    
}

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
        case STMSocketEventReconnect: {
            return @"reconnect";
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
    } else if ([stringValue isEqualToString:@"reconnect"]) {
        return STMSocketEventReconnect;
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

+ (STMSyncer *)syncer {
    return [[STMCoreSessionManager sharedManager].currentSession syncer];
}

+ (STMDocument *)document {
    return [[STMCoreSessionManager sharedManager].currentSession document];
}

+ (SocketIOClientStatus)currentSocketStatus {
    return [self sharedInstance].socket.status;
}

+ (BOOL)socketIsAvailable {
    return ([self currentSocketStatus] == SocketIOClientStatusConnected && [self sharedInstance].isAuthorized);
}

+ (BOOL)isSendingData {
    return [self sharedInstance].isSendingData;
}

+ (void)startSocketWithUrl:(NSString *)socketUrlString andEntityResource:(NSString *)entityResource {
    
    STMSocketController *sc = [self sharedInstance];

    sc.socketUrl = socketUrlString;
    sc.entityResource = entityResource;
    
    [self startSocket];
    
}

+ (void)startSocket {
    
    STMSocketController *sc = [self sharedInstance];
    
    if (sc.socketUrl && !sc.isRunning && !sc.isReconnecting) {

        NSLogMethodName;

        sc.isRunning = YES;

        switch (sc.socket.status) {
                
            case SocketIOClientStatusNotConnected:
            case SocketIOClientStatusClosed: {
                [sc.socket connect];
//                [sc performSelector:@selector(checkAuthorizationForSocket:) withObject:sc.socket afterDelay:CHECK_AUTHORIZATION_DELAY];
                break;
            }
            case SocketIOClientStatusConnecting: {
                
                break;
            }
            case SocketIOClientStatusConnected: {
                
                break;
            }
            case SocketIOClientStatusReconnecting: {
                
                break;
            }
            default: {
                break;
            }
                
        }

    } else {
        
        [[self syncer] setSyncerState:STMSyncerReceiveData];
        
    }

}

+ (void)closeSocket {
    
    NSLogMethodName;

    STMSocketController *sc = [self sharedInstance];
    
    if (sc.isRunning) {
        
        //    [self sharedInstance].shouldStarted = NO;
        [sc.socket disconnect];
        sc.socketUrl = nil;
        sc.socket = nil;
        sc.isSendingData = NO;
        sc.isAuthorized = NO;
        sc.isRunning = NO;

    }

}

+ (void)reconnectSocket {
    [[self sharedInstance] reconnectSocket];
}

+ (void)sendEvent:(STMSocketEvent)event withStringValue:(NSString *)stringValue {
    [self socket:[self sharedInstance].socket sendEvent:event withStringValue:stringValue];
}

+ (void)sendEvent:(STMSocketEvent)event withValue:(id)value {
    [self socket:[self sharedInstance].socket sendEvent:event withValue:value];
}

+ (void)reloadResultsControllers {
    [[self sharedInstance] reloadResultsControllers];
}


#pragma mark - send

+ (NSArray *)unsyncedObjects {
    return [[self sharedInstance] unsyncedObjectsArray];
}

+ (NSUInteger)numbersOfUnsyncedObjects {
    return [self unsyncedObjects].count;
}

+ (void)sendUnsyncedObjects:(id)sender {

    [self checkSendingTimeInterval];
    
    if ([STMSocketController syncer].syncerState != STMSyncerReceiveData &&
        [self socketIsAvailable] &&
        ![self sharedInstance].isSendingData) {
        
        if (![self haveToSyncObjects]) {

            if ([sender isEqual:[self syncer]]) {
                [[self syncer] nothingToSend];
            }
            
        }

    } else {
        
        if ([sender isEqual:[self syncer]]) {
            [[self syncer] nothingToSend];
        }

    }

}

+ (void)checkSendingTimeInterval {
    
    STMSocketController *sc = [self sharedInstance];
    
    if (sc.sendingDate && sc.isSendingData) {
        
        NSTimeInterval sendingInterval = [sc.sendingDate timeIntervalSinceNow];
        
        if (sendingInterval > CHECK_SENDING_TIME_INTERVAL) {

            NSString *errorMessage = @"exceed sending time interval";
            [[STMLogger sharedLogger] saveLogMessageWithText:errorMessage type:@"error"];
            
            [self sendFinishedWithError:errorMessage];
            
        }
        
    }
    
}

+ (BOOL)haveToSyncObjects {
    
    NSArray *unsyncedObjectsArray = [self unsyncedObjects];

    NSArray <STMDatum *> *syncDataArray = [self syncDataArrayFromUnsyncedObjects:unsyncedObjectsArray];

    if (syncDataArray.count > 0) {

        NSLog(@"%d objects to send via Socket", syncDataArray.count);

// old way sending
//        [self sendEvent:STMSocketEventData withValue:syncDataArray];
        
// new way sending
        [self sendObjectsFromArray:syncDataArray];
        
        return YES;
        
    } else {
        
        return NO;
        
    }
    
}

+ (NSMutableArray <STMDatum *> *)syncDataArrayFromUnsyncedObjects:(NSArray *)unsyncedObjectsArray {
    
    NSMutableArray *syncDataArray = [NSMutableArray array];
    
    for (STMDatum *unsyncedObject in unsyncedObjectsArray) {

        if (unsyncedObject.xid) {
            
            NSData *xid = unsyncedObject.xid;
            
            if (![[self sharedInstance].syncDataDictionary.allKeys containsObject:xid]) {
                
//                [self addObject:unsyncedObject toSyncDataArray:syncDataArray];
                [syncDataArray addObject:unsyncedObject];
                
                if (unsyncedObject.deviceTs) {
                    [self sharedInstance].syncDataDictionary[xid] = unsyncedObject.deviceTs;
                }
                
            }

        }
        
        if (syncDataArray.count >= 100) {
            
            NSLog(@"syncDataArray is full");
            break;
            
        }
        
    }
    
    return syncDataArray;

}

//+ (void)addObject:(NSManagedObject *)object toSyncDataArray:(NSMutableArray <NSDictionary *> *)syncDataArray {
//    
////    NSDate *currentDate = [NSDate date];
////    [object setValue:currentDate forKey:@"sts"];
//    
//    NSDictionary *objectDictionary = [STMCoreObjectsController dictionaryForObject:object];
//    
//    [syncDataArray addObject:objectDictionary];
//
//}

+ (NSDate *)deviceTsForSyncedObjectXid:(NSData *)xid {

    NSDate *deviceTs = [self sharedInstance].syncDataDictionary[xid];
    return deviceTs;
    
}

+ (void)successfullySyncObjectWithXid:(NSData *)xid {
    
    NSMutableDictionary *sdd = [self sharedInstance].syncDataDictionary;
    
    if (xid) [sdd removeObjectForKey:xid];
    
    if (sdd.allKeys.count == 0) {
        [self sendFinishedWithError:nil];
    }
    
}

+ (void)sendObjectsFromArray:(NSArray <STMDatum *> *)syncDataArray {
    
    NSMutableArray *syncArray = syncDataArray.mutableCopy;
    
    for (STMDatum *object in syncDataArray) {
        [self checkObject:object forSendingWithSyncArray:syncArray];
    }
    
    if (syncArray.count > 0) {
        [self sendObjectsFromArray:syncArray];
    }
    
}

+ (void)checkObject:(STMDatum *)object forSendingWithSyncArray:(NSMutableArray *)syncArray {
    
    NSEntityDescription *objectEntity = object.entity;
    NSString *entityName = objectEntity.name;
    NSDictionary *relationships = [STMCoreObjectsController singleRelationshipsForEntityName:entityName];
    
    BOOL safelyToSend = YES;
    
    for (NSString *relName in relationships.allKeys) {
        
        STMDatum *relObject = [object valueForKey:relName];
        if (![syncArray containsObject:relObject]) continue;
        
        NSEntityDescription *relObjectEntity = relObject.entity;
        NSArray *checkingRelationships = [relObjectEntity relationshipsWithDestinationEntity:objectEntity];
        
        for (NSRelationshipDescription *relDesc in checkingRelationships) {
            
            if (!relDesc.isToMany) continue;
            if (![[relObject valueForKey:relDesc.name] containsObject:object]) continue;
            
            [self checkObject:relObject forSendingWithSyncArray:syncArray];
            safelyToSend = NO;
            break;
            
        }
        
    }
    
    if (safelyToSend) {
        
        [syncArray removeObject:object];
        [self sendObject:object];
        
    }
    
}

+ (void)sendObject:(STMDatum *)object {
    
    NSDictionary *stcEntities = [STMEntityController stcEntities];
    STMEntity *entity = stcEntities[object.entity.name];
    NSString *resource = [entity resource];
    NSDictionary *objectDic = [STMCoreObjectsController dictionaryForJSWithObject:object];
    
    [self sendObjectDic:objectDic resource:resource];
    
}

+ (void)sendObjectDic:(NSDictionary *)objectDic resource:(NSString *)resource {
    
    if (!objectDic) objectDic = @{};
    if (!resource) resource = @"";
    
    NSDictionary *value = @{@"method"   : kSocketUpdateMethod,
                            @"resource" : resource,
                            @"attrs"    : objectDic};
    
    [self sendEvent:STMSocketEventJSData withValue:value];
    
}

#pragma mark - socket events sending

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

+ (void)socket:(SocketIOClient *)socket sendEvent:(STMSocketEvent)event withValue:(id)value {
    
    // Log
    // ----------
    
#ifdef DEBUG
    
    if (event == STMSocketEventData && [value isKindOfClass:[NSArray class]]) {
        
        NSArray *valueArray = [(NSArray *)value valueForKeyPath:@"name"];
        
        NSLog(@"socket:%@ sendEvent:%@ withObjects:%@", socket, [self stringValueForEvent:event], valueArray);
        
    } else {
        
        NSLog(@"socket:%@ sendEvent:%@ withValue:%@", socket, [self stringValueForEvent:event], value);
        
    }
#endif
    
    // ----------
    // End of log
    
    if (socket.status == SocketIOClientStatusConnected) {
        
        if (event == STMSocketEventJSData && [value isKindOfClass:[NSDictionary class]]) {
            
            [self sharedInstance].isSendingData = YES;
            [self sharedInstance].sendingDate = [NSDate date];

            NSString *eventStringValue = [STMSocketController stringValueForEvent:event];
            
            NSDictionary *dataDic = (NSDictionary *)value;
            
            [socket emitWithAck:eventStringValue withItems:@[dataDic]](0, ^(NSArray *data) {
                [self receiveJSDataEventAckWithData:data];
            });
            
        } else {
            
            NSString *primaryKey = [self primaryKeyForEvent:event];
            
            if (value && primaryKey) {
                
                NSDictionary *dataDic = @{primaryKey : value};
                
                dataDic = [STMFunctions validJSONDictionaryFromDictionary:dataDic];
                
                NSString *eventStringValue = [STMSocketController stringValueForEvent:event];
                
                if (dataDic) {
                    
                    if (socket.status != SocketIOClientStatusConnected) {
                        
                    } else {
                        
                        //                NSLog(@"%@ ___ emit: %@, data: %@", socket, eventStringValue, dataDic);
                        
                        if (event == STMSocketEventData) {
                            
//                            [self sharedInstance].isSendingData = YES;
//                            [self sharedInstance].sendingDate = [NSDate date];
//                            
//                            [socket emitWithAck:eventStringValue withItems:@[dataDic]](0, ^(NSArray *data) {
//                                [self receiveEventDataAckWithData:data];
//                            });
                            
                        } else {
                            [socket emit:eventStringValue withItems:@[dataDic]];
                        }
                        
                    }
                    
                } else {
                    NSLog(@"%@ ___ no dataDic to send via socket for event: %@", socket, eventStringValue);
                }
                
            }
            
        }
        
    } else {
        
        NSLog(@"socket not connected");
        
        if ([self syncer].syncerState == STMSyncerSendData || [self syncer].syncerState == STMSyncerSendDataOnce) {
            [self sendFinishedWithError:@"socket not connected"];
        }
        
    }
    
}

+ (void)socket:(SocketIOClient *)socket sendEvent:(STMSocketEvent)event withStringValue:(NSString *)stringValue {
    [self socket:socket sendEvent:event withValue:stringValue];
}

+ (void)socket:(SocketIOClient *)socket receiveAckWithData:(NSArray *)data forEvent:(NSString *)event {
    
    NSLog(@"%@ ___ receive Ack, event: %@, data: %@", socket, event, data);
    
    STMSocketEvent socketEvent = [self eventForString:event];
    
    if (socketEvent == STMSocketEventAuthorization) {
        [self socket:socket receiveAuthorizationAckWithData:data];
    }
    
}

+ (void)socket:(SocketIOClient *)socket receiveAuthorizationAckWithData:(NSArray *)data {
    
    if (socket.status != SocketIOClientStatusConnected) {
        return;
    }
    
    if ([data.firstObject isKindOfClass:[NSDictionary class]]) {
        
        NSDictionary *dataDic = data.firstObject;
        BOOL isAuthorized = [dataDic[@"isAuthorized"] boolValue];
        
        if (isAuthorized) {
            
            NSLog(@"socket authorized");
            
            [self sharedInstance].isAuthorized = YES;
            [self sharedInstance].isSendingData = NO;
            [[self syncer] socketReceiveAuthorization];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:@"socketAuthorizationSuccess" object:self];
            
            [self socket:socket sendEvent:STMSocketEventStatusChange withStringValue:[STMFunctions appStateString]];
            
            if ([[STMFunctions appStateString] isEqualToString:@"UIApplicationStateActive"]) {
                
                if ([[STMCoreRootTBC sharedRootVC].selectedViewController class]) {
                    
                    Class _Nonnull rootVCClass = (Class _Nonnull)[[STMCoreRootTBC sharedRootVC].selectedViewController class];
                    
                    NSString *stringValue = [@"selectedViewController: " stringByAppendingString:NSStringFromClass(rootVCClass)];
                    [self socket:socket sendEvent:STMSocketEventStatusChange withStringValue:stringValue];
                    
                }
                
            }
            
        } else {
            
            NSLog(@"socket not authorized");
            [self sharedInstance].isAuthorized = NO;
            [[STMCoreAuthController authController] logout];
            
        }
        
    } else {
        
        NSLog(@"socket not authorized");
        [self sharedInstance].isAuthorized = NO;
        [[STMCoreAuthController authController] logout];
        
    }
    
}

+ (void)receiveJSDataEventAckWithData:(NSArray *)data {
    
    //    NSLog(@"receiveJSDataEventAckWithData %@", data);
    
    [[self syncer] socketReceiveJSDataAck:data];
    
}

//+ (void)receiveEventDataAckWithData:(NSArray *)data {
//    
//    NSDictionary *response = data.firstObject;
//    
//    NSString *errorString = nil;
//    
//    if ([response isKindOfClass:[NSDictionary class]]) {
//        
//        errorString = response[@"error"];
//        
//    } else {
//        
//        errorString = @"response not a dictionary";
//        NSLog(@"error: %@", data);
//        
//    }
//    
//    if (errorString) {
//        
//        NSLog(@"error: %@", errorString);
//        
//        [self sendEvent:STMSocketEventInfo withStringValue:errorString];
//        
//        if ([[errorString.lowercaseString stringByReplacingOccurrencesOfString:@" " withString:@""] isEqualToString:@"notauthorized"]) {
//            [[STMCoreAuthController authController] logout];
//        }
//        
//    } else {
//        
//        NSArray *dataArray = response[@"data"];
//        
//        for (NSDictionary *datum in dataArray) {
//            
//            [[self document].managedObjectContext performBlockAndWait:^{
////                [STMCoreObjectsController syncObject:datum];
//            }];
//            
//        }
//        
//    }
//    
//    [[[STMCoreSessionManager sharedManager].currentSession document] saveDocument:^(BOOL success) {
//        [self performSelector:@selector(sendFinishedWithError:) withObject:errorString afterDelay:0];
//    }];
//    
//}

+ (void)sendFinishedWithError:(NSString *)errorString {
    
    if (errorString) {
        
        [self sendingCleanupWithError:errorString];
        
    } else {
        
        if ([self haveToSyncObjects]) {
            
            [[self syncer] bunchOfObjectsSended];
            
        } else {
            
            [self sendingCleanupWithError:nil];
            
        }
        
    }
    
}

+ (void)sendingCleanupWithError:(NSString *)errorString {
    
    STMSocketController *sc = [self sharedInstance];
    
    sc.isSendingData = NO;
    [[self syncer] sendFinishedWithError:errorString];
    sc.syncDataDictionary = nil;
    sc.sendingDate = nil;
    
}


#pragma mark - receive

+ (void)startReceiveDataFromResource:(NSString *)resourceString withETag:(NSString *)eTag fetchLimit:(NSInteger)fetchLimit andTimeout:(NSTimeInterval)timeout {
	
    [self startReceiveDataFromResource:resourceString
                              withETag:eTag
                            fetchLimit:fetchLimit
                            andTimeout:timeout
                                params:nil];
    
}

+ (void)startReceiveDataFromResource:(NSString *)resourceString withETag:(NSString *)eTag fetchLimit:(NSInteger)fetchLimit andTimeout:(NSTimeInterval)timeout params:(NSDictionary *)params {
    
    NSMutableDictionary *value = @{@"method"   : kSocketFindAllMethod,
                                   @"resource" : resourceString
                                   }.mutableCopy;
    
    NSMutableDictionary *options = @{@"pageSize" : @(fetchLimit)}.mutableCopy;
    if (eTag) options[@"offset"] = eTag;
    
    value[@"options"] = options;

    if (params) value[@"params"] = params;
    
    [self sendEvent:STMSocketEventJSData withValue:value];

}

+ (void)checkNewsWithFetchLimit:(NSInteger)fetchLimit andTimeout:(NSTimeInterval)timeout {
	
    NSDictionary *params = @{@"deviceUUID"  : [STMFunctions UUIDStringFromUUIDData:[STMClientDataController deviceUUID]]/*,
                             @"agentBuild"  : BUILD_VERSION*/};
    
    [self startReceiveDataFromResource:[self newsResourceString]
                              withETag:nil
                            fetchLimit:fetchLimit
                            andTimeout:timeout
                                params:params];

}

+ (NSString *)newsResourceString {
	
    NSString *accountOrg = [STMCoreAuthController authController].accountOrg;
    NSString *resourceString = [accountOrg stringByAppendingString:@"/news"];

    return resourceString;
    
}



#pragma mark - socket events receiveing

- (void)addEventObserversToSocket:(SocketIOClient *)socket {
    
    NSLog(@"addEventObserversToSocket %@", socket);
    
    [STMSocketController addOnAnyEventToSocket:socket];

    [STMSocketController addEvent:STMSocketEventConnect toSocket:socket];
    [STMSocketController addEvent:STMSocketEventDisconnect toSocket:socket];
    [STMSocketController addEvent:STMSocketEventReconnect toSocket:socket];
    [STMSocketController addEvent:STMSocketEventRemoteCommands toSocket:socket];
    [STMSocketController addEvent:STMSocketEventData toSocket:socket];
    [STMSocketController addEvent:STMSocketEventJSData toSocket:socket];
    
}

+ (void)addOnAnyEventToSocket:(SocketIOClient *)socket {
    
    [socket onAny:^(SocketAnyEvent *event) {
        
        NSLog(@"%@ ___ event %@", socket, event.event);
        NSLog(@"%@ ___ items (", socket);

        for (id item in event.items) NSLog(@"    %@", item);

        NSLog(@"%@           )", socket);

    }];

}

+ (void)addEvent:(STMSocketEvent)event toSocket:(SocketIOClient *)socket {
    
    NSString *eventString = [STMSocketController stringValueForEvent:event];
    
    [socket on:eventString callback:^(NSArray *data, SocketAckEmitter *ack) {
        
        switch (event) {
            case STMSocketEventConnect: {
                [self connectCallbackWithData:data ack:ack socket:socket];
                break;
            }
            case STMSocketEventDisconnect: {
                [self disconnectCallbackWithData:data ack:ack socket:socket];
                break;
            }
            case STMSocketEventReconnect: {
                [self reconnectCallbackWithData:data ack:ack socket:socket];
                break;
            }
            case STMSocketEventStatusChange: {
                
                break;
            }
            case STMSocketEventInfo: {
                
                break;
            }
            case STMSocketEventAuthorization: {
                
                break;
            }
            case STMSocketEventRemoteCommands: {
                [self remoteCommandsCallbackWithData:data ack:ack socket:socket];
                break;
            }
            case STMSocketEventData: {
                [self dataCallbackWithData:data ack:ack socket:socket];
            }
            case STMSocketEventJSData: {
                [self jsDataCallbackWithData:data ack:ack socket:socket];
            }
            default: {
                break;
            }
        }

    }];
    
}

+ (void)connectCallbackWithData:(NSArray *)data ack:(SocketAckEmitter *)ack socket:(SocketIOClient *)socket {
    
    //            [self checkQueuedEvent];
    
//    NSLog(@"connectCallback data %@", data);
//    NSLog(@"connectCallback ack %@", ack);
    NSLog(@"connectCallback socket %@", socket);
    
    [self sharedInstance].isAuthorized = NO;

    [[self sharedInstance] performSelector:@selector(checkAuthorizationForSocket:) withObject:socket afterDelay:CHECK_AUTHORIZATION_DELAY];

    STMClientData *clientData = [STMClientDataController clientData];
    NSMutableDictionary *dataDic = [[STMCoreObjectsController dictionaryForObject:clientData][@"properties"] mutableCopy];
    
    NSDictionary *authDic = @{@"userId"         : [STMCoreAuthController authController].userID,
                              @"accessToken"    : [STMCoreAuthController authController].accessToken};
    
    [dataDic addEntriesFromDictionary:authDic];
    
    NSLog(@"send authorization data %@ with socket %@", dataDic, socket);
    
    NSString *event = [STMSocketController stringValueForEvent:STMSocketEventAuthorization];
    
    [socket emitWithAck:event withItems:@[dataDic]](0, ^(NSArray *data) {
        [self socket:socket receiveAckWithData:data forEvent:event];
    });
    
}

+ (void)disconnectCallbackWithData:(NSArray *)data ack:(SocketAckEmitter *)ack socket:(SocketIOClient *)socket {
    
    NSLog(@"disconnectCallback socket %@", socket);
    
    [[self syncer] socketLostConnection];
    
    if ([self sharedInstance].isReconnecting) {
        
        [self sharedInstance].isReconnecting = NO;
        [self startSocket];
        
    }

}

+ (void)reconnectCallbackWithData:(NSArray *)data ack:(SocketAckEmitter *)ack socket:(SocketIOClient *)socket {
    
    NSLog(@"reconnectCallback socket %@", socket);
    
    [[self syncer] socketLostConnection];

}

+ (void)remoteCommandsCallbackWithData:(NSArray *)data ack:(SocketAckEmitter *)ack socket:(SocketIOClient *)socket {
    
    NSLog(@"remoteCommandsCallback socket %@", socket);

    if ([data.firstObject isKindOfClass:[NSDictionary class]]) {
        [STMRemoteController receiveRemoteCommands:data.firstObject];
    }

}

+ (void)dataCallbackWithData:(NSArray *)data ack:(SocketAckEmitter *)ack socket:(SocketIOClient *)socket {
    NSLog(@"dataCallback socket %@ data %@", socket, data);
}

+ (void)jsDataCallbackWithData:(NSArray *)data ack:(SocketAckEmitter *)ack socket:(SocketIOClient *)socket {
    NSLog(@"jsDataCallback socket %@ data %@", socket, data);
}


#pragma mark - instance methods

- (instancetype)init {
    
    self = [super init];
    if (self) {
        [self addObservers];
    }
    return self;
    
}

- (void)addObservers {
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self
           selector:@selector(appSettingsChanged:)
               name:@"appSettingsSettingsChanged"
             object:nil];
    
    [nc addObserver:self
           selector:@selector(sessionStatusChanged:)
               name:NOTIFICATION_SESSION_STATUS_CHANGED
             object:nil];

    
    [nc addObserver:self
           selector:@selector(objectContextDidSave:)
               name:NSManagedObjectContextDidSaveNotification
             object:nil];

    [nc addObserver:self
           selector:@selector(documentSavedSuccessfully:)
               name:@"documentSavedSuccessfully"
             object:nil];

}

- (void)removeObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)appSettingsChanged:(NSNotification *)notification {
    
    STMCoreSession *currentSession = [STMCoreSessionManager sharedManager].currentSession;
    
    if (currentSession.status == STMSessionRunning) {

// recconnect socket if socketUrl setting did change
        
//        NSString *key = @"socketUrl";
//        
//        if ([notification.userInfo.allKeys containsObject:key]) {
//            
//            self.socketUrl = nil;
//            
//            if (self.isRunning) {
//                
//                if (![self.socket.socketURL isEqualToString:self.socketUrl]) {
//                    [self reconnectSocket];
//                }
//                
//            } else {
//                
//                [STMSocketController startSocket];
//                
//            }
//            
//        }

    }
    
}

- (void)sessionStatusChanged:(NSNotification *)notification {
    
    STMCoreSession *session = [STMCoreSessionManager sharedManager].currentSession;
    
    if (notification.object == session) {
        
        if (session.status == STMSessionRunning) {
            
            [self performFetches];
            
        } else {
            
            self.resultsControllers = nil;
            
        }
        
    }
    
}

- (void)objectContextDidSave:(NSNotification *)notification {
    
//    NSLogMethodName;
    
//    if (self.controllersDidChangeContent && [notification.object isKindOfClass:[NSManagedObjectContext class]]) {
//        
//        NSManagedObjectContext *context = (NSManagedObjectContext *)notification.object;
//        
//        if ([context isEqual:[STMSocketController document].managedObjectContext]) {
//
//            [[STMSocketController sharedInstance] performSelector:@selector(sendUnsyncedObjects) withObject:nil afterDelay:0];
//
//        }
//        
//    }
    
}

- (void)documentSavedSuccessfully:(NSNotification *)notification {
    
    NSLogMethodName;

    if (self.controllersDidChangeContent && [notification.object isKindOfClass:[STMDocument class]]) {
        
        NSManagedObjectContext *context = [(STMDocument *)notification.object managedObjectContext];

        if ([context isEqual:[STMSocketController document].managedObjectContext]) {
            
            [[STMSocketController sharedInstance] performSelector:@selector(sendUnsyncedObjects) withObject:nil afterDelay:0];
            
        }
        
    }

}

- (void)sendUnsyncedObjects {

    self.controllersDidChangeContent = NO;
    [STMSocketController sendUnsyncedObjects:self];
    
}

- (void)performFetches {

    NSArray *entityNamesForSending = [STMEntityController uploadableEntitiesNames];

    self.resultsControllers = @[].mutableCopy;
    
    for (NSString *entityName in entityNamesForSending) {
        
        NSFetchedResultsController *rc = [self resultsControllerForEntityName:entityName];
        
        if (rc) {
            
            [self.resultsControllers addObject:rc];
            [rc performFetch:nil];
            
        }

    }
    
}

- (void)reloadResultsControllers {
    
    self.resultsControllers = nil;
    [self performFetches];
    
}

- (NSMutableDictionary *)syncDataDictionary {
    
    if (!_syncDataDictionary) {
        _syncDataDictionary = @{}.mutableCopy;
    }
    return _syncDataDictionary;
    
}


#pragma mark - NSFetchedResultsController

- (nullable NSFetchedResultsController *)resultsControllerForEntityName:(NSString *)entityName {
    
    if ([[STMCoreObjectsController localDataModelEntityNames] containsObject:entityName]) {
        
        STMFetchRequest *request = [STMFetchRequest fetchRequestWithEntityName:entityName];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES selector:@selector(compare:)]];
        request.includesSubentities = YES;
        
        NSMutableArray *subpredicates = @[].mutableCopy;
        
        if ([entityName isEqualToString:NSStringFromClass([STMLogMessage class])]) {
            
            STMLogger *logger = [[STMCoreSessionManager sharedManager].currentSession logger];
            
            NSArray *logMessageSyncTypes = [logger syncingTypesForSettingType:[self uploadLogType]];
            
            [subpredicates addObject:[NSPredicate predicateWithFormat:@"type IN %@", logMessageSyncTypes]];
            
        }
        
        [subpredicates addObject:[NSPredicate predicateWithFormat:@"(lts == %@ || deviceTs > lts)", nil]];
        
        request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:subpredicates];
        
        NSFetchedResultsController *rc = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                                             managedObjectContext:[STMSocketController document].managedObjectContext
                                                                               sectionNameKeyPath:nil
                                                                                        cacheName:nil];
        rc.delegate = self;
        
        return rc;
        
    } else {
        
        return nil;
        
    }

}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"syncerDidChangeContent" object:self];
    
    self.controllersDidChangeContent = YES;
    
//    NSArray *fetchedObjects = [self.resultsControllers valueForKeyPath:@"@distinctUnionOfArrays.fetchedObjects"];
//
//    NSLog(@"fetchedObjects.count %@", @(fetchedObjects.count));
    
    [[STMSocketController document] saveDocument:^(BOOL success) {
        
    }];
    
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    
//    NSLog(@"didChangeObject %@", [anObject entity].name);
    
}

- (NSString *)uploadLogType {
        NSString *uploadLogType = [STMCoreSettingsController stringValueForSettings:@"uploadLog.type" forGroup:@"syncer"];
    return uploadLogType;
}

- (NSArray *)unsyncedObjectsArray {
    
    if (self.isAuthorized && [STMSocketController document].managedObjectContext) {
        
        NSArray *fetchedObjects = [self.resultsControllers valueForKeyPath:@"@distinctUnionOfArrays.fetchedObjects"];
        
        return fetchedObjects;
        
    } else {
        return nil;
    }
    
}


#pragma mark - socket

- (SocketIOClient *)socket {
    
    if (!_socket && self.socketUrl) {
        
        SocketIOClient *socket = [[SocketIOClient alloc] initWithSocketURL:self.socketUrl opts:nil];

        NSLog(@"init socket %@", socket);

        [self addEventObserversToSocket:socket];

        _socket = socket;
        
    }
    return _socket;
    
}

- (void)reconnectSocket {

    NSLogMethodName;
    
    if (self.isRunning) {
        
        self.isReconnecting = YES;
        [STMSocketController closeSocket];
        
    } else {
    
        [STMSocketController startSocket];

    }
    
}

- (NSString *)socketUrl {
    
    if (!_socketUrl) {
        _socketUrl = [STMCoreSettingsController stringValueForSettings:@"socketUrl" forGroup:@"syncer"];
    }
    return _socketUrl;
    
}

- (void)checkAuthorizationForSocket:(SocketIOClient *)socket {

    NSLog(@"checkAuthorizationForSocket: %@", socket);
    
    if ([socket isEqual:self.socket]) {
        
        if (self.isAuthorized) {
            
            NSLog(@"socket is authorized");
            
        } else {

            NSString *logMessage = @"socket is connected but don't receive authorization ack, trying to resolve this issue by reconnecting";
            [[STMLogger sharedLogger] saveLogMessageWithText:logMessage type:@"error"];

            [self reconnectSocket];
            
        }

    } else {
        
        NSLog(@"not a current socket");
        
    }
    
}



@end
