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


@interface STMSocketController() <NSFetchedResultsControllerDelegate>

@property (nonatomic, strong) SocketIOClient *socket;
@property (nonatomic, strong) NSString *socketUrl;
@property (nonatomic, strong) NSString *entityResource;

@property (nonatomic) BOOL isRunning;
@property (nonatomic) BOOL isAuthorized;
@property (nonatomic) BOOL isSendingData;
@property (nonatomic) BOOL isManualReconnecting;
@property (nonatomic) BOOL wasClosedInBackground;
@property (nonatomic) BOOL shouldSendData;
@property (nonatomic) BOOL waitDocumentSavingToSyncNextObject;
@property (nonatomic) BOOL waitDocumentSavingToSendingCleanup;
@property (nonatomic) BOOL controllersDidChangeContent;

@property (nonatomic, strong) NSArray <STMDatum *> *unsyncedObjectsArray;
@property (nonatomic, strong) NSMutableArray <STMDatum *> *currentSyncObjects;
@property (nonatomic, strong) NSMutableDictionary *syncDateDictionary;
@property (nonatomic, strong) NSMutableArray *doNotSyncObjectXids;
@property (nonatomic, strong) NSMutableArray *resultsControllers;

@property (nonatomic, strong) NSDate *sendingDate;
@property (nonatomic) NSTimeInterval sendTimeout;
@property (nonatomic) NSTimeInterval receiveTimeout;
@property (nonatomic, strong) NSDate *receivingStartDate;
@property (nonatomic, strong) NSString *sendingCleanupError;


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
    [[self sharedInstance] startSocketWithUrl:socketUrlString andEntityResource:entityResource];
}

+ (BOOL)isItCurrentSocket:(SocketIOClient *)socket failString:(NSString *)failString {
    return [[self sharedInstance] isItCurrentSocket:socket failString:failString];
}

+ (void)checkSocket {
    [[self sharedInstance] checkSocket];
}

+ (void)startSocket {
    [[self sharedInstance] startSocket];
}

+ (void)closeSocket {
    [[self sharedInstance] closeSocket];
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

+ (NSArray <STMDatum *> *)unsyncedObjects {
    return [[self sharedInstance] unsyncedObjectsArray];
}

+ (NSUInteger)numbersOfAllUnsyncedObjects {
    return [self unsyncedObjects].count;
}

+ (NSUInteger)numberOfCurrentlyUnsyncedObjects {
    return [self sharedInstance].currentSyncObjects.count;
}

+ (void)sendUnsyncedObjects:(id)sender withTimeout:(NSTimeInterval)timeout {
    
    [self sharedInstance].sendTimeout = timeout;
    
    if (![self socketIsAvailable]) {

        if ([self syncer].syncerState == STMSyncerSendData || [self syncer].syncerState == STMSyncerSendDataOnce) {

            [self sendFinishedWithError:@"socket not connected"
                              abortSync:@(YES)];
            
        }
        return;
        
    }
    
    if ([STMSocketController syncer].syncerState == STMSyncerReceiveData) {
        
        NSLog(@"socket is receiving data, wait finish of it to send");
        return;
        
    }
    
    if ([self sharedInstance].isSendingData) {
        
        NSLog(@"socket already in sending data process");
        return;

    }

    if (![self haveToSyncObjects]) {
        
        if ([sender isEqual:[self syncer]]) {
            [[self syncer] nothingToSend];
        }
        
    }

}

+ (BOOL)haveToSyncObjects {

    NSArray <STMDatum *> *syncDataArray = [self unsyncedObjects];

    STMSocketController *sc = [self sharedInstance];

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"NOT (xid IN %@) AND NOT (xid IN %@)", sc.doNotSyncObjectXids, sc.syncDateDictionary.allKeys];
    
    syncDataArray = [syncDataArray filteredArrayUsingPredicate:predicate];
    
    if (syncDataArray.count > 0) {
        
        NSLog(@"have %d objects to send via Socket", syncDataArray.count);

        sc.currentSyncObjects = syncDataArray.mutableCopy;

        [self sendObjectFromSyncArray];
        
        return YES;
        
    } else {
        
        return NO;
        
    }
    
}

+ (void)sendObjectFromSyncArray {
    
    STMSocketController *sc = [self sharedInstance];
    
    if (sc.currentSyncObjects.count > 0) {
        
        STMDatum *syncObject = [self findObjectToSendFirstFromSyncArray:sc.currentSyncObjects.mutableCopy];
        
        if (syncObject) {

            [sc.currentSyncObjects removeObject:syncObject];

            if (syncObject.xid) {

                NSData *xid = syncObject.xid;

                if (![sc.syncDateDictionary.allKeys containsObject:xid]) {

                    sc.syncDateDictionary[xid] = (syncObject.deviceTs) ? syncObject.deviceTs : [NSDate date];
                    [self sendObject:syncObject];

                } else {
                    
                    NSString *message = [NSString stringWithFormat:@"skip %@ %@, already trying to sync", syncObject.entity.name, syncObject.xid];
                    NSLog(message);

                    [self sendObjectFromSyncArray];
                    
                }

            } else {
                
                NSLog(@"    ERROR: sync object have no xid: %@", syncObject);
                [self sendObjectFromSyncArray];

            }
            
        } else {
            [self sendFinishedWithError:nil abortSync:@(NO)];
        }
        
    } else {
        [self sendFinishedWithError:nil abortSync:@(NO)];
    }

}

