//
//  STMSyncer.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 06/06/14.
//  Copyright (c) 2014 Sistemium UAB. All rights reserved.
//

#import "STMSyncer.h"

#import "STMCoreAppDelegate.h"

#import "STMEntityController.h"
#import "STMClientEntityController.h"
#import "STMClientDataController.h"

#import "STMSyncer+RemoteData.h"
#import "STMSocketTransport+Persisting.h"


@interface STMSyncer ()

@property (nonatomic, strong) NSDictionary *settings;
@property (nonatomic, strong) NSTimer *syncTimer;

@property (nonatomic, strong) NSString *entityResource;
@property (nonatomic) NSTimeInterval httpTimeoutForeground;
@property (nonatomic) NSTimeInterval httpTimeoutBackground;

@property (nonatomic) BOOL isRunning;
@property (nonatomic) BOOL isDefantomizing;
@property (nonatomic) BOOL isUsingNetwork;
@property (nonatomic) BOOL haveToCloseSocketAfterFetch;

@property (nonatomic) BOOL needRepeatDownload;

@end


@implementation STMSyncer

@synthesize syncInterval = _syncInterval;


#pragma mark - observers

- (void)addObservers {

    [self observeNotification:@"syncerSettingsChanged"
                     selector:@selector(syncerSettingsChanged)
                       object:self.session];

    [self observeNotification:UIApplicationDidBecomeActiveNotification
                     selector:@selector(appDidBecomeActive)];

    [self observeNotification:UIApplicationDidEnterBackgroundNotification
                     selector:@selector(appDidEnterBackground)];

}

- (void)removeObservers {
    [self unsubscribeFromUnsyncedObjects];
    [super removeObservers];
}


- (void)syncerSettingsChanged {
    [self flushSettings];
}

- (void)appDidBecomeActive {
    [self sendData];
}

- (void)appDidEnterBackground {
    [self sendData];
}


#pragma mark - variables setters & getters

- (void)setSession:(id <STMSession>)session {

    [super setSession:session];

    if (session) [self startSyncer];

}

- (NSDictionary *)settings {

    if (!_settings) {
        _settings = [[(id <STMSession>) self.session settingsController] currentSettingsForGroup:@"syncer"];
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
    return !!self.dataDownloadingDelegate.downloadingState;
}

- (void)setIsDefantomizing:(BOOL)isDefantomizing {

    if (_isDefantomizing != isDefantomizing) {

        _isDefantomizing = isDefantomizing;

        if (isDefantomizing) {
            [STMFunctions setNetworkActivityIndicatorVisible:YES];
        } else {
            [self turnOffNetworkActivityIndicator];
        }

    }

}

- (void)setIsSendingData:(BOOL)isSendingData {

    if (_isSendingData != isSendingData) {

        _isSendingData = isSendingData;

        if (isSendingData) {

            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [STMFunctions setNetworkActivityIndicatorVisible:YES];
                [self sendStarted];
            }];

        } else {

            [self turnOffNetworkActivityIndicator];
            [self sendFinished];

        }

    }
}

- (void)turnOffNetworkActivityIndicator {

    if (!self.isUsingNetwork) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            STMFunctions.networkActivityIndicatorVisible = NO;
            [self checkSyncerState];
        }];
    }

}

- (void)checkSyncerState {

    if (self.haveToCloseSocketAfterFetch) {

        self.haveToCloseSocketAfterFetch = NO;
        [self closeSocketInBackgroundAfterFetch];

    }

}

- (BOOL)isUsingNetwork {
    return self.isReceivingData || self.isDefantomizing || self.isSendingData;
}

- (NSTimeInterval)timeout {

    [STMFunctions appState];

    NSTimeInterval result = [STMFunctions appState] ? self.httpTimeoutBackground : self.httpTimeoutForeground;

    return result;

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

    if (self.isRunning) return;

    self.settings = nil;

    if (![self checkStcEntities]) {
        return [self.session.logger saveLogMessageWithText:@"checkStcEntities fail" numType:STMLogMessageTypeError];
    }

    if (!self.socketUrlString) {

        [self.session.logger saveLogMessageWithText:self.settings.description numType:STMLogMessageTypeInfo];
        [self.session.logger saveLogMessageWithText:@"Syncer has no socketURL" numType:STMLogMessageTypeError];

        return;

    }

    self.socketUrlString = [self.socketUrlString stringByReplacingOccurrencesOfString:@"//socket." withString:@"//socket-v2."];

    [STMEntityController checkEntitiesForDuplicates];
    [STMClientDataController checkClientData];

    [self.session.logger saveLogMessageDictionaryToDocument];
    [self.session.logger saveLogMessageWithText:@"Syncer start"];

    [self addObservers];

    self.socketTransport = [STMSocketTransport transportWithUrl:self.socketUrlString andEntityResource:self.entityResource owner:self remoteDataEventHandling:self];

    if (!self.socketTransport) {
        return [self.session.logger saveLogMessageWithText:@"Syncer can not start socket transport" numType:STMLogMessageTypeError];
    }

    self.isRunning = YES;

    [self postAsyncMainQueueNotification:NOTIFICATION_SYNCER_INIT_SUCCESSFULLY];

}


