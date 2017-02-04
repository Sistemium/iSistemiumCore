//
//  STMSyncer.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 06/06/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import <AdSupport/AdSupport.h>

#import "STMSyncer.h"
#import "STMDocument.h"

#import "STMSocketTransport.h"

#import "STMCoreObjectsController.h"
#import "STMEntityController.h"
#import "STMClientEntityController.h"
#import "STMClientDataController.h"
#import "STMCoreAuthController.h"

#import "STMDataSyncingSubscriber.h"

#import "STMSocketTransport+Persisting.h"

@interface STMSyncer() <STMDataSyncingSubscriber>

@property (nonatomic, strong) STMDocument *document;
@property (nonatomic, strong) id <STMSocketConnection, STMPersistingWithHeadersAsync> socketTransport;

@property (nonatomic, strong) NSMutableDictionary *settings;
@property (nonatomic) NSInteger fetchLimit;
@property (nonatomic, strong) NSTimer *syncTimer;

@property (nonatomic, strong) NSString *entityResource;
@property (nonatomic, strong) NSString *socketUrlString;
@property (nonatomic) NSTimeInterval httpTimeoutForeground;
@property (nonatomic) NSTimeInterval httpTimeoutBackground;

@property (nonatomic) BOOL isRunning;
@property (nonatomic) BOOL isDefantomizing;
@property (nonatomic) BOOL isUsingNetwork;

@property (nonatomic, strong) NSArray *receivingEntitiesNames;
@property (nonatomic, strong) NSMutableArray *entitySyncNames;
@property (nonatomic, strong) NSMutableDictionary *temporaryETag;

@property (nonatomic) NSUInteger entityCount;
@property (atomic) NSUInteger fantomsCount;

@property (nonatomic, strong) void (^fetchCompletionHandler) (UIBackgroundFetchResult result);
@property (nonatomic) UIBackgroundFetchResult fetchResult;


@end


@implementation STMSyncer

@synthesize syncInterval = _syncInterval;
@synthesize syncerState = _syncerState;


- (instancetype)init {
    
    self = [super init];
    
    if (self) {
        [self customInit];
    }
    
    return self;
    
}

- (void)customInit {
    NSLog(@"syncer init");
}


#pragma mark - observers

- (void)addObservers {
    
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self
           selector:@selector(sessionStatusChanged:)
               name:NOTIFICATION_SESSION_STATUS_CHANGED
             object:self.session];
    
    [nc addObserver:self
           selector:@selector(syncerSettingsChanged)
               name:@"syncerSettingsChanged"
             object:self.session];
    
    [nc addObserver:self
           selector:@selector(appDidBecomeActive)
               name:UIApplicationDidBecomeActiveNotification
             object:nil];
    
    [nc addObserver:self
           selector:@selector(appDidEnterBackground)
               name:UIApplicationDidEnterBackgroundNotification
             object:nil];
    
}

- (void)removeObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)sessionStatusChanged:(NSNotification *)notification {
    
    if ([notification.object isKindOfClass:[STMCoreSession class]]) {
        
        STMCoreSession *session = (STMCoreSession *)notification.object;
        
        if (session == self.session) {
            
            if (session.status == STMSessionFinishing || session.status == STMSessionRemoving) {
                [self stopSyncer];
            } else if (session.status == STMSessionRunning) {
                [self startSyncer];
            }
            
        }
        
    }
    
}

- (void)syncerSettingsChanged {
    [self flushSettings];
}

- (void)appDidBecomeActive {
    
#ifdef DEBUG
    [self setSyncerState:STMSyncerSendData];
#else
    [self setSyncerState:STMSyncerSendDataOnce];
#endif
    
}

- (void)appDidEnterBackground {
    [self setSyncerState:STMSyncerSendDataOnce];
}


#pragma mark - variables setters & getters

- (void)setSyncerState:(STMSyncerState) syncerState fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result)) handler {
    
    self.fetchCompletionHandler = handler;
    self.fetchResult = UIBackgroundFetchResultNewData;
    self.syncerState = syncerState;
    
}

- (void)setSyncerState:(STMSyncerState)syncerState {
    
    if (self.isRunning && syncerState != _syncerState) {
        
        STMSyncerState previousState = _syncerState;
        
        _syncerState = syncerState;
        
        NSArray *syncStates = @[@"idle", @"sendData", @"sendDataOnce", @"receiveData"];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SYNCER_STATUS_CHANGED
                                                                object:self
                                                              userInfo:@{@"from":@(previousState), @"to":@(syncerState)}];
            
        });
        
        
        NSString *logMessage = [NSString stringWithFormat:@"Syncer %@", syncStates[syncerState]];
        NSLog(@"%@", logMessage);
        
        switch (_syncerState) {
            case STMSyncerIdle: {
                break;
            }
            case STMSyncerSendData:
            case STMSyncerSendDataOnce: {
                
                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
                [STMClientDataController checkClientData];
                self.syncerState = STMSyncerIdle;
                
                break;
            }
            case STMSyncerReceiveData: {
                
                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
                [self receiveData];
                self.syncerState = STMSyncerIdle;
                
                break;
            }
            default: {
                break;
            }
        }
        
    }
    
    return;
    
}

