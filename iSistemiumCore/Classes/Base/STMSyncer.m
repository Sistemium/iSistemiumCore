//
//  STMSyncer.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 06/06/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import <AdSupport/AdSupport.h>

// new

#import "STMSyncer.h"
#import "STMDocument.h"

#import "STMSocketTransport.h"
#import "STMDataSyncing.h"
#import "STMSyncerHelper.h"

#import "STMCoreObjectsController.h"
#import "STMEntityController.h"
#import "STMClientEntityController.h"
#import "STMClientDataController.h"
#import "STMCoreAuthController.h"


//old

#import "STMFunctions.h"
#import "STMCorePicturesController.h"

#import "STMCoreDataModel.h"

#import "STMSocketController.h"

#define SEND_DATA_CONNECTION @"SEND_DATA"


@interface STMSyncer()


// new

@property (nonatomic, strong) STMDocument *document;
@property (nonatomic, weak) id <STMPersistingPromised,STMPersistingAsync,STMPersistingSync>persistenceDelegate;
@property (nonatomic, strong) STMSocketTransport *socketTransport;
@property (nonatomic, strong) id <STMDataSyncing>dataSyncingDelegate;
@property (nonatomic, strong) STMSyncerHelper *syncerHelper;

@property (nonatomic, strong) NSMutableDictionary *settings;
@property (nonatomic) NSInteger fetchLimit;
@property (nonatomic, strong) NSTimer *syncTimer;

@property (nonatomic, strong) NSString *entityResource;
@property (nonatomic, strong) NSString *socketUrlString;

@property (nonatomic) BOOL isRunning;
@property (nonatomic) BOOL isReceivingData;
@property (nonatomic) BOOL isDefantomizing;
@property (nonatomic) BOOL isUsingNetwork;

@property (nonatomic, strong) NSArray *receivingEntitiesNames;
@property (nonatomic, strong) NSMutableArray *entitySyncNames;

@property (nonatomic) NSUInteger entityCount;
@property (atomic) NSUInteger fantomsCount;

@property (nonatomic, strong) NSString *subscriptionId;
@property (nonatomic, strong) void (^unsyncedSubscriptionHandler)(NSString *entityName, NSDictionary *itemData, NSString *itemVersion);

// old

@property (nonatomic, strong) NSString *xmlNamespace;
@property (nonatomic) NSTimeInterval httpTimeoutForeground;
@property (nonatomic) NSTimeInterval httpTimeoutBackground;
@property (nonatomic, strong) NSString *uploadLogType;

@property (nonatomic) BOOL timerTicked;

@property (nonatomic) BOOL syncing;
@property (nonatomic) BOOL checkSending;
@property (nonatomic) BOOL sendOnce;
@property (nonatomic) BOOL fullSyncWasDone;
@property (nonatomic) BOOL isFirstSyncCycleIteration;
@property (nonatomic) BOOL errorOccured;

@property (nonatomic, strong) NSMutableDictionary *responses;
@property (nonatomic, strong) NSMutableDictionary *temporaryETag;
@property (nonatomic, strong) NSMutableArray *sendedEntities;


@property (nonatomic, strong) void (^fetchCompletionHandler) (UIBackgroundFetchResult result);

@property (nonatomic) UIBackgroundFetchResult fetchResult;

- (void)didReceiveRemoteNotification;


@end


@implementation STMSyncer

@synthesize syncInterval = _syncInterval;
@synthesize syncerState = _syncerState;


#pragma mark - NEW IMPLEMENTATION
#pragma mark

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