#pragma mark - stop syncer methods

- (void)stopSyncer {

    if (self.isRunning) {

        [self.socketTransport closeSocket];

//        [self.session.logger saveLogMessageWithText:@"Syncer stop"];
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
    self.httpTimeoutForeground = 0;
    self.httpTimeoutBackground = 0;

}


#pragma mark - STMSocketConnectionOwner protocol


- (void)socketAuthorizationError:(NSError *)error {

    [self.session.logger saveLogMessageWithText:error.localizedDescription numType:STMLogMessageTypeError];

    [self.socketTransport closeSocket];

    [NSTimer scheduledTimerWithTimeInterval:self.timeout target:self selector:@selector(checkSocket) userInfo:nil repeats:NO];

}

- (void)socketReceiveAuthorization {

    NSLogMethodName;
    
    STMCoreAuthController.sharedAuthController.initialLoadingError = false;
    
    [self postAsyncMainQueueNotification:NOTIFICATION_SOCKET_AUTHORIZATION_SUCCESS];

    [self subscribeToUnsyncedObjects];

    [self initTimer];

    NSArray *downloadableEntityNames = [STMEntityController downloadableEntityNames];

    NSArray *downloadableEntityResources = [STMFunctions mapArray:downloadableEntityNames withBlock:^id _Nonnull(NSString *_Nonnull value) {
        return [STMEntityController resourceForEntity:value];
    }];

    [self.socketTransport socketSendEvent:STMSocketEventSubscribe withValue:downloadableEntityResources];

}

- (void)socketWillClosed {

    NSLogMethodName;

    [self stopSyncerActivity];

}

- (void)socketLostConnection {

    NSLogMethodName;

    [self stopSyncerActivity];

}

- (void)stopSyncerActivity {

    [self releaseTimer];

    [self unsubscribeFromUnsyncedObjects];

    if (self.isSendingData) {
        self.isSendingData = NO;
    }

//    if (self.isReceivingData) {
    [self.dataDownloadingDelegate stopDownloading];
//    }

//    if (self.isDefantomizing) {
    [self.defantomizingDelegate stopDefantomization];
//    }

}

- (BOOL)checkStcEntities {

    NSDictionary *stcEntities = [STMEntityController stcEntities];

    NSString *stcEntityName = NSStringFromClass([STMEntity class]);

    NSDictionary *entity = stcEntities[stcEntityName];

    if (!entity) {

        if (!self.entityResource) {

            [self.logger errorMessage:@"ERROR! syncer have no settings, something really wrong here, needs attention!"];
            return NO;

        }

        NSError *error;
        NSDictionary *attributes = @{
                @"name": [STMFunctions removePrefixFromEntityName:stcEntityName],
                @"url": self.entityResource
        };

        [self.persistenceDelegate mergeSync:stcEntityName
                                 attributes:attributes
                                    options:@{STMPersistingOptionLtsNow}
                                      error:&error];

    } else if ([entity[@"url"] isKindOfClass:[NSString class]] && ![entity[@"url"] isEqualToString:self.entityResource]) {

        NSLog(@"change STMEntity url from %@ to %@", entity[@"url"], self.entityResource);

        NSMutableDictionary *attributes = entity.mutableCopy;
        attributes[@"url"] = self.entityResource;

        NSError *error = nil;
        [self.persistenceDelegate mergeSync:stcEntityName
                                 attributes:attributes.copy
                                    options:@{STMPersistingOptionLtsNow}
                                      error:&error];

    }

    [STMEntityController addChangesObserver:self selector:@selector(entitiesChanged)];

    return YES;

}

- (void)entitiesChanged {

    [self subscribeToUnsyncedObjects];
    [self postAsyncMainQueueNotification:NOTIFICATION_SYNCER_RECEIVED_ENTITIES];
    [self receiveData];

}

- (void)checkSocket {
    if (self.isRunning) [self.socketTransport checkSocket];
}

- (void)closeSocketInBackground {

    [STMSyncer cancelPreviousPerformRequestsWithTarget:self
                                              selector:@selector(closeSocketInBackground)
                                                object:nil];

    [self.session.logger saveLogMessageWithText:@"close socket in background"
                                        numType:STMLogMessageTypeInfo];

    [self.socketTransport closeSocket];

}

- (void)closeSocketInBackgroundAfterFetch {

    UIApplication *app = [UIApplication sharedApplication];

    if (app.applicationState != UIApplicationStateBackground) return;
    if (app.backgroundTimeRemaining > 180) return;

    if (self.isUsingNetwork) {
        self.haveToCloseSocketAfterFetch = YES;
    } else {
        [self closeSocketInBackground];
    }

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

    [[NSRunLoop mainRunLoop] addTimer:self.syncTimer
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
    [self sendData];
    [self.dataSyncingDelegate startSyncing];
}

- (void)fullSync {

    [self receiveData];
    [self upload];

}

- (void)receiveEntities:(NSArray *)entitiesNames {

    if (![entitiesNames isKindOfClass:[NSArray class]]) {
        NSString *logMessage = @"receiveEntities: argument is not an array";
        return [self.session.logger saveLogMessageWithText:logMessage numType:STMLogMessageTypeError];
    }

    NSArray *existingNames = [STMFunctions mapArray:entitiesNames withBlock:^NSString *(NSString *name) {
        return [self.persistenceDelegate isConcreteEntityName:name] ? [STMFunctions addPrefixToEntityName:name] : nil;
    }];

    if (existingNames.count) {
        [self.dataDownloadingDelegate startDownloading:existingNames];
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
            NSLog(@"error: %@ %@", entityName, error);
            return;
        }

        NSLog(@"success: %@ %@", entityName, identifier);

        [self.persistenceDelegate mergeAsync:entityName attributes:result options:@{STMPersistingOptionLtsNow} completionHandler:nil];

    }];

}