- (void)setSession:(id <STMSession>)session {
    
    if (session != _session) {
        
        self.document = (STMDocument *)session.document;

        _session = session;
        
        [self startSyncer];
        
    }
    
}

- (NSMutableDictionary *)settings {
    
    if (!_settings) {
        _settings = [[(id <STMSession>)self.session settingsController] currentSettingsForGroup:@"syncer"];
    }
    return _settings;
    
}

- (NSTimeInterval)syncInterval {
    
    if (!_syncInterval) {
        _syncInterval = [self.settings[@"syncInterval"] doubleValue];
    }
    return _syncInterval;
    
}

- (void)setSyncInterval:(double)syncInterval {

    if (_syncInterval != syncInterval) {
        
        [self releaseTimer];
        _syncInterval = syncInterval;
        [self initTimer];
        
    }
    
}

- (NSInteger)fetchLimit {

    if (!_fetchLimit) {
        _fetchLimit = [self.settings[@"fetchLimit"] integerValue];
    }
    return _fetchLimit;
    
}

- (NSTimeInterval)httpTimeoutForeground {
    
    if (!_httpTimeoutForeground) {
        _httpTimeoutForeground = [self.settings[@"http.timeout.foreground"] doubleValue];
    }
    return _httpTimeoutForeground;
    
}

- (NSTimeInterval)httpTimeoutBackground {
    
    if (!_httpTimeoutBackground) {
        _httpTimeoutBackground = [self.settings[@"http.timeout.background"] doubleValue];
    }
    return _httpTimeoutBackground;
    
}

- (NSMutableDictionary *)stcEntities {
    
    if (!_stcEntities) {
        _stcEntities = [STMEntityController stcEntities].mutableCopy;
    }
    return _stcEntities;
    
}

- (void)setIsReceivingData:(BOOL)isReceivingData {

    if (_isReceivingData != isReceivingData) {

        _isReceivingData = isReceivingData;

        if (isReceivingData) {
            
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
            [self receiveStarted];
            
        } else {
            
            [self turnOffNetworkActivityIndicator];
            [self receiveFinished];
            
        }
        
    }

}

- (void)setIsDefantomizing:(BOOL)isDefantomizing {
    
    if (_isDefantomizing != isDefantomizing) {
        
        _isDefantomizing = isDefantomizing;
        
        if (isDefantomizing) {
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
        } else {
            [self turnOffNetworkActivityIndicator];
        }
        
    }
    
}

- (void)setIsSendingData:(BOOL)isSendingData {
    
    if (_isSendingData != isSendingData) {
        
        _isSendingData = isSendingData;
        
        if (isSendingData) {
            
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
            [self sendStarted];
            
        } else {
            
            [self turnOffNetworkActivityIndicator];
            [self sendFinished];

        }
        
    }
}

- (void)setEntityCount:(NSUInteger)entityCount {
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"entityCountdownChange"
                                                            object:self
                                                          userInfo:@{@"countdownValue": @((int)entityCount)}];

    });
    
    _entityCount = entityCount;
    
}

- (void)turnOffNetworkActivityIndicator {
    
    if (!self.isUsingNetwork) {
        
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        [self checkAppState];
        
    }

}

- (void)checkAppState {
    
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
        [self closeSocketInBackground];
    }
    
}

- (BOOL)isUsingNetwork {
    return self.isReceivingData || self.isDefantomizing || self.isSendingData;
}

- (NSTimeInterval)timeout {
    return ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) ? self.httpTimeoutBackground : self.httpTimeoutForeground;
}

- (BOOL)transportIsReady {
    return self.socketTransport.isReady;
}

- (NSMutableDictionary *)temporaryETag {
    
    if (!_temporaryETag) {
        _temporaryETag = [NSMutableDictionary dictionary];
    }
    return _temporaryETag;
    
}

- (NSMutableArray *)entitySyncNames {
    
    if (!_entitySyncNames) {
        _entitySyncNames = [NSMutableArray array];
    }
    return _entitySyncNames;
    
}

- (NSString *)entityResource {

    if (!_entityResource) {
        _entityResource = self.settings[@"entityResource"];
    }
    return _entityResource;
    
}

- (NSString *)socketUrlString {

    if (!_socketUrlString) {
        _socketUrlString = self.settings[@"socketUrl"];
    }
    return _socketUrlString;
    
}


#pragma mark - start syncer methods