+ (STMDatum *)findObjectToSendFirstFromSyncArray:(NSMutableArray <STMDatum *> *)syncArray {
    
    if (syncArray.firstObject) {
        return [self checkRelationshipsObjectsForObject:syncArray.firstObject fromSyncArray:syncArray];
    } else {
        return nil;
    }
    
}

+ (STMDatum *)checkRelationshipsObjectsForObject:(STMDatum *)syncObject fromSyncArray:(NSMutableArray <STMDatum *> *)syncArray {
    
    [syncArray removeObject:syncObject];
    
    STMSocketController *sc = [STMSocketController sharedInstance];
    
    if ([sc.doNotSyncObjectXids containsObject:(NSData *)syncObject.xid]) {
        
        return [self findObjectToSendFirstFromSyncArray:syncArray];
        
    } else {
     
        NSEntityDescription *objectEntity = syncObject.entity;
        NSString *entityName = objectEntity.name;
        NSDictionary *relationships = [STMCoreObjectsController toOneRelationshipsForEntityName:entityName];
        
        BOOL shouldFindNext = NO;
        
        for (NSString *relName in relationships.allKeys) {
            
            STMDatum *relObject = [syncObject valueForKey:relName];
            
            if ([sc.doNotSyncObjectXids containsObject:(NSData *)relObject.xid]) {
                
                if (![sc.doNotSyncObjectXids containsObject:syncObject.xid]) {
                    [sc.doNotSyncObjectXids addObject:(NSData *)syncObject.xid];
                }
                
                NSString *log = [NSString stringWithFormat:@"%@ %@ have unsynced relation to %@", syncObject.entity.name, syncObject.xid, relObject.entity.name];
                NSLog(log);
                
                shouldFindNext = YES;
                break;
                
            }
            
            if (![syncArray containsObject:relObject]) continue;
            
            NSEntityDescription *relObjectEntity = relObject.entity;
            NSArray *checkingRelationships = [relObjectEntity relationshipsWithDestinationEntity:objectEntity];
            
            BOOL doBreak = NO;
            
            for (NSRelationshipDescription *relDesc in checkingRelationships) {
                
                if (!relDesc.isToMany) continue;
                if (![[relObject valueForKey:relDesc.name] containsObject:syncObject]) continue;
                
                syncObject = [self checkRelationshipsObjectsForObject:relObject fromSyncArray:syncArray];
                doBreak = YES;
                break;
                
            }
            
            if (doBreak) break;
            
        }
        return (shouldFindNext) ? [self findObjectToSendFirstFromSyncArray:syncArray] : syncObject;
        
    }
    
}

+ (void)sendObject:(STMDatum *)object {
    
    NSDictionary *stcEntities = [STMEntityController stcEntities];
    STMEntity *entity = stcEntities[(NSString *)object.entity.name];
    NSString *resource = [entity resource];
    NSDictionary *objectDic = [STMCoreObjectsController dictionaryForJSWithObject:object];
    
    NSLog(@"sync %@ %@", object.entity.name, object.xid);
    
    [self sendObjectDic:objectDic resource:resource];
    
    STMSocketController *sc = [self sharedInstance];
    
    [sc performSelector:@selector(checkSendTimeoutForObjectXid:)
             withObject:object.xid
             afterDelay:sc.sendTimeout];

}

+ (void)sendObjectDic:(NSDictionary *)objectDic resource:(NSString *)resource {
    
    if (!objectDic) objectDic = @{};
    if (!resource) resource = @"";
    
    NSDictionary *value = @{@"method"   : kSocketUpdateMethod,
                            @"resource" : resource,
                            @"id"       : objectDic[@"id"],
                            @"attrs"    : objectDic};
    
    [self sendEvent:STMSocketEventJSData withValue:value];
    
}

- (void)checkSendTimeoutForObjectXid:(NSData *)xid {
    
    if ([self.syncDateDictionary.allKeys containsObject:xid]) {
        
        NSString *errorString = [NSString stringWithFormat:@"timeout for sending object with xid %@", xid];
        
        [STMSocketController sendEvent:STMSocketEventInfo withStringValue:errorString];
        
        [STMSocketController unsuccessfullySyncObjectWithXid:xid
                                                 errorString:errorString
                                                   abortSync:NO];

    }
    
}