- (void)setSession:(id <STMSession>)session {
    
    if (session != _session) {
        
        self.document = (STMDocument *)session.document;
        self.persistenceDelegate = session.persistenceDelegate;
        
        self.syncerHelper = [[STMSyncerHelper alloc] init];
        self.syncerHelper.persistenceDelegate = session.persistenceDelegate;
        
        self.dataSyncingDelegate = self.syncerHelper;

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
        } else {
            [self turnOffNetworkActivityIndicator];
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

- (void)turnOffNetworkActivityIndicator {
    
    if (!self.isUsingNetwork) {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    }

}

- (BOOL)isUsingNetwork {
    return self.isReceivingData || self.isDefantomizing;
}

- (NSTimeInterval)timeout {
    return ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) ? self.httpTimeoutBackground : self.httpTimeoutForeground;
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
                
                [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SYNCER_INIT_SUCCESSFULLY
                                                                    object:self];
                
                if (self.socketUrlString) {
                    
                    self.socketTransport = [STMSocketTransport initWithUrl:self.socketUrlString
                                                         andEntityResource:self.entityResource
                                                                 forSyncer:self];
                    
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

- (void)socketReceiveAuthorization {
    
    NSLogMethodName;
    
    [self initTimer];
    
    self.subscriptionId = [self.dataSyncingDelegate subscribeUnsyncedWithCompletionHandler:self.unsyncedSubscriptionHandler];
    
}

- (void)socketLostConnection {

    NSLogMethodName;
    
    [self releaseTimer];
    
    if ([self.dataSyncingDelegate unSubscribe:self.subscriptionId]) {
        
        NSLog(@"successfully unsubscribed subscriptionId: %@", self.subscriptionId);
        self.subscriptionId = nil;
        
    } else {
        NSLog(@"ERROR! can not unsubscribe subscriptionId: %@", self.subscriptionId);
    }

}

- (void)checkStcEntitiesWithCompletionHandler:(void (^)(BOOL success))completionHandler {
    
    NSDictionary *stcEntities = [STMEntityController stcEntities];
    
    NSString *stcEntityName = NSStringFromClass([STMEntity class]);
    
    if (!stcEntities[stcEntityName]) {
        
        STMEntity *entity = (STMEntity *)[STMCoreObjectsController newObjectForEntityName:stcEntityName isFantom:NO];
        
        if ([stcEntityName hasPrefix:ISISTEMIUM_PREFIX]) {
            stcEntityName = [stcEntityName substringFromIndex:[ISISTEMIUM_PREFIX length]];
        }
        
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
        
        if ([stcEntityName hasPrefix:ISISTEMIUM_PREFIX]) {
            stcEntityName = [stcEntityName substringFromIndex:[ISISTEMIUM_PREFIX length]];
        }
        
        STMClientEntity *clientEntity = [STMClientEntityController clientEntityWithName:stcEntityName];
        clientEntity.eTag = nil;
        
    }
    
}


#pragma mark - stop syncer methods

- (void)stopSyncer {
    
    if (self.isRunning) {
        
        [STMSocketController closeSocket];
        
        [self.session.logger saveLogMessageWithText:@"Syncer stop"];
        self.syncing = NO;
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
    self.xmlNamespace = nil;
    self.httpTimeoutForeground = 0;
    self.httpTimeoutBackground = 0;
    self.syncInterval = 0;
    self.uploadLogType = nil;

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

- (void)checkConditionForReceivingEntityWithName:(NSString *)entityName {
    
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
            
            NSString *resource = entity.url;
            
            if (resource) {
                
                STMClientEntity *clientEntity = [STMClientEntityController clientEntityWithName:entity.name];
                
                NSString *eTag = clientEntity.eTag;
                eTag = eTag ? eTag : @"*";
                
                __block BOOL blockIsComplete = NO;
                
                [self.socketTransport findAllFromResource:resource
                                                 withETag:eTag
                                               fetchLimit:self.fetchLimit
                                                  timeout:[self timeout]
                                                   params:nil
                                        completionHandler:^(BOOL success, NSArray *data, NSError *error) {
                                             
                                            if (blockIsComplete) {
                                                NSLog(@"completionHandler for %@ already complete", entityName);
                                                return;
                                            }

                                            blockIsComplete = YES;
                                             
                                            if (success) {

                                                [self socketReceiveJSDataAck:data];
                                                 
                                            } else {
                                                 
                                                if (self.entityCount > 0) {
                                                    [self entityCountDecreaseWithError:error.localizedDescription];
                                                } else {
                                                    [self receivingDidFinishWithError:error.localizedDescription];
                                                }
                                                 
                                            }
                                             
                                        }];
                
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

- (void)entityCountDecrease {
    [self entityCountDecreaseWithError:nil];
}

- (void)entityCountDecreaseWithError:(NSString *)errorMessage {
    
    if (errorMessage) {
        
        NSString *logMessage = [NSString stringWithFormat:@"entityCountDecreaseWithError: %@", errorMessage];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                 numType:STMLogMessageTypeError];
        
    }
    
    if (--self.entityCount) {
        
        if (self.entitySyncNames.firstObject) [self.entitySyncNames removeObject:(id _Nonnull)self.entitySyncNames.firstObject];
        
        if (self.entitySyncNames.firstObject) {
            
            [self.document saveDocument:^(BOOL success) {}];
            
            [self checkConditionForReceivingEntityWithName:self.entitySyncNames.firstObject];
            
        } else {
            
            [self receivingDidFinish];
            
        }
        
    } else {
        
        [self receivingDidFinish];
        
    }

}

- (void)receiveNoContentStatusForEntityWithName:(NSString *)entityName {
    
    if ([entityName isEqualToString:@"STMEntity"]) {
        
        [STMEntityController flushSelf];
        [STMSocketController reloadResultsControllers];
        
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
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"entitiesReceivingDidFinish"
                                                            object:self];
        
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
    
    self.isReceivingData = NO;
    
    if (errorString) {
        
        NSString *logMessage = [NSString stringWithFormat:@"receivingDidFinishWithError: %@", errorString];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                 numType:STMLogMessageTypeError];
        
    } else {
        
#warning - do it only if have no error or always?
        [self saveReceiveDate];
        [STMCoreObjectsController dataLoadingFinished];
        [self startDefantomization];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_PERSISTER_HAVE_UNSYNCED
                                                            object:self];
        
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
            
            self.isDefantomizing = NO;
            [self.syncerHelper defantomizingFinished];
            
        }
        
    }];
    
}

- (void)defantomizeObject:(NSDictionary *)fantomDic {
    
    NSString *entityName = fantomDic[@"entityName"];
    NSString *fantomId = fantomDic[@"id"];
    
    if (![entityName hasPrefix:ISISTEMIUM_PREFIX]) {
        entityName = [ISISTEMIUM_PREFIX stringByAppendingString:entityName];
    }
    
    STMEntity *entity = [STMEntityController stcEntities][entityName];
    
    if (!entity.url) {
        
        NSString *errorMessage = [NSString stringWithFormat:@"no url for entity %@", entityName];
        [self defantomizingObject:fantomDic
                            error:errorMessage];
        
        return;
        
    }
    
    if (!fantomId) {
        
        NSString *errorMessage = [NSString stringWithFormat:@"no xid in request parameters %@", fantomDic];
        [self defantomizingObject:fantomDic
                            error:errorMessage];
        
        return;
        
    }
    
    NSString *resource = entity.url;
//    NSString *resource = [entity resource]; ???
    
    __block BOOL blockIsComplete = NO;
    
    [self.socketTransport findFromResource:resource
                                  objectId:fantomId
                                   timeout:[self timeout]
                         completionHandler:^(BOOL success, NSArray *data, NSError *error) {
                             
                             if (blockIsComplete) {
                                 NSLog(@"completionHandler for %@ already complete", entityName);
                                 return;
                             }
                             
                             blockIsComplete = YES;
                             
                             if (success) {
                                 
                                 NSDictionary *context = @{@"type"  : DEFANTOMIZING_CONTEXT,
                                                           @"object": fantomDic};
                                 
                                 [self socketReceiveJSDataAck:data
                                                      context:context];
                                 
                             } else {
                                 
                                 [self defantomizingObject:fantomDic
                                                     error:error.localizedDescription];
                                 
                             }
                             
                         }];

}

- (void)defantomizingObject:(NSDictionary *)fantomDic error:(NSString *)errorString {
    
    NSLog(@"defantomize error: %@", errorString);
    
    [self.syncerHelper defantomizeErrorWithObject:fantomDic];
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


#pragma mark - socket ack handlers

- (void)socketReceiveJSDataAck:(NSArray *)data {
    [self socketReceiveJSDataAck:data context:nil];
}

- (void)socketReceiveJSDataAck:(NSArray *)data context:(NSDictionary *)context {
    
    NSDictionary *response = ([data.firstObject isKindOfClass:[NSDictionary class]]) ? data.firstObject : nil;
    
    if (!response) {
        
        // don't know which method cause an error, send error to all of them
        NSString *errorMessage = @"ERROR: response contain no dictionary";
        [self socketReceiveJSDataFindAllAckError:errorMessage];
        
        [self socketReceiveJSDataFindAckWithErrorCode:nil
                                   errorString:errorMessage
                                          context:context];
        
        [self socketReceiveJSDataUpdateAckErrorCode:nil
                                     andErrorString:errorMessage
                                       withResponse:nil];
        return;
        
    }
    
    NSString *resource = response[@"resource"];
    NSString *entityName = [STMEntityController entityNameForURLString:resource];
    NSNumber *errorCode = response[@"error"];
    NSString *methodName = response[@"method"];
    
    if ([methodName isEqualToString:kSocketFindAllMethod]) {
        
        [self receiveFindAllAck:data
                   withResponse:response
                       resource:resource
                     entityName:entityName
                      errorCode:errorCode];
        
    } else if ([methodName isEqualToString:kSocketFindMethod]) {
        
        [self receiveFindAck:data
                withResponse:response
                    resource:resource
                  entityName:entityName
                   errorCode:errorCode
                     context:context];
        
    } else if ([methodName isEqualToString:kSocketUpdateMethod]) {
        
        [self receiveUpdateAck:data
                  withResponse:response
                      resource:resource
                    entityName:entityName
                     errorCode:errorCode];
        
    }
    
}


#pragma mark findAll ack handler

- (void)receiveFindAllAck:(NSArray *)data withResponse:(NSDictionary *)response resource:(NSString *)resource entityName:(NSString *)entityName errorCode:(NSNumber *)errorCode {
    
    if (errorCode) {
        [self socketReceiveJSDataFindAllAckError:[NSString stringWithFormat:@"    %@: ERROR: %@", entityName, errorCode]]; return;
    }
    
    if (!resource) {
        [self socketReceiveJSDataFindAllAckError:@"ERROR: have no resource string in response"]; return;
    }
    
    NSArray *responseData = ([response[@"data"] isKindOfClass:[NSArray class]]) ? response[@"data"] : nil;
    
    if (!responseData) {
        [self socketReceiveJSDataFindAllAckError:[NSString stringWithFormat:@"    %@: ERROR: find all response data is not an array", entityName]]; return;
    }
    
    [self parseFindAllAckData:data
                 responseData:responseData
                     resource:resource
                   entityName:entityName
                     response:response];
    
}

- (void)socketReceiveJSDataFindAllAckError:(NSString *)errorString {
    
    [STMSocketController sendEvent:STMSocketEventInfo withValue:errorString];
    [self entityCountDecreaseWithError:errorString];
    
}

- (void)parseFindAllAckData:(NSArray *)data responseData:(NSArray *)responseData resource:(NSString *)resource entityName:(NSString *)entityName response:(NSDictionary *)response {
    
    if (entityName) {
        
        if (responseData.count > 0) {
            
            NSString *offset = response[@"offset"];
            NSUInteger pageSize = [response[@"pageSize"] integerValue];
            
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
        
        NSString *logMessage = [NSString stringWithFormat:@"ERROR: unknown entity response: %@", data];
        [[STMLogger sharedLogger] saveLogMessageWithText:logMessage
                                                 numType:STMLogMessageTypeError];
        
    }
    
}

- (void)parseSocketFindAllResponseData:(NSArray *)data forEntityName:(NSString *)entityName isLastPage:(BOOL)isLastPage {
    
    STMEntity *entity = self.stcEntities[entityName];
    
    if (entity) {
        
        NSMutableDictionary *options = @{@"lts": [STMFunctions stringFromNow]}.mutableCopy;

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
        
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SYNCER_GET_BUNCH_OF_OBJECTS
                                                            object:self
                                                          userInfo:@{@"count"         :@(result.count),
                                                                     @"entityName"    :entityName}];
        
    }];

}

- (void)findAllResultMergedWithError:(NSString *)errorString {
    [self entityCountDecreaseWithError:errorString];
}


#pragma mark find ack handler

- (void)receiveFindAck:(NSArray *)data withResponse:(NSDictionary *)response resource:(NSString *)resource entityName:(NSString *)entityName errorCode:(NSNumber *)errorCode context:(NSDictionary *)context {
    
    NSData *xid = [STMFunctions xidDataFromXidString:response[@"id"]];
    
    if (errorCode) {
        
        [self socketReceiveJSDataFindAckWithErrorCode:errorCode
                                          errorString:[NSString stringWithFormat:@"    %@ %@: ERROR: %@", entityName, xid, errorCode]
                                              context:context];
        
        return;
        
    }
    
    if (!resource) {
        
        [self socketReceiveJSDataFindAckWithErrorCode:errorCode
                                          errorString:@"ERROR: have no resource string in response"
                                              context:context];
        return;
        
    }
    
    NSDictionary *responseData = ([response[@"data"] isKindOfClass:[NSDictionary class]]) ? response[@"data"] : nil;
    
    if (!responseData) {
        
        NSString *errorString = [NSString stringWithFormat:@"    %@: ERROR: find response data is not a dictionary", resource];
        [self socketReceiveJSDataFindAckWithErrorCode:errorCode
                                          errorString:errorString
                                              context:context];
        return;
        
    }
    
    xid = [STMFunctions xidDataFromXidString:responseData[@"id"]];
    
    [self parseFindAckResponseData:responseData
                    withEntityName:entityName
                               xid:xid
                           context:context];
    
}

- (void)socketReceiveJSDataFindAckWithErrorCode:(NSNumber *)errorCode errorString:(NSString *)errorString context:(NSDictionary *)context {

    if (errorCode.integerValue > 499 && errorCode.integerValue < 600) {
        
    }

    BOOL defantomizing = [context[@"type"] isEqualToString:DEFANTOMIZING_CONTEXT];
    
    if (defantomizing) {
        
        [self defantomizingObject:context[@"object"]
                            error:errorString];
        
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
    
    NSDictionary *options = @{@"lts": [STMFunctions stringFromNow]};
    
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

- (void (^)(NSString *entityName, NSDictionary *itemData, NSString *itemVersion))unsyncedSubscriptionHandler {
    
    if (!_unsyncedSubscriptionHandler) {
        
        __weak STMSyncer *weakSelf = self;
        
        _unsyncedSubscriptionHandler = ^(NSString *entityName, NSDictionary *itemData, NSString *itemVersion) {
            
            STMEntity *entity = [STMEntityController stcEntities][entityName];
            NSString *resource = entity.url;
//            NSString *resource = [entity resource]; ???

            if (!resource) {
                
                NSString *errorMessage = [NSString stringWithFormat:@"no url for entity %@", entityName];
                NSLog(@"%@", errorMessage);

                [weakSelf.dataSyncingDelegate setSynced:NO
                                                 entity:entityName
                                               itemData:itemData
                                            itemVersion:itemVersion];

                return;
                
            }
            

            [weakSelf.socketTransport updateResource:resource
                                              object:itemData
                                             timeout:[weakSelf timeout]
                                   completionHandler:^(BOOL success, NSArray *data, NSError *error) {
            
                NSLog(@"entityName %@, item %@", entityName, itemData[@"id"]);
            
                if (error) {
                    NSLog(@"updateResource error: %@", error.localizedDescription);
                }
                                       
                [weakSelf.dataSyncingDelegate setSynced:success
                                                 entity:entityName
                                               itemData:itemData
                                            itemVersion:itemVersion];
                
            }];
            
        };
        
    }
    return _unsyncedSubscriptionHandler;
    
}



// ----------------------
// | OLD IMPLEMENTATION |
// ----------------------



#pragma mark - OLD IMPLEMENTATION

//- (void)socketReceiveTimeout {
//
//    (self.entityCount > 0) ? [self entityCountDecrease] : [self receivingDidFinishWithError:@"socket receive objects timeout"];
////    [STMCoreObjectsController stopDefantomizing];
//
//}

#pragma mark - variables setters & getters

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

- (NSString *)xmlNamespace {
    if (!_xmlNamespace) {
        _xmlNamespace = self.settings[@"xmlNamespace"];
    }
    return _xmlNamespace;
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

- (NSString *)uploadLogType {
    if (!_uploadLogType) {
        _uploadLogType = self.settings[@"uploadLog.type"];
    }
    return _uploadLogType;
}

- (NSMutableArray *)sendedEntities {
    
    if (!_sendedEntities) {
        _sendedEntities = [NSMutableArray array];
    }
    return _sendedEntities;
    
}

- (STMSyncerState)syncerState {
    
    if (!_syncerState) {
        _syncerState = STMSyncerIdle;
    }
    
    return _syncerState;
    
}

- (void)setSyncerState:(STMSyncerState) syncerState fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result)) handler {
    
    self.fetchCompletionHandler = handler;
    self.fetchResult = UIBackgroundFetchResultNewData;
    self.syncerState = syncerState;
    
}


- (void)setSyncerState:(STMSyncerState)syncerState {
    
    if (self.isRunning && !self.syncing && syncerState != _syncerState) {

        STMSyncerState previousState = _syncerState;
        
        _syncerState = syncerState;
        
        NSArray *syncStates = @[@"idle", @"sendData", @"sendDataOnce", @"receiveData"];
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SYNCER_STATUS_CHANGED
                                                            object:self
                                                          userInfo:@{@"from":@(previousState), @"to":@(syncerState)}];
        
        NSString *logMessage = [NSString stringWithFormat:@"Syncer %@", syncStates[syncerState]];
        NSLog(@"%@", logMessage);

        switch (_syncerState) {
            case STMSyncerIdle: {
                
                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                self.syncing = NO;
                self.sendOnce = NO;
                self.checkSending = NO;
                
                self.entitySyncNames = nil;
                if (self.receivingEntitiesNames) self.receivingEntitiesNames = nil;
                if (self.fetchCompletionHandler) self.fetchCompletionHandler(self.fetchResult);
                self.fetchCompletionHandler = nil;

                break;
            }
            case STMSyncerSendData:
            case STMSyncerSendDataOnce: {
                
                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
                [STMClientDataController checkClientData];
                self.syncing = YES;

//                [STMSocketController sendUnsyncedObjects:self withTimeout:[self timeout]];
                self.syncerState = STMSyncerIdle;
                
                break;
            }
            case STMSyncerReceiveData: {
                
                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
                self.syncing = YES;
//                [self checkNews];
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

- (void)sendingRoute {

    if ([STMSocketController socketIsAvailable]) {
        
        [STMSocketController sendUnsyncedObjects:self withTimeout:[self timeout]];
        
    } else {

    }

}

- (void)setEntityCount:(NSUInteger)entityCount {
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"entityCountdownChange"
                                                        object:self
                                                      userInfo:@{@"countdownValue": @((int)entityCount)}];
    
    _entityCount = entityCount;
    
}

- (NSMutableDictionary *)responses {
    
    if (!_responses) {
        _responses = [NSMutableDictionary dictionary];
    }
    return _responses;
    
}

- (NSMutableDictionary *)temporaryETag {
    
    if (!_temporaryETag) {
        _temporaryETag = [NSMutableDictionary dictionary];
    }
    return _temporaryETag;
    
}


#pragma mark - syncer methods

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
            
            NSString *name = ([entityName hasPrefix:ISISTEMIUM_PREFIX]) ? entityName : [ISISTEMIUM_PREFIX stringByAppendingString:entityName];
            
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

- (void)sendObjects:(NSDictionary *)parameters {
    
    NSError *error;
    NSArray *jsonArray = [STMCoreObjectsController jsonForObjectsWithParameters:parameters error:&error];
    
    if (error) {
        
        [[STMLogger sharedLogger] saveLogMessageWithText:error.localizedDescription type:@"error"];
        
    } else {
        
        if (jsonArray) {

            NSData *JSONData = [NSJSONSerialization dataWithJSONObject:@{@"data": jsonArray}
                                                               options:0
                                                                 error:nil];
//            [self startConnectionForSendData:JSONData];
            
#warning should send it via socket
            
        }
        
    }
    
}

- (void)didReceiveRemoteNotification {
    [self upload];
}

- (void)syncerDidReceiveRemoteNotification:(NSNotification *)notification {
    
    if ([(notification.userInfo)[@"syncer"] isEqualToString:@"upload"]) {
        [self setSyncerState:STMSyncerSendDataOnce];
    }
    
}



#pragma mark - syncing
#pragma mark - send

- (void)nothingToSend {
    
    [self.session.logger saveLogMessageWithText:@"Syncer nothing to send"];

    self.syncing = NO;
    
    if (self.timerTicked) {
        
        self.timerTicked = NO;
        self.receivingEntitiesNames = nil;
        self.syncerState = STMSyncerReceiveData;
        
    } else {
        
        if (self.syncerState == STMSyncerSendData) {
            
            self.receivingEntitiesNames = nil;
            self.syncerState = STMSyncerReceiveData;
            
        } else {
            
            if (self.receivingEntitiesNames) {
                
                self.syncerState = STMSyncerReceiveData;
                
            } else {
                
                self.syncerState = STMSyncerIdle;
//                [STMCoreObjectsController resolveFantoms];
                
            }
            
        }
    
    }
    
}

- (NSArray *)unsyncedObjects {
    return [STMSocketController unsyncedObjects];
}

- (NSUInteger)numbersOfAllUnsyncedObjects {
    return [self unsyncedObjects].count;
}

- (NSUInteger)numberOfCurrentlyUnsyncedObjects {
    return [STMSocketController numberOfCurrentlyUnsyncedObjects];
}

#pragma mark - receive

- (void)checkNews {
    
    [self receiveData]; return; // check news is temporary disabled

    if (self.fullSyncWasDone && !self.receivingEntitiesNames) {
        
        self.errorOccured = NO;
        
        [STMSocketController checkNewsWithFetchLimit:self.fetchLimit andTimeout:[self timeout]];
        
#warning do not forget to check self.fetchResult usage
        
//            if (!connectionError) {
//                
//                NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
//                
//                NSInteger statusCode = httpResponse.statusCode;
//                NSString *stringForStatusCode = [NSHTTPURLResponse localizedStringForStatusCode:statusCode];
//                
//                switch (statusCode) {
//                        
//                    case 200:
//                        self.fetchResult = UIBackgroundFetchResultNewData;
//                        [self parseNewsData:data];
//                        break;
//                        
//                    case 204:
//                        NSLog(@"    news: 204 %@", stringForStatusCode);
//                        self.fetchResult = UIBackgroundFetchResultNoData;
//                        [self receivingDidFinish];
//                        break;
//                        
//                    default:
//                        NSLog(@"    news statusCode: %d %@", statusCode, stringForStatusCode);
//                        self.fetchResult = UIBackgroundFetchResultFailed;
//                        [self receivingDidFinish];
//                        break;
//                        
//                }
//                
//            } else {
//                
//                NSLog(@"connectionError %@", connectionError.localizedDescription);
//                self.errorOccured = YES;
//                self.fetchResult = UIBackgroundFetchResultFailed;
//
//                [self receivingDidFinish];
//                
//            }
        
    } else {
        
        [self receiveData];
        
    }
    
    
}

- (void)notAuthorized {
    
    self.fetchResult = UIBackgroundFetchResultFailed;
    [self stopSyncer];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"notAuthorized" object:self];
    
}


#pragma mark - socket receive ack handler

- (void)receiveUpdateAck:(NSArray *)data withResponse:(NSDictionary *)response resource:(NSString *)resource entityName:(NSString *)entityName errorCode:(NSNumber *)errorCode {
    
    NSDictionary *responseData = ([response[@"data"] isKindOfClass:[NSDictionary class]]) ? response[@"data"] : nil;
    
    if (errorCode) {
        
        NSString *errorString = [NSString stringWithFormat:@"    %@: ERROR: %@", resource, errorCode];
        [self socketReceiveJSDataUpdateAckErrorCode:errorCode andErrorString:errorString withResponse:response]; return;
        
    }

    if (!responseData) {
        
        NSString *errorString = [NSString stringWithFormat:@"    %@: ERROR: update response data is not a dictionary", resource];
        [self socketReceiveJSDataUpdateAckErrorCode:nil andErrorString:errorString withResponse:response]; return;
        
    }
    
    [self parseUpdateAckResponseData:responseData];

}

- (void)socketReceiveJSDataUpdateAckErrorCode:(NSNumber *)errorCode andErrorString:(NSString *)errorString withResponse:(NSDictionary *)response {
    
    NSLog(@"%@", errorString);
    [STMSocketController sendEvent:STMSocketEventInfo withValue:errorString];

    NSString *xid = [response valueForKey:@"id"];
    NSData *xidData = [STMFunctions xidDataFromXidString:xid];

    BOOL abortSync = (errorCode.integerValue <= 399 || errorCode.integerValue >= 500);
    
    [STMSocketController unsuccessfullySyncObjectWithXid:xidData
                                             errorString:errorString
                                               abortSync:abortSync];
    
}

- (void)parseNewsData:(NSArray *)newsData {
    
    if (newsData.count > 0) {
        
        NSArray *entitiesNames = [newsData valueForKeyPath:@"@unionOfObjects.name"];
        NSArray *objectsCount = [newsData valueForKeyPath:@"@unionOfObjects.cnt"];
        
        NSDictionary *news = [NSDictionary dictionaryWithObjects:objectsCount forKeys:entitiesNames];
        
        for (NSString *entityName in entitiesNames) {
            NSLog(@"    news: STM%@ — %@ objects", entityName, news[entityName]);
        }
        
        NSMutableArray *tempArray = [NSMutableArray array];
        
        for (NSString *entityName in entitiesNames) {
            [tempArray addObject:[ISISTEMIUM_PREFIX stringByAppendingString:entityName]];
        }
        
        self.entitySyncNames = tempArray;
        self.entityCount = tempArray.count;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"syncerNewsHaveObjects"
                                                            object:self
                                                          userInfo:@{@"totalNumberOfObjects": [objectsCount valueForKeyPath:@"@sum.integerValue"]}];
        
        [self checkConditionForReceivingEntityWithName:self.entitySyncNames.firstObject];

    } else {
        
        NSLog(@"empty news data received");
        [self receivingDidFinish];
        
    }
    
}

- (void)parseUpdateAckResponseData:(NSDictionary *)responseData {

//    NSLog(@"update responseData %@", responseData);
    [self syncObject:responseData];
    
}


#pragma mark - sync object

- (void)syncObject:(NSDictionary *)objectDictionary {
    
    STMLogger *logger = [STMLogger sharedLogger];
    
    NSString *xid = [objectDictionary valueForKey:@"id"];
    NSData *xidData = [STMFunctions xidDataFromXidString:xid];
    
    NSDate *syncDate = [STMSocketController syncDateForSyncedObjectXid:xidData];

    if (!syncDate) {

        NSString *logMessage = [NSString stringWithFormat:@"Sync: object with xid %@ have no syncDate", xid];
        [logger saveLogMessageWithText:logMessage];
        
        return;
        
    }
    
    NSManagedObject *syncedObject = [STMCoreObjectsController objectForXid:xidData];
    
    if (!syncedObject) {
        
        NSString *logMessage = [NSString stringWithFormat:@"Sync: no object with xid: %@", xid];
        [logger saveLogMessageWithText:logMessage];
        
        return;

    }
    
    if (![syncedObject isKindOfClass:[STMDatum class]]) {
        
        NSString *logMessage = [NSString stringWithFormat:@"Sync: syncedObject %@ is not STMDatum class", xid];
        [logger saveLogMessageWithText:logMessage];
        
        return;
        
    }

    STMDatum *object = (STMDatum *)syncedObject;
    
    [object.managedObjectContext performBlockAndWait:^{
        
        if ([object isKindOfClass:[STMRecordStatus class]] && [[(STMRecordStatus *)object valueForKey:@"isRemoved"] boolValue]) {
            [STMCoreObjectsController removeObject:object];
        } else {
            object.lts = syncDate;
        }
        
        [STMSocketController successfullySyncObjectWithXid:xidData];
        
        NSString *entityName = object.entity.name;
        
        NSString *logMessage = [NSString stringWithFormat:@"successefully sync %@ with xid %@", entityName, xid];
        [logger saveLogMessageWithText:logMessage];
        
    }];

}


#pragma mark - some sync methods

- (void)sendFinishedWithError:(NSString *)errorString {
    
    if (errorString) {
        
        [[STMLogger sharedLogger] saveLogMessageWithText:errorString
                                                 numType:STMLogMessageTypeImportant];
        
        self.syncing = NO;
        if (self.fetchCompletionHandler) self.fetchResult = UIBackgroundFetchResultFailed;
        self.syncerState = (self.receivingEntitiesNames) ? STMSyncerReceiveData : STMSyncerIdle;
        
    } else {
        
        [self sendFinished:self];
        
    }
    
}

- (void)sendFinished:(id)sender {
    
    [self.document saveDocument:^(BOOL success) {
        
        [self saveSendDate];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"sendFinished" object:self];
        
        [self nothingToSend];
        
    }];

}

- (void)bunchOfObjectsSended {
    
    [self saveSendDate];
    [self postObjectsSendedNotification];
    
}

- (void)postObjectsSendedNotification {
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SYNCER_BUNCH_OF_OBJECTS_SENDED
                                                        object:self];

}

- (void)saveSendDate {
    
    STMUserDefaults *defaults = [STMUserDefaults standardUserDefaults];
    
    NSString *key = [@"sendDate" stringByAppendingString:self.session.uid];
    NSString *sendDateString = [[STMFunctions dateShortTimeShortFormatter] stringFromDate:[NSDate date]];
    
    [defaults setObject:sendDateString forKey:key];
    [defaults synchronize];
    
}

//- (void)socketLostConnection {
//    
//    self.syncing = NO;
//    self.syncerState = STMSyncerIdle;
//
//}


@end