- (void)startSyncer {
    
    if (!self.isRunning && self.session.status == STMSessionRunning) {
        
        self.settings = nil;
        
        [self checkStcEntitiesWithCompletionHandler:^(BOOL success) {
            
            if (success) {
                
                [STMEntityController checkEntitiesForDuplicates];
                [STMClientDataController checkClientData];
                [self.session.logger saveLogMessageDictionaryToDocument];
                [self.session.logger saveLogMessageWithText:@"Syncer start"];
                
                [self checkUploadableEntities];
                
                [self addObservers];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SYNCER_INIT_SUCCESSFULLY
                                                                        object:self];

                });
                
                if (self.socketUrlString) {
                    
                    self.socketTransport = [STMSocketTransport transportWithUrl:self.socketUrlString
                                                              andEntityResource:self.entityResource
                                                                          owner:self];
                    
                    if (!self.socketTransport) {
                        
                        NSLog(@"can not start socket transport");
                        [[STMCoreAuthController authController] logout];
                        
                    }
                    
                    //                    [STMSocketController startSocketWithUrl:self.socketUrlString
                    //                                          andEntityResource:self.entityResource];
                    
                } else {
                    
                    NSLog(@"have NO socketURL, fail to start socket controller");
                    [[STMCoreAuthController authController] logout];
                    
                }
                
                self.isRunning = YES;
                
            } else {
                
                [[STMLogger sharedLogger] saveLogMessageWithText:@"checkStcEntities fail"
                                                         numType:STMLogMessageTypeError];
                
            }
            
        }];
        
    }
    
}


#pragma mark - stop syncer methods

- (void)stopSyncer {
    
    if (self.isRunning) {
        
        //        [STMSocketController closeSocket];
        
        [self.session.logger saveLogMessageWithText:@"Syncer stop"];
        //        self.syncing = NO;
        self.syncerState = STMSyncerIdle;
        [self releaseTimer];
        [self flushSettings];
        self.isRunning = NO;
        
    }
    
}

- (void)prepareToDestroy {
    
    [self removeObservers];
    [self stopSyncer];
    
}

- (void)flushSettings {
    
    self.settings = nil;
    
    self.fetchLimit = 0;
    self.entityResource = nil;
    self.socketUrlString = nil;
    //    self.xmlNamespace = nil;
    self.httpTimeoutForeground = 0;
    self.httpTimeoutBackground = 0;
    self.syncInterval = 0;
    //    self.uploadLogType = nil;
    
}


#pragma mark - STMSocketConnectionOwner protocol

- (void)socketReceiveAuthorization {
    
    NSLogMethodName;
    
    [self initTimer];
    
}

- (void)socketLostConnection {

    NSLogMethodName;
    
    [self releaseTimer];
    
    [self unsubscribeFromUnsyncedObjects];
    
    if (self.isReceivingData) {
        
        [self entityCountDecreaseWithError:@"socketLostConnection"
                           finishReceiving:YES];
        
    }
    
    if (self.isDefantomizing) {
        [self stopDefantomizing];
    }

}

- (void)checkStcEntitiesWithCompletionHandler:(void (^)(BOOL success))completionHandler {
    
    NSDictionary *stcEntities = [STMEntityController stcEntities];
    
    NSString *stcEntityName = NSStringFromClass([STMEntity class]);
    
    if (!stcEntities[stcEntityName]) {
        
        STMEntity *entity = (STMEntity *)[STMCoreObjectsController newObjectForEntityName:stcEntityName isFantom:NO];
        
        stcEntityName = [STMFunctions removePrefixFromEntityName:stcEntityName];
        
        entity.name = stcEntityName;
        entity.url = self.entityResource;
        
         [self.document saveDocument:^(BOOL success) {
         }];
         // otherwise syncer does not start before socket is connected+authorized
         completionHandler(YES);
        
    } else {
        
        STMEntity *entity = stcEntities[stcEntityName];
        
        if (![entity.url isEqualToString:self.entityResource]) {
            
            NSLog(@"change STMEntity url from %@ to %@", entity.url, self.entityResource);
            
            entity.url = self.entityResource;
            
        }
        
        completionHandler(YES);
        
    }
    
}

- (void)checkUploadableEntities {
    
    NSArray *uploadableEntitiesNames = [STMEntityController uploadableEntitiesNames];
    NSLog(@"uploadableEntitiesNames %@", uploadableEntitiesNames);
    
    if (uploadableEntitiesNames.count == 0) {
        
        NSString *stcEntityName = NSStringFromClass([STMEntity class]);
        
        stcEntityName = [STMFunctions removePrefixFromEntityName:stcEntityName];
        
        STMClientEntity *clientEntity = [STMClientEntityController clientEntityWithName:stcEntityName];
        clientEntity.eTag = nil;
        
    }
    
}

- (void)checkSocket {
    [self.socketTransport checkSocket];
}

- (void)checkSocketForBackgroundFetchWithFetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))handler {
    
    self.fetchCompletionHandler = handler;
    self.fetchResult = UIBackgroundFetchResultNewData;
    [self.socketTransport checkSocket];

}