+ (NSDate *)syncDateForSyncedObjectXid:(NSData *)xid {
    
    NSDate *syncDate = [self sharedInstance].syncDateDictionary[xid];
    return syncDate;
    
}

+ (void)successfullySyncObjectWithXid:(NSData *)xid {
    
    STMSocketController *sc = [self sharedInstance];
    
    [STMSocketController cancelPreviousPerformRequestsWithTarget:sc
                                                        selector:@selector(checkSendTimeoutForObjectXid:)
                                                          object:xid];
    
    [sc releaseDoNotSyncObjectsWithObjectXid:xid];
    
    if (sc.currentSyncObjects.count == 0) {

        sc.waitDocumentSavingToSyncNextObject = YES;

        [[self document] saveDocument:^(BOOL success) {
        }];

    } else {
    
        [sc performSelector:@selector(sendFinishedWithError:abortSync:)
                 withObject:nil
                 withObject:nil];

    }
    
}

+ (void)unsuccessfullySyncObjectWithXid:(NSData *)xid errorString:(NSString *)errorString abortSync:(BOOL)abortSync {
    
    STMSocketController *sc = [self sharedInstance];
    
    if (xid) {
    
        [STMSocketController cancelPreviousPerformRequestsWithTarget:sc
                                                            selector:@selector(checkSendTimeoutForObjectXid:)
                                                              object:xid];

        [sc.syncDateDictionary removeObjectForKey:xid];
        [sc.doNotSyncObjectXids addObject:xid];

    }
    
    [sc performSelector:@selector(sendFinishedWithError:abortSync:)
             withObject:errorString
             withObject:@(abortSync)];
    
}

- (void)sendFinishedWithError:(NSString *)errorString abortSync:(NSNumber *)abortSync {
    [STMSocketController sendFinishedWithError:errorString abortSync:abortSync];
}