#pragma mark - defantomization

- (void)startDefantomization {

    if (!self.socketTransport.isReady) {
        return [self.defantomizingDelegate stopDefantomization];
    }

    if (self.isDefantomizing) {
        return;
    }

    self.isDefantomizing = YES;

    [self.defantomizingDelegate startDefantomization];

}


#pragma mark STMDefantomizingOwner

- (void)defantomizeEntityName:(NSString *)entityName identifier:(NSString *)identifier {

    if (!self.isDefantomizing) return [self.defantomizingDelegate stopDefantomization];

    [self.socketTransport findAsync:entityName identifier:identifier options:nil completionHandlerWithHeaders:^(BOOL success, NSDictionary *result, NSDictionary *headers, NSError *error) {

        id errorHeader = headers[@"error"];

        if ([errorHeader respondsToSelector:@selector(integerValue)]) {
            switch ([errorHeader integerValue]) {
                case 404:
                case 403:
                    success = NO;
                    error = [STMFunctions errorWithMessage:[NSString stringWithFormat:@"%@", errorHeader]];
                    break;
                default:
                    break;
            }
        }

        [self.defantomizingDelegate defantomizedEntityName:entityName identifier:identifier success:success attributes:result error:error];

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
    [self finishUnsyncedProcess];

}


#pragma mark - STMSyncer protocol methods

- (void)sendData {

    if (!self.isRunning) return;

    [[self.session logger] saveLogMessageWithText:CurrentMethodName
                                          numType:STMLogMessageTypeInfo];

    if ([NSThread isMainThread]) {
        [STMClientDataController checkClientData];
    }

}

- (void)receiveData {

    if (!self.isRunning) return;

    [[self.session logger] infoMessage:CurrentMethodName];

    if ([self.dataDownloadingDelegate downloadingState]) {
        NSLog(@"repeat download");
//        self.needRepeatDownload = YES;
//        return;
//        [[self.session logger] importantMessage:@"receiveData is stopping downloading"];
//        [self.dataDownloadingDelegate stopDownloading];
    }

    [self.dataDownloadingDelegate startDownloading];

}


#pragma mark - STMDataDownloadingOwner

- (void)dataDownloadingFinished {

    if (self.needRepeatDownload) {

        NSLog(@"dataDownloadingFinished and needRepeatDownload");
        self.needRepeatDownload = NO;
        return [self receiveData];

    }

    NSLogMethodName;

    [self postAsyncMainQueueNotification:NOTIFICATION_SYNCER_RECEIVE_FINISHED];

    [self turnOffNetworkActivityIndicator];

    [self saveReceiveDate];

    [STMCoreObjectsController dataLoadingFinished];

    [[self.session logger] saveLogMessageWithText:CurrentMethodName
                                          numType:STMLogMessageTypeInfo];

    if(!STMCoreAuthController.sharedAuthController.initialLoadingError){
        [self startDefantomization];
    }

    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        UIApplication *app = [UIApplication sharedApplication];
        STMCoreAppDelegate *appDelegate = (STMCoreAppDelegate *) app.delegate;

        if (appDelegate.haveFetchCompletionHandlers) {

            [appDelegate completeFetchCompletionHandlersWithResult:UIBackgroundFetchResultNewData];
            [self closeSocketInBackgroundAfterFetch];

        }
    }];


}