- (void)closeSocketInBackground {
    
    [STMSyncer cancelPreviousPerformRequestsWithTarget:self
                                              selector:@selector(closeSocketInBackground)
                                                object:nil];

    [self.socketTransport closeSocketInBackground];
    
}


#pragma mark - timer

- (NSTimer *)newSyncTimer {
   
    NSTimeInterval syncInterval = self.syncInterval ? self.syncInterval : 0;
    BOOL repeats = self.syncInterval ? YES : NO;

    NSTimer *syncTimer = [[NSTimer alloc] initWithFireDate:[NSDate date]
                                                  interval:syncInterval
                                                    target:self
                                                  selector:@selector(onTimerTick:)
                                                  userInfo:nil
                                                   repeats:repeats];
    
    return syncTimer;

}

- (void)initTimer {
    
    if (self.syncTimer) {
        [self releaseTimer];
    }
    
    self.syncTimer = [self newSyncTimer];
    
    [[NSRunLoop currentRunLoop] addTimer:self.syncTimer
                                 forMode:NSRunLoopCommonModes];
    
}

- (void)releaseTimer {
    
    if (self.syncTimer) {
    
        [self.syncTimer invalidate];
        self.syncTimer = nil;

    }
    
}

- (void)onTimerTick:(NSTimer *)timer {
    
#ifdef DEBUG
    NSTimeInterval bgTR = [UIApplication sharedApplication].backgroundTimeRemaining;
    NSLog(@"syncTimer tick at %@, bgTimeRemaining %.0f", [NSDate date], bgTR > 3600 ? -1 : bgTR);
#endif
    
    if (self.socketTransport.isReady) {
        [self receiveData];
    }
    
}


#pragma mark - remote control methods

- (void)upload {
    [self setSyncerState:STMSyncerSendDataOnce];
}

- (void)fullSync {
    [self setSyncerState:STMSyncerSendData];
}

- (void)receiveEntities:(NSArray *)entitiesNames {
    
    if ([entitiesNames isKindOfClass:[NSArray class]]) {
        
        NSArray *localDataModelEntityNames = [STMCoreObjectsController localDataModelEntityNames];
        NSMutableArray *existingNames = [@[] mutableCopy];
        
        for (NSString *entityName in entitiesNames) {
            
            NSString *name = [STMFunctions addPrefixToEntityName:entityName];
            
            if ([localDataModelEntityNames containsObject:name]) {
                [existingNames addObject:name];
            }
            
        }
        
        if (existingNames.count > 0) {
            
            self.receivingEntitiesNames = existingNames;
            [self setSyncerState:STMSyncerReceiveData];
            
        }
        
    } else {
        
        NSString *logMessage = @"receiveEntities: argument is not an array";
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage type:@"error"];
        
    }
    
}

- (void)sendEventViaSocket:(STMSocketEvent)event withValue:(id)value {
    [self.socketTransport socketSendEvent:event withValue:value];
}

#pragma mark - recieve data

- (void)receiveData {
    
    if (!self.isReceivingData) {
        
        self.isReceivingData = YES;
        
        if (!self.receivingEntitiesNames || [self.receivingEntitiesNames containsObject:@"STMEntity"]) {
            
            self.entityCount = 1;
            
            [self checkConditionForReceivingEntityWithName:@"STMEntity"];
            
        } else {
            
            self.entitySyncNames = self.receivingEntitiesNames.mutableCopy;
            self.receivingEntitiesNames = nil;
            self.entityCount = self.entitySyncNames.count;
            
            [self checkConditionForReceivingEntityWithName:self.entitySyncNames.firstObject];
            
        }
        
    }

}

- (void)receiveStarted {

    dispatch_async(dispatch_get_main_queue(), ^{
       
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SYNCER_RECEIVE_STARTED
                                                            object:self];

    });
    
}

- (void)receiveFinished {

    dispatch_async(dispatch_get_main_queue(), ^{
        
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SYNCER_RECEIVE_FINISHED
                                                            object:self];
        
    });

}