+ (void)sendFinishedWithError:(NSString *)errorString abortSync:(NSNumber *)abortSync {
    
    [[self syncer] postObjectsSendedNotification];
    
    if (errorString && abortSync.boolValue) {
        
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
    
    sc.sendingCleanupError = errorString;
    sc.waitDocumentSavingToSendingCleanup = YES;
    
    [[self document] saveDocument:^(BOOL success) {
    }];

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
        
//        NSArray *valueArray = [(NSArray *)value valueForKeyPath:@"name"];
        
//        NSLog(@"socket:%@ sendEvent:%@ withObjects:%@", socket, [self stringValueForEvent:event], valueArray);
        
    } else if (event == STMSocketEventInfo || event == STMSocketEventStatusChange) {
        
        NSLog(@"socket:%@ %@ sendEvent:%@ withValue:%@", socket, socket.sid, [self stringValueForEvent:event], value);
        
    }
#endif
    
    // ----------
    // End of log
    
    if (socket.status == SocketIOClientStatusConnected) {
        
        if (event == STMSocketEventJSData && [value isKindOfClass:[NSDictionary class]]) {
            
            NSString *method = value[@"method"];
            
            if ([method isEqualToString:@"update"]) {
                
                [self sharedInstance].isSendingData = YES;
                [self sharedInstance].sendingDate = [NSDate date];

            }
            
            NSString *eventStringValue = [STMSocketController stringValueForEvent:event];
            
            NSDictionary *dataDic = (NSDictionary *)value;
            
            [socket emitWithAck:eventStringValue with:@[dataDic]](0, ^(NSArray *data) {
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
                            [socket emit:eventStringValue with:@[dataDic]];
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
            
            [self sendFinishedWithError:@"socket not connected"
                              abortSync:@(YES)];
            
        }
        
    }
    
}

+ (void)socket:(SocketIOClient *)socket sendEvent:(STMSocketEvent)event withStringValue:(NSString *)stringValue {
    [self socket:socket sendEvent:event withValue:stringValue];
}

+ (void)socket:(SocketIOClient *)socket receiveAckWithData:(NSArray *)data forEvent:(NSString *)event {
    
    STMSocketEvent socketEvent = [self eventForString:event];
    
    if (socketEvent == STMSocketEventAuthorization) {
        [self socket:socket receiveAuthorizationAckWithData:data];
    } else {
        NSLog(@"%@ %@ ___ receive Ack, event: %@, data: %@", socket, socket.sid, event, data);
    }
    
}

+ (void)socket:(SocketIOClient *)socket receiveAuthorizationAckWithData:(NSArray *)data {
    
    if ([self isItCurrentSocket:socket failString:@"receiveAuthorizationAck"]) {

        STMLogger *logger = [STMLogger sharedLogger];
        
        NSString *logMessage = [NSString stringWithFormat:@"socket %@ %@ receiveAuthorizationAckWithData %@", socket, socket.sid, data];
        [logger saveLogMessageWithText:logMessage
                               numType:STMLogMessageTypeInfo];
        
        if (socket.status != SocketIOClientStatusConnected) {
            return;
        }
        
        if ([data.firstObject isKindOfClass:[NSDictionary class]]) {
            
            NSDictionary *dataDic = data.firstObject;
            BOOL isAuthorized = [dataDic[@"isAuthorized"] boolValue];
            
            if (isAuthorized) {
                
                logMessage = [NSString stringWithFormat:@"socket %@ %@ authorized", socket, socket.sid];
                [logger saveLogMessageWithText:logMessage
                                       numType:STMLogMessageTypeInfo];
                
                [self sharedInstance].isAuthorized = YES;
                [self sharedInstance].isSendingData = NO;
                [[self syncer] socketReceiveAuthorization];
                
                [[NSNotificationCenter defaultCenter] postNotificationName:@"socketAuthorizationSuccess" object:self];
                
                [self socket:socket sendEvent:STMSocketEventStatusChange withStringValue:[STMFunctions appStateString]];
                
                if ([[STMFunctions appStateString] isEqualToString:@"UIApplicationStateActive"]) {
                    
                    UIViewController *selectedVC = [STMCoreRootTBC sharedRootVC].selectedViewController;
                    
                    if ([selectedVC class]) {
                        
                        Class _Nonnull rootVCClass = (Class _Nonnull)[selectedVC class];
                        
                        NSString *stringValue = [NSString stringWithFormat:@"selectedViewController: %@ %@ %@", selectedVC.title, selectedVC, NSStringFromClass(rootVCClass)];

                        [self socket:socket sendEvent:STMSocketEventStatusChange withStringValue:stringValue];
                        
                    }
                    
                }
                
            } else {
                [self notAuthorizedSocket:socket
                                withError:@"socket receiveAuthorizationAck with dataDic.isAuthorized.boolValue == NO"];
            }
            
        } else {
            [self notAuthorizedSocket:socket
                            withError:@"socket receiveAuthorizationAck with data.firstObject is not a NSDictionary"];
        }

    }
    
}

+ (void)notAuthorizedSocket:(SocketIOClient *)socket withError:(NSString *)errorString {
    
    NSString *logMessage = [NSString stringWithFormat:@"socket %@ %@ not authorized\n%@", socket, socket.sid, errorString];
    [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                             numType:STMLogMessageTypeWarning];
    
    [self sharedInstance].isAuthorized = NO;
    [[STMCoreAuthController authController] logout];

}

+ (void)receiveJSDataEventAckWithData:(NSArray *)data {
    
//    NSLog(@"receiveJSDataEventAckWithData %@", data);

    [self cancelCheckReceiveTimeout];

    [[self syncer] socketReceiveJSDataAck:data];
    
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
    
    [self sendFindWithValue:value andTimeout:timeout];

}

+ (void)checkNewsWithFetchLimit:(NSInteger)fetchLimit andTimeout:(NSTimeInterval)timeout {
	
    NSDictionary *params = @{@"deviceUUID"  : [STMClientDataController deviceUUIDString]/*,
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

+ (void)sendFantomFindEventToResource:(NSString *)resource withXid:(NSString *)xidString andTimeout:(NSTimeInterval)timeout {
	
    NSDictionary *value = @{@"method"   : kSocketFindMethod,
                            @"resource" : resource,
                            @"id"       : xidString};

    [self sendFindWithValue:value andTimeout:timeout];
    
}

+ (void)sendFindWithValue:(id)value andTimeout:(NSTimeInterval)timeout {
    
    STMSocketController *sc = [self sharedInstance];
    sc.receivingStartDate = [NSDate date];
    
    [self cancelCheckReceiveTimeout];
    
    sc.receiveTimeout = timeout;
    
    [sc performSelector:@selector(checkReceiveTimeout:)
             withObject:@(sc.receiveTimeout)
             afterDelay:timeout];
    
    [self sendEvent:STMSocketEventJSData withValue:value];

}

- (void)checkReceiveTimeout:(NSNumber *)timeoutNumber {
    
    NSTimeInterval timeout = timeoutNumber.doubleValue;
    NSTimeInterval elapsedTime = -[self.receivingStartDate timeIntervalSinceNow];
    
    if (elapsedTime >= timeout) {
        [[STMSocketController syncer] socketReceiveTimeout];
    }
    
}

+ (void)cancelCheckReceiveTimeout {
    
    STMSocketController *sc = [self sharedInstance];

    [self cancelPreviousPerformRequestsWithTarget:sc
                                         selector:@selector(checkReceiveTimeout:)
                                           object:@(sc.receiveTimeout)];

}

+ (void)receiveFinishedWithError:(NSString *)errorString {

    STMSocketController *sc = [self sharedInstance];
    sc.unsyncedObjectsArray = nil;
    sc.doNotSyncObjectXids = nil;

}


#pragma mark - socket events receiveing

- (void)addEventObserversToSocket:(SocketIOClient *)socket {
    
    [socket removeAllHandlers];
    
    STMLogger *logger = [STMLogger sharedLogger];
    
    NSString *logMessage = [NSString stringWithFormat:@"addEventObserversToSocket %@", socket];
    [logger saveLogMessageWithText:logMessage
                           numType:STMLogMessageTypeInfo];

    
    [STMSocketController addOnAnyEventToSocket:socket];
    
    NSArray *events = @[@(STMSocketEventConnect),
                        @(STMSocketEventDisconnect),
                        @(STMSocketEventError),
                        @(STMSocketEventReconnect),
                        @(STMSocketEventReconnectAttempt),
                        @(STMSocketEventRemoteCommands),
                        @(STMSocketEventData),
                        @(STMSocketEventJSData)];

    for (NSNumber *eventNum in events) {
        [STMSocketController addEvent:eventNum.integerValue toSocket:socket];
    }

}

+ (void)addOnAnyEventToSocket:(SocketIOClient *)socket {
    
    [socket onAny:^(SocketAnyEvent *event) {
        
        NSLog(@"%@ %@ ___ event %@", socket, socket.sid, event.event);
        NSLog(@"%@ %@ ___ items (", socket, socket.sid);

        for (id item in event.items) NSLog(@"    %@", item);

        NSLog(@"%@ %@           )", socket, socket.sid);

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
            case STMSocketEventError: {
                [self errorCallbackWithData:data ack:ack socket:socket];
                break;
            }
            case STMSocketEventReconnect: {
                [self reconnectCallbackWithData:data ack:ack socket:socket];
                break;
            }
            case STMSocketEventReconnectAttempt: {
                [self reconnectAttemptCallbackWithData:data ack:ack socket:socket];
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
    
    if ([self isItCurrentSocket:socket failString:@"connectCallback"]) {

        STMLogger *logger = [STMLogger sharedLogger];
        
        NSString *logMessage = [NSString stringWithFormat:@"connectCallback socket %@ with sid: %@", socket, socket.sid];
        [logger saveLogMessageWithText:logMessage
                               numType:STMLogMessageTypeDebug];
        
        STMSocketController *sc = [self sharedInstance];
        sc.isAuthorized = NO;
        sc.syncDateDictionary = nil;
        sc.unsyncedObjectsArray = nil;
        sc.doNotSyncObjectXids = nil;
        sc.sendingDate = nil;
        
        [sc startDelayedAuthorizationCheckForSocket:socket];
        
        STMClientData *clientData = [STMClientDataController clientData];
        NSMutableDictionary *dataDic = [STMCoreObjectsController dictionaryForJSWithObject:clientData].mutableCopy;
        
        NSDictionary *authDic = @{@"userId"         : [STMCoreAuthController authController].userID,
                                  @"accessToken"    : [STMCoreAuthController authController].accessToken};
        
        [dataDic addEntriesFromDictionary:authDic];
        
        logMessage = [NSString stringWithFormat:@"send authorization data %@ with socket %@ %@", dataDic, socket, socket.sid];
        [logger saveLogMessageWithText:logMessage
                               numType:STMLogMessageTypeInfo];
        
        NSString *event = [STMSocketController stringValueForEvent:STMSocketEventAuthorization];
        
        [socket emitWithAck:event with:@[dataDic]](0, ^(NSArray *data) {
            [self socket:socket receiveAckWithData:data forEvent:event];
        });

    }
    
}

+ (void)disconnectCallbackWithData:(NSArray *)data ack:(SocketAckEmitter *)ack socket:(SocketIOClient *)socket {

    if ([self isItCurrentSocket:socket failString:@"disconnectCallback"]) {

        STMSocketController *sc = [STMSocketController sharedInstance];
        STMLogger *logger = [STMLogger sharedLogger];
        
        NSString *logMessage = [NSString stringWithFormat:@"disconnectCallback socket %@ %@", socket, socket.sid];
        [logger saveLogMessageWithText:logMessage
                               numType:STMLogMessageTypeInfo];
        
        [self socketLostConnection];
        
        if (sc.isManualReconnecting) {
            
            logMessage = [NSString stringWithFormat:@"socket %@ %@ isManualReconnecting, start socket now", socket, socket.sid];
            [logger saveLogMessageWithText:logMessage
                                   numType:STMLogMessageTypeInfo];
            
            sc.isManualReconnecting = NO;
            [self startSocket];
            
        } else {
            
            logMessage = [NSString stringWithFormat:@"socket %@ %@ is not reconnecting, do nothing", socket, socket.sid];
            [logger saveLogMessageWithText:logMessage
                                   numType:STMLogMessageTypeInfo];
            
        }

    }

}

+ (void)errorCallbackWithData:(NSArray *)data ack:(SocketAckEmitter *)ack socket:(SocketIOClient *)socket {
    
    STMLogger *logger = [STMLogger sharedLogger];
    
    NSString *logMessage = [NSString stringWithFormat:@"errorCallback socket %@ %@ with data: %@", socket, socket.sid, data.description];
    [logger saveLogMessageWithText:logMessage
                           numType:STMLogMessageTypeInfo];
    
}

+ (void)reconnectAttemptCallbackWithData:(NSArray *)data ack:(SocketAckEmitter *)ack socket:(SocketIOClient *)socket {
    
    STMLogger *logger = [STMLogger sharedLogger];
    
    NSString *logMessage = [NSString stringWithFormat:@"reconnectAttemptCallback socket %@ %@", socket, socket.sid];
    [logger saveLogMessageWithText:logMessage
                           numType:STMLogMessageTypeInfo];
    
}

+ (void)reconnectCallbackWithData:(NSArray *)data ack:(SocketAckEmitter *)ack socket:(SocketIOClient *)socket {
    
    STMLogger *logger = [STMLogger sharedLogger];
    
    NSString *logMessage = [NSString stringWithFormat:@"reconnectCallback socket %@ %@", socket, socket.sid];
    [logger saveLogMessageWithText:logMessage
                           numType:STMLogMessageTypeInfo];

    [self socketLostConnection];

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

+ (void)socketLostConnection {
    [[self syncer] socketLostConnection];
}

#pragma mark - instance methods

- (instancetype)init {
    
    self = [super init];
    
    if (self) {
        
        [self addObservers];
//        [self checkSocketStatus];
        
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

- (void)checkSocketStatus {

#ifdef DEBUG
    STMLogger *logger = [STMLogger sharedLogger];
    
    NSString *logMessage = [NSString stringWithFormat:@"socket %@ status %@", self.socket, @(self.socket.status)];
    [logger saveLogMessageWithText:logMessage
                           numType:STMLogMessageTypeDebug];
    
    [self performSelector:@selector(checkSocketStatus)
               withObject:nil
               afterDelay:10];
#endif

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
    
}

- (void)documentSavedSuccessfully:(NSNotification *)notification {
    
    if (self.waitDocumentSavingToSyncNextObject) {
        
        self.waitDocumentSavingToSyncNextObject = NO;
        
        self.unsyncedObjectsArray = nil;
        self.currentSyncObjects = nil;
        self.syncDateDictionary = nil;
        
        [self performSelector:@selector(sendFinishedWithError:abortSync:)
                   withObject:nil
                   withObject:nil];
        
    } else if (self.waitDocumentSavingToSendingCleanup) {
        
        self.waitDocumentSavingToSendingCleanup = NO;
        
        self.isSendingData = NO;
        [[STMSocketController syncer] sendFinishedWithError:self.sendingCleanupError];
        self.sendingCleanupError = nil;
        self.unsyncedObjectsArray = nil;
        self.syncDateDictionary = nil;
        self.sendingDate = nil;

    } else {
        
        if ([STMSocketController socketIsAvailable] &&
            self.controllersDidChangeContent &&
            [notification.object isKindOfClass:[STMDocument class]]) {
            
            NSManagedObjectContext *context = [(STMDocument *)notification.object managedObjectContext];
            
            if ([context isEqual:[STMSocketController document].managedObjectContext]) {

                self.controllersDidChangeContent = NO;
                [STMSocketController syncer].syncerState = STMSyncerSendDataOnce;
                
            }
            
        }

    }

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

- (NSMutableDictionary *)syncDateDictionary {
    
    if (!_syncDateDictionary) {
        _syncDateDictionary = @{}.mutableCopy;
    }
    return _syncDateDictionary;
    
}

- (NSMutableArray *)doNotSyncObjectXids {
    
    if (!_doNotSyncObjectXids) {
        _doNotSyncObjectXids = @[].mutableCopy;
    }
    return _doNotSyncObjectXids;
    
}

- (NSTimeInterval)sendTimeout {
    
    if (!_sendTimeout) {
        _sendTimeout = [[STMSocketController syncer] timeout];
    }
    return _sendTimeout;
    
}

//- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
//    
//    if ([object isKindOfClass:[STMDatum class]]) {
//        
//        if ([keyPath isEqualToString:@"isFantom"]) {
//            
//            id newValue = [change valueForKey:NSKeyValueChangeNewKey];
//            
//            if ([newValue isKindOfClass:[NSNumber class]]) {
//                
//                BOOL isFantom = [newValue boolValue];
//                
//                if (!isFantom) {
//                    
//                    [object removeObserver:self forKeyPath:keyPath];
//                    [self releaseDoNotSyncObjectsWithObject:object];
//
//                }
//
//            }
//            
//        }
//        
//    }
//    
//}

- (void)releaseDoNotSyncObjectsWithObjectXid:(NSData *)objectXid {
    
    if (objectXid) {
        
        STMDatum *object = [STMCoreObjectsController objectForXid:objectXid];
        
        if (object) [self releaseDoNotSyncObjectsWithObject:object];

    }
    
}

- (void)releaseDoNotSyncObjectsWithObject:(STMDatum *)object {
    
    if (self.doNotSyncObjectXids.count == 0) return;
    
    NSDictionary *toManyRelationships = [STMCoreObjectsController toManyRelationshipsForEntityName:object.entity.name];
    
    for (NSString *relName in toManyRelationships.allKeys) {
        
        NSSet *relObjects = [object valueForKey:relName];
        NSArray *relObjectsXids = [relObjects valueForKeyPath:@"@distinctUnionOfObjects.xid"];
        
        for (NSData *xid in relObjectsXids) [self.doNotSyncObjectXids removeObject:xid];
        
    }
    
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
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SYNCER_DID_CHANGE_CONTENT
                                                        object:self];
    
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
    
    NSString *uploadLogType = [STMCoreSettingsController stringValueForSettings:@"uploadLog.type"
                                                                       forGroup:@"syncer"];
    return uploadLogType;
    
}

- (NSArray <STMDatum *> *)unsyncedObjectsArray {
    
    if (!_unsyncedObjectsArray) {
        
        if (self.isAuthorized && [STMSocketController document].managedObjectContext) {
            
            NSArray <STMDatum *> *fetchedObjects = [self.resultsControllers valueForKeyPath:@"@distinctUnionOfArrays.fetchedObjects"];
            _unsyncedObjectsArray = (fetchedObjects.count > 0) ? fetchedObjects : nil;
            
        }

    }
    return _unsyncedObjectsArray;
    
}


#pragma mark - socket

- (SocketIOClient *)socket {
    
    if (!_socket && self.socketUrl && self.isRunning) {
        
        NSURL *socketUrl = [NSURL URLWithString:self.socketUrl];
        NSString *path = [socketUrl.path stringByAppendingString:@"/"];

        SocketIOClient *socket = [[SocketIOClient alloc] initWithSocketURL:socketUrl
                                                                    config:@{@"voipEnabled"         : @YES,
                                                                              @"log"                : @NO,
                                                                              @"forceWebsockets"    : @NO,
                                                                              @"path"               : path}];

        STMLogger *logger = [STMLogger sharedLogger];
        
        NSString *logMessage = [NSString stringWithFormat:@"init socket %@", socket];
        [logger saveLogMessageWithText:logMessage
                               numType:STMLogMessageTypeInfo];

        [self addEventObserversToSocket:socket];

        _socket = socket;
        
    }
    return _socket;
    
}

- (void)startSocketWithUrl:(NSString *)socketUrlString andEntityResource:(NSString *)entityResource {

    self.socketUrl = socketUrlString;
    self.entityResource = entityResource;
    
    [self startSocket];

}

- (BOOL)isItCurrentSocket:(SocketIOClient *)socket failString:(NSString *)failString {
    
    if ([socket isEqual:self.socket]) {
        
        return YES;
        
    } else {
        
        STMLogger *logger = [STMLogger sharedLogger];
        
        NSString *logMessage = [NSString stringWithFormat:@"socket %@ %@ %@, is not the current socket", socket, socket.sid, failString];
        [logger saveLogMessageWithText:logMessage
                               numType:STMLogMessageTypeError];
        
        logMessage = [NSString stringWithFormat:@"current socket %@ %@", self.socket, self.socket.sid];
        [logger saveLogMessageWithText:logMessage
                               numType:STMLogMessageTypeInfo];
        
        if (socket.status != SocketIOClientStatusDisconnected || socket.status != SocketIOClientStatusNotConnected) {
            
            logMessage = [NSString stringWithFormat:@"not current socket disconnect"];
            [logger saveLogMessageWithText:logMessage
                                   numType:STMLogMessageTypeInfo];
            
            [socket disconnect];
            
        } else {
            
            socket = nil;
            
        }
        
        return NO;
        
    }

}

- (void)checkSocket {
    
    if (self.wasClosedInBackground) {
        
        self.wasClosedInBackground = NO;
        [self startSocket];
        
    }

}

- (void)startSocket {
    
    STMLogger *logger = [STMLogger sharedLogger];
    
    NSString *logMessage = @"startSocket";
    [logger saveLogMessageWithText:logMessage
                           numType:STMLogMessageTypeInfo];
    
    logMessage = [NSString stringWithFormat:@"self.socket %@, self.socketUrl %@, self.isRunning %@, self.isManualReconnecting %@, self.socket.sid %@", self.socket, self.socketUrl, @(self.isRunning), @(self.isManualReconnecting), self.socket.sid];
    [logger saveLogMessageWithText:logMessage
                           numType:STMLogMessageTypeInfo];
    
    if (self.socketUrl && !self.isRunning && !self.isManualReconnecting) {
        
        self.isRunning = YES;
        
        logMessage = [NSString stringWithFormat:@"sc.socket %@ sc.socket.sid %@ status %@", self.socket, self.socket.sid, @(self.socket.status)];
        [logger saveLogMessageWithText:logMessage
                               numType:STMLogMessageTypeInfo];
        
        switch (self.socket.status) {
                
            case SocketIOClientStatusNotConnected:
            case SocketIOClientStatusDisconnected: {
                [self.socket connect];
                break;
            }
            case SocketIOClientStatusConnecting: {
                
                break;
            }
            case SocketIOClientStatusConnected: {
                
                break;
            }
                
        }
        
    } else {
        [STMSocketController syncer].syncerState = STMSyncerReceiveData;
    }

}

- (void)closeSocket {
    
    if (self.isRunning) {

        STMLogger *logger = [STMLogger sharedLogger];
        
        NSString *logMessage = [NSString stringWithFormat:@"close socket %@ %@", self.socket, self.socket.sid];
        [logger saveLogMessageWithText:logMessage
                               numType:STMLogMessageTypeInfo];
        
        if (!self.isManualReconnecting) {
            self.socket = nil;
        }
        
        self.socketUrl = nil;
        
        self.isSendingData = NO;
        self.isAuthorized = NO;
        self.isRunning = NO;
        
        self.unsyncedObjectsArray = nil;
        self.syncDateDictionary = nil;
        self.doNotSyncObjectXids = nil;
        
        self.sendingDate = nil;
        
        [self.socket disconnect];
        
    }

}

- (void)closeSocketInBackground {
    
    STMLogger *logger = [STMLogger sharedLogger];
    
    [logger saveLogMessageWithText:@"close socket in background"
                           numType:STMLogMessageTypeInfo];
    
    self.wasClosedInBackground = YES;
    [self closeSocket];
    
}

- (void)reconnectSocket {

    STMLogger *logger = [STMLogger sharedLogger];
    
    NSString *logMessage = [NSString stringWithFormat:@"reconnectSocket %@ %@", self.socket, self.socket.sid];
    [logger saveLogMessageWithText:logMessage
                           numType:STMLogMessageTypeInfo];

    if (self.isRunning) {

        logMessage = [NSString stringWithFormat:@"socket %@ %@ isRunning, close socket first", self.socket, self.socket.sid];
        [logger saveLogMessageWithText:logMessage
                               numType:STMLogMessageTypeInfo];

        self.isManualReconnecting = YES;
        [STMSocketController closeSocket];
        
    } else {
    
        [STMSocketController startSocket];

    }
    
}

- (NSString *)socketUrl {
    
    if (!_socketUrl) {
        _socketUrl = [STMCoreSettingsController stringValueForSettings:@"socketUrl" forGroup:@"syncer"];
    }
//    _socketUrl = @"http://lamac3.local:8000/socket.io-client";
    return _socketUrl;
    
}

- (void)checkAuthorizationForSocket:(SocketIOClient *)socket {
    
    if ([self isItCurrentSocket:socket failString:@"checkAuthorization"]) {

        STMLogger *logger = [STMLogger sharedLogger];
        
        NSString *logMessage = [NSString stringWithFormat:@"checkAuthorizationForSocket: %@ %@", socket, socket.sid];
        [logger saveLogMessageWithText:logMessage
                               numType:STMLogMessageTypeInfo];

        if (socket.status == SocketIOClientStatusConnected) {
        
            if (self.isAuthorized) {
                
                logMessage = [NSString stringWithFormat:@"socket %@ %@ is authorized", socket, socket.sid];
                [logger saveLogMessageWithText:logMessage
                                       numType:STMLogMessageTypeInfo];
                
            } else {
                
                logMessage = [NSString stringWithFormat:@"socket %@ %@ is connected but don't receive authorization ack, reconnecting", socket, socket.sid];
                [logger saveLogMessageWithText:logMessage
                                       numType:STMLogMessageTypeError];
                
                [self reconnectSocket];
                
            }
            
        } else {
            
            logMessage = [NSString stringWithFormat:@"socket %@ %@ is not connected", socket, socket.sid];
            [logger saveLogMessageWithText:logMessage
                                   numType:STMLogMessageTypeInfo];
            
        }

    }
    
}

- (void)startDelayedAuthorizationCheckForSocket:(SocketIOClient *)socket {
    
    SEL checkAuthSel = @selector(checkAuthorizationForSocket:);
    
    [STMSocketController cancelPreviousPerformRequestsWithTarget:self
                                                        selector:checkAuthSel
                                                          object:socket];
    
    [self performSelector:checkAuthSel
               withObject:socket
               afterDelay:CHECK_AUTHORIZATION_DELAY];

}


@end
