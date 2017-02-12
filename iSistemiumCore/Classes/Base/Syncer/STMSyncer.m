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

#import "STMCoreObjectsController.h"
#import "STMEntityController.h"
#import "STMClientEntityController.h"
#import "STMClientDataController.h"
#import "STMCoreAuthController.h"

#import "STMSocketTransport+Persisting.h"


@interface STMSyncer()

@property (nonatomic, strong) STMDocument *document;
@property (nonatomic, strong) id <STMSocketConnection, STMPersistingWithHeadersAsync> socketTransport;

@property (nonatomic, strong) NSMutableDictionary *settings;
@property (nonatomic, strong) NSTimer *syncTimer;

@property (nonatomic, strong) NSString *entityResource;
@property (nonatomic, strong) NSString *socketUrlString;
@property (nonatomic) NSTimeInterval httpTimeoutForeground;
@property (nonatomic) NSTimeInterval httpTimeoutBackground;

@property (nonatomic) BOOL isRunning;
@property (nonatomic) BOOL isDefantomizing;
@property (nonatomic) BOOL isUsingNetwork;

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

- (BOOL)isReceivingData {
    return self.dataDownloadingDelegate.downloadingState.isInSyncingProcess;
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

        [self.socketTransport closeSocket];
        
        [self.session.logger saveLogMessageWithText:@"Syncer stop"];
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
    
    [self subscribeToUnsyncedObjects];

    [self initTimer];
    
}

- (void)socketLostConnection {

    NSLogMethodName;
    
    [self releaseTimer];
    
    [self unsubscribeFromUnsyncedObjects];
    
    if (self.isReceivingData) {
        [self.dataDownloadingDelegate stopDownloading:@"socketLostConnection"];
    }
    
    if (self.isDefantomizing) {
        [self.defantomizingDelegate stopDefantomization];
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
        
        [STMClientEntityController clientEntityWithName:stcEntityName
                                                setETag:nil];
        
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
        
        NSArray *localDataModelEntityNames = self.persistenceDelegate.concreteEntities.allKeys;
        NSMutableArray *existingNames = [@[] mutableCopy];
        
        for (NSString *entityName in entitiesNames) {
            
            NSString *name = [STMFunctions addPrefixToEntityName:entityName];
            
            if ([localDataModelEntityNames containsObject:name]) {
                [existingNames addObject:name];
            }
            
        }
        
        if (existingNames.count > 0) {
            
            self.dataDownloadingDelegate.receivingEntitiesNames = existingNames;
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

- (void)sendFindWithValue:(NSDictionary *)value {
    
    NSString *entityName = [STMFunctions addPrefixToEntityName:value[@"entity"]];
    NSString *identifier = value[@"id"];
    
    [self.socketTransport findAsync:entityName identifier:identifier options:nil completionHandlerWithHeaders:^(BOOL success, NSDictionary *result, NSDictionary *headers, NSError *error) {
        
        if (error) {
            NSLog(@"sendFindWithValue entityName %@ error: %@", entityName, error);
            return;
        }
        
        NSLog(@"sendFindWithValue success: %@ %@", entityName, identifier);
        
        NSDictionary *options = @{STMPersistingOptionLts:[STMFunctions stringFromNow]};
        
        [self.persistenceDelegate mergeAsync:entityName attributes:result options:options completionHandler:nil];
        
    }];

}

#pragma mark - defantomization

- (void)startDefantomization {
    
    if (!self.socketTransport.isReady) {
        
        [self.defantomizingDelegate stopDefantomization];
        return;
        
    }
    
    if (self.isDefantomizing) {
        return;
    }
    
    self.isDefantomizing = YES;
    
    [self.defantomizingDelegate startDefantomization];
    
}


#pragma mark STMDefantomizingOwner

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

        [self.defantomizingDelegate defantomize:fantomDic
                                        success:success
                                     entityName:entityName
                                         result:result
                                          error:error];
                
    }];

}

- (void)defantomizingFinished {
    self.isDefantomizing = NO;
}


#pragma mark - unsynced subscription

- (void)subscribeToUnsyncedObjects {
    
    NSLogMethodName;
    
    [self unsubscribeFromUnsyncedObjects];

    self.dataSyncingDelegate.subscriberDelegate = self;
    [self.dataSyncingDelegate startSyncing];
    
}

- (void)unsubscribeFromUnsyncedObjects {

    NSLogMethodName;

    self.dataSyncingDelegate.subscriberDelegate = nil;
    [self.dataSyncingDelegate pauseSyncing];

}


#pragma mark - recieve data

- (void)receiveData {
    [self.dataDownloadingDelegate startDownloading];
}


#pragma mark - STMDataDownloadingOwner

- (BOOL)downloadingTransportIsReady {
    return [self transportIsReady];
}

- (void)entitiesWasUpdated {
    
    [STMEntityController flushSelf];
    [self subscribeToUnsyncedObjects];

}

- (void)dataDownloadingFinished {
        
    [self turnOffNetworkActivityIndicator];

    [STMCoreObjectsController dataLoadingFinished];
    
    [self startDefantomization];

    if (self.fetchCompletionHandler) {
        
        self.fetchCompletionHandler(self.fetchResult);
        self.fetchCompletionHandler = nil;
        
    }

}

- (void)receiveData:(NSString *)entityName offset:(NSString *)offset pageSize:(NSUInteger)pageSize {
    
    __block BOOL blockIsComplete = NO;
    
    NSDictionary *options = @{STMPersistingOptionPageSize   : @(pageSize),
                              STMPersistingOptionOffset     : offset};
    
    [self.socketTransport findAllAsync:entityName predicate:nil options:options completionHandlerWithHeaders:^(BOOL success, NSArray *result, NSDictionary *headers, NSError *error) {
        
        if (blockIsComplete) {
            NSLog(@"completionHandler for %@ %@ already complete", entityName, offset);
            return;
        }
        
        blockIsComplete = YES;
        
        NSString *offset = headers[STMPersistingOptionOffset];
        NSUInteger pageSize = [headers[STMPersistingOptionPageSize] integerValue];

        [self.dataDownloadingDelegate dataReceivedSuccessfully:success
                                                    entityName:entityName
                                                        result:result
                                                        offset:offset
                                                      pageSize:pageSize
                                                         error:error];
        
    }];

}


#pragma mark - STMDataSyncingSubscriber

- (void)haveUnsynced:(NSString *)entityName itemData:(NSDictionary *)itemData itemVersion:(NSString *)itemVersion {
    
    self.isSendingData = YES;
    
    [self.socketTransport mergeAsync:entityName attributes:itemData options:nil completionHandlerWithHeaders:^(BOOL success, NSDictionary *result, NSDictionary *headers, NSError *error) {
        
//        NSLog(@"synced entityName %@, item %@", entityName, itemData[@"id"]);
        
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
                                   itemData:success ? result : itemData
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