- (void)checkConditionForReceivingEntityWithName:(NSString *)entityName {
    
    NSLog(@"checkConditionForReceivingEntityWithName: %@", entityName);
    
    if (!self.socketTransport.isReady) {
        
        [self receivingDidFinishWithError:@"socket transport is not ready"];
        return;
        
    }
    
    NSString *errorMessage = nil;
    
    STMEntity *entity = self.stcEntities[entityName];
    
    NSArray *localDataModelEntityNames = [STMCoreObjectsController localDataModelEntityNames];
    
    if (entity.roleName) {
        
        NSString *roleOwner = entity.roleOwner;
        NSString *roleOwnerEntityName = [ISISTEMIUM_PREFIX stringByAppendingString:roleOwner];
        
        if (![localDataModelEntityNames containsObject:roleOwnerEntityName]) {
            errorMessage = [NSString stringWithFormat:@"local data model have no %@ entity for relationship %@", roleOwnerEntityName, entityName];
        } else {
            
            NSString *roleName = entity.roleName;
            NSDictionary *ownerRelationships = [STMCoreObjectsController ownObjectRelationshipsForEntityName:roleOwnerEntityName];
            NSString *destinationEntityName = ownerRelationships[roleName];
            
            if (![localDataModelEntityNames containsObject:destinationEntityName]) {
                errorMessage = [NSString stringWithFormat:@"local data model have no %@ entity for relationship %@", destinationEntityName, entityName];
            }
            
        }
        
    }
    
    if (errorMessage) {
        
        [self entityCountDecreaseWithError:errorMessage];
        
    } else {
        
        if (entity.roleName || [localDataModelEntityNames containsObject:entityName]) {
            
            NSString *resource = [entity resource];
            
            if (resource) {
                
                STMClientEntity *clientEntity = [STMClientEntityController clientEntityWithName:entity.name];
                
                NSString *eTag = clientEntity.eTag;
                eTag = eTag ? eTag : @"*";

                [self receiveDataForEntityName:entityName
                                          eTag:eTag];
                
            } else {
                
                NSString *errorMessage = [NSString stringWithFormat:@"    %@: have no url", entityName];
                [self entityCountDecreaseWithError:errorMessage];
                
            }
            
        } else {
            
            NSString *errorMessage = [NSString stringWithFormat:@"    %@: do not exist in local data model", entityName];
            [self entityCountDecreaseWithError:errorMessage];
            
        }
        
    }
    
}

- (void)receiveDataForEntityName:(NSString *)entityName eTag:(NSString * _Nonnull)eTag {
    
    __block BOOL blockIsComplete = NO;
    
    NSDictionary *options = @{STMPersistingOptionPageSize: @(self.fetchLimit),
                              @"offset"     : eTag};

    [self.socketTransport findAllAsync:entityName predicate:nil options:options completionHandlerWithHeaders:^(BOOL success, NSArray *result, NSDictionary *headers, NSError *error) {
        
        if (blockIsComplete) {
            NSLog(@"completionHandler for %@ %@ already complete", entityName, eTag);
            return;
        }
        
        blockIsComplete = YES;

        if (success) {
            
            [self parseFindAllAckResponseData:result
                                   entityName:entityName
                                      headers:headers];
            
        } else {
            
            if (self.entityCount > 0) {
                [self entityCountDecreaseWithError:error.localizedDescription];
            } else {
                [self receivingDidFinishWithError:error.localizedDescription];
            }
            
        }

        
    }];
    
}

- (void)entityCountDecrease {
    [self entityCountDecreaseWithError:nil];
}

- (void)entityCountDecreaseWithError:(NSString *)errorMessage {
    [self entityCountDecreaseWithError:errorMessage finishReceiving:NO];
}

- (void)entityCountDecreaseWithError:(NSString *)errorMessage finishReceiving:(BOOL)finishReceiving {
    
    if (errorMessage) {
        
        NSString *logMessage = [NSString stringWithFormat:@"entityCountDecreaseWithError: %@", errorMessage];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                 numType:STMLogMessageTypeError];
        
    }
    
    if (!finishReceiving && --self.entityCount) {
        
        NSLog(@"remain %@ entities to receive", @(self.entityCount));
        
        if (self.entitySyncNames.firstObject) [self.entitySyncNames removeObject:(id _Nonnull)self.entitySyncNames.firstObject];
        
        if (self.entitySyncNames.firstObject) {
            
            [self.document saveDocument:^(BOOL success) {}];
            
            [self checkConditionForReceivingEntityWithName:self.entitySyncNames.firstObject];
            
        } else {
            
            [self receivingDidFinish];
            
        }
        
    } else {

        NSLog(@"remain %@ entities to receive", @(self.entityCount));

        [self receivingDidFinish];
        
    }
    
}

- (void)receiveNoContentStatusForEntityWithName:(NSString *)entityName {
    
    if ([entityName isEqualToString:@"STMEntity"]) {
        
        [STMEntityController flushSelf];
        [self subscribeToUnsyncedObjects];
        
        self.stcEntities = nil;
        
        NSMutableArray *entitiesNames = [self.stcEntities keysOfEntriesPassingTest:^BOOL(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            return [obj valueForKey:@"url"] ? YES : NO;
        }].allObjects.mutableCopy;
        
        [entitiesNames removeObject:entityName];
        
        NSUInteger settingsIndex = [entitiesNames indexOfObject:@"STMSetting"];
        if (settingsIndex != NSNotFound) [entitiesNames exchangeObjectAtIndex:settingsIndex
                                                                   withObjectAtIndex:0];

        self.entitySyncNames = entitiesNames;
        self.entityCount = entitiesNames.count;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [[NSNotificationCenter defaultCenter] postNotificationName:@"entitiesReceivingDidFinish"
                                                                object:self];

        });
        
        [self.document saveDocument:^(BOOL success) {}];
        
        [self checkConditionForReceivingEntityWithName:self.entitySyncNames.firstObject];
        
    } else {
        [self entityCountDecrease];
    }
    
}

