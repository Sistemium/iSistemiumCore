//
//  STMSocketController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 10/10/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMSocketController.h"
#import "STMAuthController.h"
#import "STMClientDataController.h"
#import "STMObjectsController.h"
#import "STMRemoteController.h"
#import "STMEntityController.h"

#import "STMSessionManager.h"

#import "STMRootTBC.h"

#import "STMFunctions.h"


#define SOCKET_URL @"https://socket.sistemium.com/socket.io-client"
#define CHECK_AUTHORIZATION_DELAY 15


@interface STMSocketController() <NSFetchedResultsControllerDelegate>

@property (nonatomic, strong) SocketIOClient *socket;
@property (nonatomic, strong) NSString *socketUrl;
@property (nonatomic) BOOL isRunning;
@property (nonatomic, strong) NSMutableDictionary *syncDataDictionary;
@property (nonatomic, strong) NSMutableArray *resultsControllers;
@property (nonatomic) BOOL controllersDidChangeContent;
@property (nonatomic) BOOL isAuthorized;
@property (nonatomic) BOOL isSendingData;
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
    } else {
        return STMSocketEventInfo;
    }
    
}

+ (STMSyncer *)syncer {
    return [[STMSessionManager sharedManager].currentSession syncer];
}

+ (STMDocument *)document {
    return [[STMSessionManager sharedManager].currentSession document];
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


#pragma mark - sync

+ (NSArray *)unsyncedObjects {
    return [[self sharedInstance] unsyncedObjectsArray];
}

+ (NSUInteger)numbersOfUnsyncedObjects {
    return [self unsyncedObjects].count;
}

+ (void)sendUnsyncedObjects:(id)sender {

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

+ (BOOL)haveToSyncObjects {
    
    NSArray *unsyncedObjectsArray = [self unsyncedObjects];

    NSArray *syncDataArray = [self syncDataArrayFromUnsyncedObjects:unsyncedObjectsArray];

    if (syncDataArray.count > 0) {

        NSLog(@"%d objects to send via Socket", syncDataArray.count);
        [self sendEvent:STMSocketEventData withValue:syncDataArray];
        
        return YES;
        
    } else {
        
        return NO;
        
    }
    
}

+ (NSMutableArray *)syncDataArrayFromUnsyncedObjects:(NSArray *)unsyncedObjectsArray {
    
    NSMutableArray *syncDataArray = [NSMutableArray array];
    
    for (STMDatum *unsyncedObject in unsyncedObjectsArray) {

        if (unsyncedObject.xid) {
            
            NSData *xid = unsyncedObject.xid;
            
            if (![[self sharedInstance].syncDataDictionary.allKeys containsObject:xid]) {
                
                [self addObject:unsyncedObject toSyncDataArray:syncDataArray];
                
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

+ (void)addObject:(NSManagedObject *)object toSyncDataArray:(NSMutableArray *)syncDataArray {
    
//    NSDate *currentDate = [NSDate date];
//    [object setValue:currentDate forKey:@"sts"];
    
    NSDictionary *objectDictionary = [STMObjectsController dictionaryForObject:object];
    
    [syncDataArray addObject:objectDictionary];

}

+ (NSDate *)deviceTsForSyncedObjectXid:(NSData *)xid {

    NSDate *deviceTs = [self sharedInstance].syncDataDictionary[xid];
    return deviceTs;
    
}

+ (void)successfullySyncObjectWithXid:(NSData *)xid {
    if (xid) [[self sharedInstance].syncDataDictionary removeObjectForKey:xid];
}


+ (void)reloadResultsControllers {
    [[self sharedInstance] reloadResultsControllers];
}


#pragma mark - socket events receiveing

- (void)addEventObserversToSocket:(SocketIOClient *)socket {
    
    NSLog(@"addEventObserversToSocket %@", socket);
    
    [STMSocketController addOnAnyEventToSocket:socket];

    [STMSocketController addEvent:STMSocketEventConnect toSocket:socket];
    [STMSocketController addEvent:STMSocketEventDisconnect toSocket:socket];
    [STMSocketController addEvent:STMSocketEventRemoteCommands toSocket:socket];
    [STMSocketController addEvent:STMSocketEventData toSocket:socket];
    
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
    NSMutableDictionary *dataDic = [[STMObjectsController dictionaryForObject:clientData][@"properties"] mutableCopy];
    
    NSDictionary *authDic = @{@"userId"         : [STMAuthController authController].userID,
                              @"accessToken"    : [STMAuthController authController].accessToken};
    
    [dataDic addEntriesFromDictionary:authDic];
    
    NSString *event = [STMSocketController stringValueForEvent:STMSocketEventAuthorization];
    
    [socket emitWithAck:event withItems:@[dataDic]](0, ^(NSArray *data) {
        [self socket:socket receiveAckWithData:data forEvent:event];
    });
    
}

+ (void)disconnectCallbackWithData:(NSArray *)data ack:(SocketAckEmitter *)ack socket:(SocketIOClient *)socket {
    
    NSLog(@"disconnectCallback socket %@", socket);
    
    if ([self sharedInstance].isReconnecting) {
        
        [self sharedInstance].isReconnecting = NO;
        [self startSocket];
        
    }

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
                        
                        [self sharedInstance].isSendingData = YES;
                        
                        [socket emitWithAck:eventStringValue withItems:@[dataDic]](0, ^(NSArray *data) {
                            
                            [self receiveEventDataAckWithData:data];
                            //                        [self receiveAckWithData:data forEvent:eventStringValue];
                            
                        });
                        
                        //                } else if (event == STMSocketEventInfo) {
                        //
                        //                    [socket emitWithAck:eventStringValue withItems:@[dataDic]](0, ^(NSArray *data) {
                        //                        [self receiveAckWithData:data forEvent:eventStringValue];
                        //                    });
                        
                    } else {
                        
                        [socket emit:eventStringValue withItems:@[dataDic]];
                        
                    }
                    
                }
                
            } else {
                NSLog(@"%@ ___ no dataDic to send via socket for event: %@", socket, eventStringValue);
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
                
                if ([[STMRootTBC sharedRootVC].selectedViewController class]) {
                    
                    Class _Nonnull rootVCClass = (Class _Nonnull)[[STMRootTBC sharedRootVC].selectedViewController class];
                    
                    NSString *stringValue = [@"selectedViewController: " stringByAppendingString:NSStringFromClass(rootVCClass)];
                    [self socket:socket sendEvent:STMSocketEventStatusChange withStringValue:stringValue];
                    
                }
                
            }
            
        } else {
            
            NSLog(@"socket not authorized");
            [self sharedInstance].isAuthorized = NO;
            [[STMAuthController authController] logout];
            
        }
        
    } else {
        
        NSLog(@"socket not authorized");
        [self sharedInstance].isAuthorized = NO;
        [[STMAuthController authController] logout];
        
    }

}

+ (void)receiveEventDataAckWithData:(NSArray *)data {

    NSDictionary *response = data.firstObject;
    
    NSString *errorString = nil;
    
    if ([response isKindOfClass:[NSDictionary class]]) {
        
        errorString = response[@"error"];
        
    } else {
        
        errorString = @"response not a dictionary";
        NSLog(@"error: %@", data);
        
    }
    
    if (errorString) {
    
        NSLog(@"error: %@", errorString);
        
        [self sendEvent:STMSocketEventInfo withStringValue:errorString];
//        [[STMLogger sharedLogger] saveLogMessageWithText:errorString type:@"error"];
        
        if ([[errorString.lowercaseString stringByReplacingOccurrencesOfString:@" " withString:@""] isEqualToString:@"notauthorized"]) {
            [[STMAuthController authController] logout];
        }

    } else {
        
        NSArray *dataArray = response[@"data"];
        
        for (NSDictionary *datum in dataArray) {
            
            [[self document].managedObjectContext performBlockAndWait:^{
                [STMObjectsController syncObject:datum];
            }];
            
        }

    }
    
//    NSLog(@"receiveEventDataAckWithData %@", data);
    
//    NSTimeInterval delay = [response[@"data"] count] * 0.1;
    
    [[[STMSessionManager sharedManager].currentSession document] saveDocument:^(BOOL success) {
        [self performSelector:@selector(sendFinishedWithError:) withObject:errorString afterDelay:0];
    }];

}

+ (void)sendFinishedWithError:(NSString *)errorString {
    
    if (errorString) {
        
        [self sharedInstance].isSendingData = NO;
        [[self syncer] sendFinishedWithError:errorString];
        [self sharedInstance].syncDataDictionary = nil;

    } else {

        if ([self haveToSyncObjects]) {
            
            [[self syncer] bunchOfObjectsSended];
            
        } else {
            
            [self sharedInstance].isSendingData = NO;
            [[self syncer] sendFinishedWithError:nil];
            [self sharedInstance].syncDataDictionary = nil;

        }

    }

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
    
    STMSession *currentSession = [STMSessionManager sharedManager].currentSession;
    
    if ([currentSession.status isEqualToString:@"running"]) {
        
        NSString *key = @"socketUrl";
        
        if ([notification.userInfo.allKeys containsObject:key]) {
            
            self.socketUrl = nil;
            
            if (self.isRunning) {
                
                if (![self.socket.socketURL isEqualToString:self.socketUrl]) {
                    [self reconnectSocket];
                }
                
            } else {
                
                [STMSocketController startSocket];
                
            }
            
        }

    }
    
}

- (void)sessionStatusChanged:(NSNotification *)notification {
    
    STMSession *session = [STMSessionManager sharedManager].currentSession;
    
    if (notification.object == session) {
        
        if ([session.status isEqualToString:@"running"]) {
            
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
    
    if ([[STMObjectsController localDataModelEntityNames] containsObject:entityName]) {
        
        STMFetchRequest *request = [STMFetchRequest fetchRequestWithEntityName:entityName];
        request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"id" ascending:YES selector:@selector(compare:)]];
        request.includesSubentities = YES;
        
        NSMutableArray *subpredicates = @[].mutableCopy;
        
        if ([entityName isEqualToString:NSStringFromClass([STMLogMessage class])]) {
            
            STMLogger *logger = [[STMSessionManager sharedManager].currentSession logger];
            
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
        NSString *uploadLogType = [STMSettingsController stringValueForSettings:@"uploadLog.type" forGroup:@"syncer"];
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
        
        _socketUrl = [STMSettingsController stringValueForSettings:@"socketUrl" forGroup:@"appSettings"];
        
    }
    return _socketUrl;
    
}

- (void)checkAuthorizationForSocket:(SocketIOClient *)socket {

    NSLog(@"checkAuthorizationForSocket: %@", socket);
    
    if ([socket isEqual:self.socket]) {
        
        if (self.isAuthorized) {
            
            NSLog(@"socket is authorized");
            
        } else {

            NSLog(@"socket is not authorized, trying to resolve this issue by reconnecting");
            [self reconnectSocket];
            
        }

    } else {
        
        NSLog(@"not a current socket");
        
    }
    
}



@end