- (void)receiveData:(NSString *)entityName offset:(NSString *)offset {

    if (![self.socketTransport isReady]) {
        return [self.dataDownloadingDelegate stopDownloading];
    }

    NSUInteger fetchLimit = [self.settings[@"fetchLimit"] integerValue];

    NSDictionary *options = @{STMPersistingOptionPageSize: @(fetchLimit),
            STMPersistingOptionOffset: offset};

    [self.socketTransport findAllAsync:entityName predicate:nil options:options completionHandlerWithHeaders:^(BOOL success, NSArray *result, NSDictionary *headers, NSError *error) {

        NSString *offset = headers[STMPersistingOptionOffset];
        NSUInteger pageSize = [headers[STMPersistingOptionPageSize] integerValue];

        [self.dataDownloadingDelegate dataReceivedSuccessfully:success
                                                    entityName:entityName
                                                  dataRecieved:result
                                                        offset:offset
                                                      pageSize:pageSize
                                                         error:error];

    }];

}


#pragma mark - STMDataSyncingSubscriber

- (NSPredicate *)predicateForUnsyncedObjectsWithEntityName:(NSString *)entityName {
    return [self.dataSyncingDelegate predicateForUnsyncedObjectsWithEntityName:entityName];
}

- (void)haveUnsynced:(NSString *)entityName itemData:(NSDictionary *)itemData itemVersion:(NSString *)itemVersion {

    self.isSendingData = YES;

    [self.socketTransport mergeAsync:entityName attributes:itemData options:nil completionHandlerWithHeaders:^(BOOL success, NSDictionary *result, NSDictionary *headers, NSError *error) {

//        NSLog(@"synced entityName %@, item %@", entityName, itemData[@"id"]);

//        if ([self.dataSyncingDelegate numberOfUnsyncedObjects] == 0) {
//            self.isSendingData = NO;
//        }

        if (error) {
            [self checkGoneEntity:entityName itemData:itemData headers:headers];
            NSLog(@"updateResource error: %@", error.localizedDescription);
        }

        if (success) {
            [self bunchOfObjectsSent];
        }

        [self.dataSyncingDelegate setSynced:success
                                     entity:entityName
                                   itemData:success ? result : itemData
                                itemVersion:itemVersion];

    }];

}

- (void)checkGoneEntity:(NSString *)entityName itemData:(NSDictionary *)itemData headers:(NSDictionary *)headers {
    
    if ([headers[@"error"] intValue] == 410){
        
        NSLog(@"destroy gone entity name: %@, id: %@", entityName, itemData[@"id"]);

        NSError *error = nil;
        
        NSDictionary *options = @{STMPersistingOptionRecordstatuses: @NO};
        
        [self.persistenceDelegate destroySync:entityName identifier:itemData[@"id"] options:options error:&error];
        
        if (error) {

            NSString *errorMessage = [NSString stringWithFormat:@"Error destroy gone entity: %@", error.localizedDescription];

            [self.logger errorMessage:errorMessage];

        }
        
    }
    
}

- (void)finishUnsyncedProcess {
    self.isSendingData = NO;
}

- (void)sendStarted {

    [self postAsyncMainQueueNotification:NOTIFICATION_SYNCER_SEND_STARTED];

}

- (void)sendFinished {

    [self saveSendDate];

    [self postAsyncMainQueueNotification:NOTIFICATION_SYNCER_SEND_FINISHED];

//    [[self.session logger] saveLogMessageWithText:CurrentMethodName
//                                          numType:STMLogMessageTypeInfo];

}

- (void)bunchOfObjectsSent {

    [self saveSendDate];
//    [self postAsyncMainQueueNotification:NOTIFICATION_SYNCER_BUNCH_OF_OBJECTS_SENT];

}


#pragma mark - save dates

- (void)saveReceiveDate {
    [self saveSyncDate:@"receive"];
}

- (void)saveSendDate {
    [self saveSyncDate:@"send"];
}

- (void)saveSyncDate:(NSString *)syncDateType {

    [[NSOperationQueue mainQueue] addOperationWithBlock:^{

        if (!self.session.uid) return;

        NSString *key = [syncDateType stringByAppendingString:[@"Date" stringByAppendingString:self.session.uid]];
        NSString *dateString = [[STMFunctions dateShortTimeShortFormatter] stringFromDate:[NSDate date]];

        [self.userDefaults setObject:dateString forKey:key];
        [self.userDefaults synchronize];

    }];

}

@end