- (void)fillETagWithTemporaryValueForEntityName:(NSString *)entityName {
    
    NSString *eTag = self.temporaryETag[entityName];
    STMEntity *entity = self.stcEntities[entityName];
    STMClientEntity *clientEntity = [STMClientEntityController clientEntityWithName:entity.name];
    
    clientEntity.eTag = eTag;
    
}

- (void)nextReceiveEntityWithName:(NSString *)entityName {
    
    [self fillETagWithTemporaryValueForEntityName:entityName];
    [self checkConditionForReceivingEntityWithName:entityName];
    
}

- (void)receivingDidFinish {
    [self receivingDidFinishWithError:nil];
}

- (void)receivingDidFinishWithError:(NSString *)errorString {
    
    if (errorString) {
        
        NSString *logMessage = [NSString stringWithFormat:@"receivingDidFinishWithError: %@", errorString];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                 numType:STMLogMessageTypeError];
        
    } else {
        
#warning - do it only if have no error or always?
        [self saveReceiveDate];
        
    }
    
    if (self.receivingEntitiesNames) {
        
        [self receiveData];
        
    } else {

        [self startDefantomization];
        
        [STMCoreObjectsController dataLoadingFinished];
        
        if (self.fetchCompletionHandler) {
            
            self.fetchCompletionHandler(self.fetchResult);
            self.fetchCompletionHandler = nil;
            
        }
        
        self.isReceivingData = NO;

    }

}

- (void)saveReceiveDate {
    
    STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
    
    NSString *key = [@"receiveDate" stringByAppendingString:self.session.uid];
    
    NSString *receiveDateString = [[STMFunctions dateShortTimeShortFormatter] stringFromDate:[NSDate date]];
    
    [defaults setObject:receiveDateString forKey:key];
    [defaults synchronize];
    
}


#pragma mark - defantomization

- (void)startDefantomization {
    
    if (!self.socketTransport.isReady) {
        
        [self.syncerHelper defantomizingFinished];
        return;
        
    }
    
    if (self.isDefantomizing) {
        return;
    }
    
    self.isDefantomizing = YES;
    
    [self.syncerHelper findFantomsWithCompletionHandler:^(NSArray <NSDictionary *> *fantomsArray) {
        
        if (fantomsArray) {
        
//            NSLog(@"fantomsArray: %@", fantomsArray);
            
            self.fantomsCount = fantomsArray.count;

            for (NSDictionary *fantomDic in fantomsArray) {
                [self defantomizeObject:fantomDic];
            }
            
        } else {
            [self stopDefantomizing];
        }
        
    }];
    
}

- (void)defantomizeObject:(NSDictionary *)fantomDic {
    
    if (!self.isDefantomizing) {
        return;
    }
    
    NSString *entityName = fantomDic[@"entityName"];
    NSString *fantomId = fantomDic[@"id"];
    
    entityName = [STMFunctions addPrefixToEntityName:entityName];
    
    __block BOOL blockIsComplete = NO;
    
    [self.socketTransport findAsync:entityName identifier:fantomId options:nil completionHandlerWithHeaders:^(BOOL success, NSDictionary *result, NSDictionary *headers, NSError *error) {

        if (blockIsComplete) {
            NSLog(@"completionHandler for %@ already complete", entityName);
            return;
        }
        
        blockIsComplete = YES;

        if (success) {
            
            NSDictionary *context = @{@"type"  : DEFANTOMIZING_CONTEXT,
                                      @"object": fantomDic};
            
            [self receiveFindAckWithResponse:result
                                  entityName:entityName
                                     context:context];
            
        } else {
            
            [self defantomizingObject:fantomDic
                                error:error.localizedDescription];

        }
        
    }];

}

- (void)defantomizingObject:(NSDictionary *)fantomDic error:(NSString *)errorString {
    [self defantomizingObject:fantomDic error:errorString deleteObject:NO];
}

- (void)defantomizingObject:(NSDictionary *)fantomDic error:(NSString *)errorString deleteObject:(BOOL)deleteObject {
    
    NSLog(@"defantomize error: %@", errorString);
    
    [self.syncerHelper defantomizeErrorWithObject:fantomDic
                                     deleteObject:deleteObject];
    [self fantomsCountDecrease];
    
    return;
    
}

- (void)fantomsCountDecrease {

    if (!--self.fantomsCount) {
        
        self.isDefantomizing = NO;
        [self startDefantomization];
        
    } else {
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        
                [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_DEFANTOMIZING_UPDATE
                                                                object:self
                                                              userInfo:@{@"fantomsCount": @(self.fantomsCount)}];

            
        }];
        
    }

}

- (void)stopDefantomizing {
    
    self.isDefantomizing = NO;
    [self.syncerHelper defantomizingFinished];

}


#pragma mark - socket ack handlers

#pragma mark findAll ack handler

- (void)parseFindAllAckResponseData:(NSArray *)responseData entityName:(NSString *)entityName headers:(NSDictionary *)headers {
    
    if (entityName) {
        
        if (responseData.count > 0) {
            
            NSString *offset = headers[@"offset"];
            NSUInteger pageSize = [headers[STMPersistingOptionPageSize] integerValue];
            
            if (offset) {
                
                BOOL isLastPage = responseData.count < pageSize;
                
                if (entityName) self.temporaryETag[entityName] = offset;
                
                [self parseSocketFindAllResponseData:responseData
                                       forEntityName:entityName
                                          isLastPage:isLastPage];
                
            } else {
                
                NSLog(@"    %@: receive data w/o offset", entityName);
                [self receiveNoContentStatusForEntityWithName:entityName];
                
            }
            
        } else {
            
            NSLog(@"    %@: have no new data", entityName);
            [self receiveNoContentStatusForEntityWithName:entityName];
            
        }
        
    } else {
        
        NSString *logMessage = [NSString stringWithFormat:@"ERROR: unknown entity response: %@", entityName];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                 numType:STMLogMessageTypeError];
        
    }
    
}

- (void)parseSocketFindAllResponseData:(NSArray *)data forEntityName:(NSString *)entityName isLastPage:(BOOL)isLastPage {
    
    STMEntity *entity = self.stcEntities[entityName];
    
    if (entity) {
        
        NSMutableDictionary *options = @{STMPersistingOptionLts: [STMFunctions stringFromNow]}.mutableCopy;

        NSString *roleName = entity.roleName;
        
        if (roleName) {
            options[@"roleName"] = roleName;
        }

// sync
//        NSError *error = nil;
//        NSArray *result = [self.persistenceDelegate mergeManySync:entityName attributeArray:data options:options error:&error];
//        
//        if (error) {
//            [self findAllResultMergedWithError:error.localizedDescription];
//        } else {
//            
//            [self findAllResultMergedWithSuccess:data
//                                      entityName:entityName
//                                      isLastPage:isLastPage];
//            
//        }

// async
        [self.persistenceDelegate mergeManyAsync:entityName
                                  attributeArray:data
                                         options:options
                               completionHandler:^(BOOL success, NSArray *result, NSError *error) {
            
            if (success) {

                [self findAllResultMergedWithSuccess:data
                                          entityName:entityName
                                          isLastPage:isLastPage];

            } else {
                [self findAllResultMergedWithError:error.localizedDescription];
            }
            
        }];
        
// promised
//        [self.persistenceDelegate mergeMany:entityName attributeArray:data options:options].then(^(NSArray *result){
//
//            [self findAllResultMergedWithSuccess:data
//                                      entityName:entityName
//                                      isLastPage:isLastPage];
//
//        }).catch(^(NSError *error){
//
//            [self findAllResultMergedWithError:error.localizedDescription];
//
//        });

// old style — same as promised
//        [STMCoreObjectsController processingOfDataArray:data withEntityName:entityName andRoleName:entity.roleName withCompletionHandler:^(BOOL success) {
//
//            if (success) {
//
//                [self findAllResultMergedWithSuccess:data
//                                         entityName:entityName
//                                         isLastPage:isLastPage];
//
//            } else {
//                
//                NSString *errorString = [NSString stringWithFormat:@"error in processingOfDataArray:%@ withEntityName: %@", data, entityName];
//                [self findAllResultMergedWithError:errorString];
//                
//            }
//            
//        }];
        
    }
    
}

- (void)findAllResultMergedWithSuccess:(NSArray *)result entityName:(NSString *)entityName isLastPage:(BOOL)isLastPage {
    
    NSLog(@"    %@: get %@ objects", entityName, @(result.count));
    
    if (isLastPage) {
        
        NSLog(@"    %@: pageRowCount < pageSize / No more content", entityName);
        
        [self fillETagWithTemporaryValueForEntityName:entityName];
        [self receiveNoContentStatusForEntityWithName:entityName];
        
    } else {
        
        [self nextReceiveEntityWithName:entityName];
        
    }
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        
            [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SYNCER_BUNCH_OF_OBJECTS_RECEIVED
                                                                object:self
                                                              userInfo:@{@"count"         :@(result.count),
                                                                         @"entityName"    :entityName}];
        
    }];

}

- (void)findAllResultMergedWithError:(NSString *)errorString {
    [self entityCountDecreaseWithError:errorString];
}


#pragma mark find ack handler

- (void)receiveFindAckWithResponse:(NSDictionary *)response entityName:(NSString *)entityName context:(NSDictionary *)context {
        
    NSData *xid = [STMFunctions xidDataFromXidString:response[@"id"]];
    
    [self parseFindAckResponseData:response
                    withEntityName:entityName
                               xid:xid
                           context:context];
    
}

- (void)socketReceiveJSDataFindAckWithErrorCode:(NSNumber *)errorCode errorString:(NSString *)errorString context:(NSDictionary *)context {

    if (errorCode.integerValue > 499 && errorCode.integerValue < 600) {
        
    }
    
    BOOL defantomizing = [context[@"type"] isEqualToString:DEFANTOMIZING_CONTEXT];
    
    if (defantomizing) {

        BOOL deleteObject = (errorCode.integerValue == 403 || errorCode.integerValue == 404);

        [self defantomizingObject:context[@"object"]
                            error:errorString
                     deleteObject:deleteObject];
        
    } else {
        NSLog(@"find error: %@", errorString);
    }
    
}

- (void)parseFindAckResponseData:(NSDictionary *)responseData withEntityName:(NSString *)entityName xid:(NSData *)xid context:(NSDictionary *)context {
    
    BOOL defantomizing = [context[@"type"] isEqualToString:DEFANTOMIZING_CONTEXT];
    
    //    NSLog(@"find responseData %@", responseData);
    
    if (!entityName) {

        NSString *errorMessage = @"Syncer parseFindAckResponseData !entityName";
        
        if (defantomizing) {
        
            [self defantomizingObject:context[@"object"]
                                error:errorMessage];

        } else {
        
            [[STMLogger sharedLogger] saveLogMessageWithText:errorMessage
                                                     numType:STMLogMessageTypeError];

        }
        
        return;
        
    }
    
    NSDictionary *options = @{STMPersistingOptionLts: [STMFunctions stringFromNow]};
    
    [self.persistenceDelegate mergeAsync:entityName attributes:responseData options:options completionHandler:^(BOOL success, NSDictionary *result, NSError *error) {

        if (defantomizing) {
            
            NSDictionary *object = context[@"object"];
            
            if (success) {
                
                NSLog(@"successfully defantomize %@ %@", object[@"entityName"], object[@"id"]);
                
                [self fantomsCountDecrease];
                
            } else {
                
                [self defantomizingObject:object
                                    error:error.localizedDescription];
                
            }
            
        }
        
    }];
    
    
}


#pragma mark - unsynced subscription

- (void)subscribeToUnsyncedObjects {
    
    NSLogMethodName;

    self.dataSyncingDelegate.subscriberDelegate = self;
    
}

- (void)unsubscribeFromUnsyncedObjects {

    NSLogMethodName;

    self.dataSyncingDelegate.subscriberDelegate = nil;

}


#pragma mark - STMDataSyncingSubscriber

- (void)haveUnsyncedObjectWithEntityName:(NSString *)entityName itemData:(NSDictionary *)itemData itemVersion:(NSString *)itemVersion {
    
    self.isSendingData = YES;
    
    [self.socketTransport mergeAsync:entityName attributes:itemData options:nil completionHandlerWithHeaders:^(BOOL success, NSDictionary *result, NSDictionary *headers, NSError *error) {
        
        NSLog(@"synced entityName %@, item %@", entityName, itemData[@"id"]);
        
        if ([self.dataSyncingDelegate numberOfUnsyncedObjects] == 0) {
            self.isSendingData = NO;
        }
        
        if (error) {
            NSLog(@"updateResource error: %@", error.localizedDescription);
        }
        
        if (success) {
            [self bunchOfObjectsSended];
        }
        
        [self.dataSyncingDelegate setSynced:success
                                     entity:entityName
                                   itemData:result
                                itemVersion:itemVersion];
        
    }];

}

- (void)sendStarted {

    dispatch_async(dispatch_get_main_queue(), ^{
        
//        NSLog(@"NOTIFICATION_SYNCER_SEND_STARTED");
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SYNCER_SEND_STARTED
                                                            object:self];
        
    });

}

- (void)sendFinished {
    
    [self saveSendDate];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
//        NSLog(@"NOTIFICATION_SYNCER_SEND_FINISHED");
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SYNCER_SEND_FINISHED
                                                            object:self];
        
    });
    
}

- (void)saveSendDate {
    
    STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
    
    NSString *key = [@"sendDate" stringByAppendingString:self.session.uid];
    NSString *sendDateString = [[STMFunctions dateShortTimeShortFormatter] stringFromDate:[NSDate date]];
    
    [defaults setObject:sendDateString forKey:key];
    [defaults synchronize];
    
}

- (void)bunchOfObjectsSended {

    [self saveSendDate];
    [self postObjectsSendedNotification];

}

- (void)postObjectsSendedNotification {

    dispatch_async(dispatch_get_main_queue(), ^{

        //    NSLog(@"NOTIFICATION_SYNCER_BUNCH_OF_OBJECTS_SENDED");
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SYNCER_BUNCH_OF_OBJECTS_SENDED
                                                            object:self];

    });

}


@end
