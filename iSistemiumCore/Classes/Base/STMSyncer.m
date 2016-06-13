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
#import "STMFunctions.h"
#import "STMEntityController.h"
#import "STMClientEntityController.h"
#import "STMClientDataController.h"
#import "STMCorePicturesController.h"

#import "STMCoreDataModel.h"

#import "STMSocketController.h"


#define SEND_DATA_CONNECTION @"SEND_DATA"


@interface STMSyncer()

@property (nonatomic, strong) STMDocument *document;

@property (nonatomic, strong) NSMutableDictionary *settings;
@property (nonatomic) NSInteger fetchLimit;
@property (nonatomic, strong) NSString *entityResource;
@property (nonatomic, strong) NSString *socketUrlString;
@property (nonatomic, strong) NSString *xmlNamespace;
@property (nonatomic) NSTimeInterval httpTimeoutForeground;
@property (nonatomic) NSTimeInterval httpTimeoutBackground;
@property (nonatomic, strong) NSString *uploadLogType;

@property (nonatomic, strong) NSTimer *syncTimer;
@property (nonatomic) BOOL timerTicked;

@property (nonatomic) BOOL running;
@property (nonatomic) BOOL syncing;
@property (nonatomic) BOOL checkSending;
@property (nonatomic) BOOL sendOnce;
@property (nonatomic) BOOL errorOccured;
@property (nonatomic) BOOL fullSyncWasDone;
@property (nonatomic) BOOL isFirstSyncCycleIteration;

@property (nonatomic, strong) NSMutableDictionary *responses;
@property (nonatomic, strong) NSMutableDictionary *temporaryETag;
@property (nonatomic, strong) NSMutableArray *sendedEntities;
@property (nonatomic, strong) NSArray *receivingEntitiesNames;
@property (nonatomic) NSUInteger entityCount;
@property (nonatomic, strong) NSMutableArray *entitySyncNames;


@property (nonatomic, strong) void (^fetchCompletionHandler) (UIBackgroundFetchResult result);

@property (nonatomic) UIBackgroundFetchResult fetchResult;

- (void)didReceiveRemoteNotification;
- (void)didEnterBackground;

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


#pragma mark - variables setters & getters

- (void)setSession:(id <STMSession>)session {
    
    if (session != _session) {
        
        self.document = (STMDocument *)session.document;
        _session = session;
        
        [self startSyncer];
        
    }
    
}

- (NSMutableArray *)entitySyncNames {
    if (!_entitySyncNames) {
        _entitySyncNames = [NSMutableArray array];
    }
    return _entitySyncNames;
}

- (NSMutableDictionary *)settings {
    if (!_settings) {
        _settings = [[(id <STMSession>)self.session settingsController] currentSettingsForGroup:@"syncer"];
    }
    return _settings;
}

- (NSInteger)fetchLimit {
    if (!_fetchLimit) {
        _fetchLimit = [self.settings[@"fetchLimit"] integerValue];
    }
    return _fetchLimit;
}

- (double)syncInterval {
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

- (NSTimeInterval)timeout {
    
    NSTimeInterval timeout = ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) ? self.httpTimeoutBackground : self.httpTimeoutForeground;
    
    return timeout;
    
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
    
    if (self.running && !self.syncing && syncerState != _syncerState) {

        STMSyncerState previousState = _syncerState;
        
        _syncerState = syncerState;
        
        NSArray *syncStates = @[@"idle", @"sendData", @"sendDataOnce", @"receiveData"];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"syncStatusChanged" object:self userInfo:@{@"from":@(previousState), @"to":@(syncerState)}];
        
        NSString *logMessage = [NSString stringWithFormat:@"Syncer %@", syncStates[syncerState]];
        NSLog(logMessage);

        switch (_syncerState) {
            case STMSyncerIdle: {
                
                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
                self.syncing = NO;
                self.sendOnce = NO;
                self.checkSending = NO;
                
                self.entitySyncNames = nil;
                if (self.receivingEntitiesNames) self.receivingEntitiesNames = nil;
                if (self.fetchCompletionHandler) self.fetchCompletionHandler(self.fetchResult);

                break;
            }
            case STMSyncerSendData:
            case STMSyncerSendDataOnce: {
                
                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
                [STMClientDataController checkClientData];
                self.syncing = YES;

                [STMSocketController sendUnsyncedObjects:self];
                
                break;
            }
            case STMSyncerReceiveData: {
                
                [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
                self.syncing = YES;
                [self checkNews];

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
        
        [STMSocketController sendUnsyncedObjects:self];
        
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

- (NSMutableDictionary *)stcEntities {
    
    if (!_stcEntities) {
        
        NSDictionary *stcEntities = [STMEntityController stcEntities];
        
        _stcEntities = [stcEntities mutableCopy];
        
    }
    
    return _stcEntities;
    
}

- (NSMutableDictionary *)temporaryETag {
    
    if (!_temporaryETag) {
        _temporaryETag = [NSMutableDictionary dictionary];
    }
    return _temporaryETag;
    
}

#pragma mark - syncer methods

- (void)startSyncer {
    
    if (!self.running) {
        
        self.settings = nil;
        self.running = YES;
        
        [STMCoreObjectsController initObjectsCacheWithCompletionHandler:^(BOOL success) {
           
            if (success) {
                
                [self checkStcEntitiesWithCompletionHandler:^(BOOL success) {
                    
                    if (success) {
                
                        [STMEntityController checkEntitiesForDuplicates];
                        [STMClientDataController checkClientData];
                        [self.session.logger saveLogMessageDictionaryToDocument];
                        [self.session.logger saveLogMessageWithText:@"Syncer start" type:@""];
                        
                        [self checkUploadableEntities];
                        
                        [self addObservers];
                        
                        [[NSNotificationCenter defaultCenter] postNotificationName:@"Syncer init successfully"
                                                                            object:self];
                        
                        if (self.socketUrlString) {
                            
                            [STMSocketController startSocketWithUrl:self.socketUrlString andEntityResource:self.entityResource];

                        } else {
                            
                            NSLog(@"have NO socketURL, fail to start socket controller");
                            
                        }
                        
                    } else {
                        NSLog(@"checkStcEntities fail");
                    }
                
                }];
                
            } else {
                NSLog(@"init object's cache fail");
            }
            
        }];
        
    }
    
}

- (void)socketReceiveAuthorization {
    [self initTimer];
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
            completionHandler(success);
        }];
        
    } else {
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

- (void)stopSyncer {
    
    if (self.running) {
        
        [STMSocketController closeSocket];
        
        [self.session.logger saveLogMessageWithText:@"Syncer stop" type:@""];
        self.syncing = NO;
        self.syncerState = STMSyncerIdle;
        [self releaseTimer];
        self.settings = nil;
        self.running = NO;
        
    }

}

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

- (void)didEnterBackground {
    [self setSyncerState:STMSyncerSendDataOnce];
}

- (void)appDidBecomeActive {
    
#ifdef DEBUG
    [self setSyncerState:STMSyncerSendData];
#else
    [self setSyncerState:STMSyncerSendDataOnce];
#endif

}

- (void)syncerDidReceiveRemoteNotification:(NSNotification *)notification {
    
    if ([(notification.userInfo)[@"syncer"] isEqualToString:@"upload"]) {
        [self setSyncerState:STMSyncerSendDataOnce];
    }
    
}

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
           selector:@selector(didEnterBackground)
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
            
            if (session.status == STMSessionFinishing) {
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

- (void)prepareToDestroy {
    
    [self removeObservers];
    [self stopSyncer];
    
}

#pragma mark - timer

- (NSTimer *)syncTimer {
    
    if (!_syncTimer) {
        
        if (!self.syncInterval) {
            
            _syncTimer = [[NSTimer alloc] initWithFireDate:[NSDate date]
                                                  interval:0
                                                    target:self
                                                  selector:@selector(onTimerTick:)
                                                  userInfo:nil
                                                   repeats:NO];
            
        } else {
            
            _syncTimer = [[NSTimer alloc] initWithFireDate:[NSDate date]
                                                  interval:self.syncInterval
                                                    target:self
                                                  selector:@selector(onTimerTick:)
                                                  userInfo:nil
                                                   repeats:YES];
            
        }
        
    }
    
    return _syncTimer;
    
}

- (void)initTimer {
    
    if (self.syncTimer) {
        [self releaseTimer];
    }
    
    [[NSRunLoop currentRunLoop] addTimer:self.syncTimer
                                 forMode: NSRunLoopCommonModes];
    
}

- (void)releaseTimer {
    
    [self.syncTimer invalidate];
    self.syncTimer = nil;
    
}

- (void)onTimerTick:(NSTimer *)timer {
    
#ifdef DEBUG
    NSTimeInterval bgTR = [[UIApplication sharedApplication] backgroundTimeRemaining];
    NSLog(@"syncTimer tick at %@, bgTimeRemaining %.0f", [NSDate date], bgTR > 3600 ? -1 : bgTR);
#endif
    
    if ([STMSocketController isSendingData]) {
        self.timerTicked = YES;
    } else {
        self.syncerState = STMSyncerSendData;
    }
    
}

#pragma mark - syncing
#pragma mark - send

- (void)nothingToSend {
    
    [self.session.logger saveLogMessageWithText:@"Syncer nothing to send" type:@""];

    self.syncing = NO;
    
    if (self.timerTicked) {
        
        self.timerTicked = NO;
        self.syncerState = STMSyncerReceiveData;
        
    } else {
    
        self.syncerState = (self.syncerState == STMSyncerSendData) ? STMSyncerReceiveData : STMSyncerIdle;

    }
    
}

- (NSArray *)unsyncedObjects {
    return [STMSocketController unsyncedObjects];
}

- (NSUInteger)numbersOfUnsyncedObjects {
    return [self unsyncedObjects].count;
}


#pragma mark - receive

- (void)checkNews {
    
    [self receiveData]; return;

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

- (void)receiveData {
    
    if (self.syncerState == STMSyncerReceiveData) {
        
        if (!self.receivingEntitiesNames || [self.receivingEntitiesNames containsObject:@"STMEntity"]) {
            
            self.entityCount = 1;
            self.errorOccured = NO;
            
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
    
    if (self.syncerState != STMSyncerIdle) {

        NSString *errorMessage = nil;
        
        STMEntity *entity = (self.stcEntities)[entityName];

        if (entity.roleName) {
            
            NSString *roleOwner = entity.roleOwner;
            NSString *roleOwnerEntityName = [ISISTEMIUM_PREFIX stringByAppendingString:roleOwner];

            if (![[STMCoreObjectsController localDataModelEntityNames] containsObject:roleOwnerEntityName]) {
                errorMessage = [NSString stringWithFormat:@"local data model have no %@ entity for relationship %@", roleOwnerEntityName, entityName];
            } else {
            
                NSString *roleName = entity.roleName;
                NSDictionary *ownerRelationships = [STMCoreObjectsController ownObjectRelationshipsForEntityName:roleOwnerEntityName];
                NSString *destinationEntityName = ownerRelationships[roleName];
                
                if (![[STMCoreObjectsController localDataModelEntityNames] containsObject:destinationEntityName]) {
                    errorMessage = [NSString stringWithFormat:@"local data model have no %@ entity for relationship %@", destinationEntityName, entityName];
                }

            }
            
        }

        if (errorMessage) {
            
            NSLog(errorMessage);
            [self entityCountDecrease];
            
        } else {

            if (entity.roleName || [[STMCoreObjectsController localDataModelEntityNames] containsObject:entityName]) {
                
                NSString *resource = entity.url;
                
                if (resource) {
                    
                    STMClientEntity *clientEntity = [STMClientEntityController clientEntityWithName:entity.name];
                    
                    NSString *eTag = clientEntity.eTag;
                    eTag = eTag ? eTag : @"*";
                    
                    [STMSocketController startReceiveDataFromResource:resource
                                                             withETag:eTag
                                                           fetchLimit:self.fetchLimit
                                                           andTimeout:[self timeout]];
                    
                } else {
                    
                    NSLog(@"    %@: have no url", entityName);
                    [self entityCountDecrease];
                    
                }
                
            } else {

                NSLog(@"    %@: do not exist in local data model", entityName);
                [self entityCountDecrease];
                
            }

        }
        
    }
    
}

- (void)notAuthorized {
    
    self.fetchResult = UIBackgroundFetchResultFailed;
    [self stopSyncer];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"notAuthorized" object:self];
    
}

//- (NSString *)entityNameForConnection:(NSURLConnection *)connection {
//    return [self entityNameForRequest:connection.currentRequest];
//}
//
//- (NSString *)entityNameForRequest:(NSURLRequest *)request {
//    return [self entityNameForURLString:request.URL.absoluteString];
//}
//
//- (NSString *)entityNameForURLString:(NSString *)urlString {
//    
//    if ([urlString isEqualToString:self.socketUrlString]) {
//        
//        return SEND_DATA_CONNECTION;
//        
//    } else {
//        
//        for (STMEntity *entity in [self.stcEntities allValues]) {
//            
//            if ([entity.url isEqualToString:urlString]) {
//                
//                return [[self.stcEntities allKeysForObject:entity] lastObject];
//                
//            }
//            
//        }
//        
//    }
//    
//    return nil;
//
//}

- (void)entityCountDecrease {
    
    self.entityCount -= 1;
    
    if (self.entityCount == 0) {

        [self receivingDidFinish];
        
    } else {
        
        if (self.entitySyncNames.firstObject) [self.entitySyncNames removeObject:(id _Nonnull)self.entitySyncNames.firstObject];

        if (self.entitySyncNames.firstObject) {
            
            [self checkConditionForReceivingEntityWithName:self.entitySyncNames.firstObject];
            
        } else {
            
            [self receivingDidFinish];

        }
        
    }
    
}

- (void)receivingDidFinish {
    [self receivingDidFinishWithError:nil];
}

- (void)receivingDidFinishWithError:(NSString *)errorString {
    
    if (errorString) {
        
        self.syncing = NO;
        [STMSocketController receiveFinishedWithError:errorString];
        self.syncerState = STMSyncerIdle;

    } else {
        
        [self saveReceiveDate];
        
        self.fullSyncWasDone = YES;
        self.isFirstSyncCycleIteration = NO;
        
        [self.document saveDocument:^(BOOL success) {
            
            if (success) {
                
                [STMCoreObjectsController dataLoadingFinished];
                
                self.syncing = NO;
                
                [STMSocketController receiveFinishedWithError:nil];
                
                self.syncerState = (self.errorOccured) ? STMSyncerIdle : STMSyncerSendDataOnce;
                
            }
            
        }];

    }
    
}


#pragma mark - socket receive ack handler

- (void)socketReceiveJSDataAck:(NSArray *)data {

    NSDictionary *response = ([data.firstObject isKindOfClass:[NSDictionary class]]) ? data.firstObject : nil;
    
    if (!response) {
        
        // don't know which method cause an error, send error to all of them
        NSString *errorMessage = @"ERROR: response contain no dictionary";
        [self socketReceiveJSDataFindAllAckError:errorMessage];
        [self socketReceiveJSDataFindAckErrorCode:nil andErrorString:errorMessage entityName:nil xid:nil];
        [self socketReceiveJSDataUpdateAckErrorCode:nil andErrorString:errorMessage withResponseData:nil];
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
                 errorCode:errorCode];
        
    } else if ([methodName isEqualToString:kSocketUpdateMethod]) {

        [self receiveUpdateAck:data
                  withResponse:response
                      resource:resource
                    entityName:entityName
                   errorCode:errorCode];
        
    }
    
}

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

- (void)receiveFindAck:(NSArray *)data withResponse:(NSDictionary *)response resource:(NSString *)resource entityName:(NSString *)entityName errorCode:(NSNumber *)errorCode {
    
    NSData *xid = [STMFunctions xidDataFromXidString:response[@"id"]];

    if (errorCode) {
        
        [self socketReceiveJSDataFindAckErrorCode:errorCode
                                   andErrorString:[NSString stringWithFormat:@"    %@: ERROR: %@", entityName, errorCode]
                                       entityName:entityName
                                              xid:xid];
    
        return;
        
    }
    
    if (!resource) {

        [self socketReceiveJSDataFindAckErrorCode:errorCode
                                   andErrorString:@"ERROR: have no resource string in response"
                                       entityName:entityName
                                              xid:xid];
        return;
        
    }

    NSDictionary *responseData = ([response[@"data"] isKindOfClass:[NSDictionary class]]) ? response[@"data"] : nil;
    
    if (!responseData) {
        
        NSString *errorString = [NSString stringWithFormat:@"    %@: ERROR: find response data is not a dictionary", resource];
        [self socketReceiveJSDataFindAckErrorCode:errorCode
                                   andErrorString:errorString
                                       entityName:entityName
                                              xid:xid];
        return;
        
    }
    
    xid = [STMFunctions xidDataFromXidString:responseData[@"id"]];
    
    [self parseFindAckResponseData:responseData
                    withEntityName:entityName
                               xid:xid];

}

- (void)receiveUpdateAck:(NSArray *)data withResponse:(NSDictionary *)response resource:(NSString *)resource entityName:(NSString *)entityName errorCode:(NSNumber *)errorCode {
    
    NSDictionary *responseData = ([response[@"data"] isKindOfClass:[NSDictionary class]]) ? response[@"data"] : nil;
    
    if (errorCode) {
        
        NSString *errorString = [NSString stringWithFormat:@"    %@: ERROR: %@", resource, errorCode];
        [self socketReceiveJSDataUpdateAckErrorCode:errorCode andErrorString:errorString withResponseData:responseData]; return;
        
    }

    if (!responseData) {
        
        NSString *errorString = [NSString stringWithFormat:@"    %@: ERROR: update response data is not a dictionary", resource];
        [self socketReceiveJSDataUpdateAckErrorCode:nil andErrorString:errorString withResponseData:responseData]; return;
        
    }
    
    [self parseUpdateAckResponseData:responseData];

}

- (void)socketReceiveJSDataFindAllAckError:(NSString *)errorString {
    
    NSLog(errorString);
    [STMSocketController sendEvent:STMSocketEventInfo withValue:errorString];
    [self entityCountDecrease];
    
}

- (void)socketReceiveJSDataFindAckErrorCode:(NSNumber *)errorCode andErrorString:(NSString *)errorString entityName:(NSString *)entityName xid:(NSData *)xid {
    
    if (errorCode.integerValue > 499 && errorCode.integerValue < 600) {

        [STMCoreObjectsController stopDefantomizing];
        
    } else {

        NSLog(errorString);
        
        if (!entityName) entityName = @"";
        if (!xid) xid = [NSData data];
        
        [STMSocketController sendEvent:STMSocketEventInfo withValue:errorString];
        [STMCoreObjectsController didFinishResolveFantom:@{@"entityName":entityName, @"xid":xid} successfully:NO];

    }
    
}

- (void)socketReceiveJSDataUpdateAckErrorCode:(NSNumber *)errorCode andErrorString:(NSString *)errorString withResponseData:(NSDictionary *)responseData {
    
    NSLog(errorString);
    [STMSocketController sendEvent:STMSocketEventInfo withValue:errorString];
    
    if (errorCode.integerValue > 399 && errorCode.integerValue < 500) {
    
        NSString *xid = [responseData valueForKey:@"id"];
        NSData *xidData = [STMFunctions xidDataFromXidString:xid];

        [STMSocketController syncObjectWithXid:xidData successfully:NO];

    } else {
        [STMSocketController sendFinishedWithError:errorString];
    }
    
}

- (void)parseFindAllAckData:(NSArray *)data responseData:(NSArray *)responseData resource:(NSString *)resource entityName:(NSString *)entityName response:(NSDictionary *)response {
    
    if (entityName) {
        
        if (responseData.count > 0) {
            
            NSString *offset = response[@"offset"];
            
            if (offset) {
                
                if (entityName && self.syncerState != STMSyncerIdle) self.temporaryETag[entityName] = offset;
                [self parseSocketFindAllResponseData:responseData forEntityName:entityName];
                
            } else {
                
                NSLog(@"    %@: receive data w/o offset", entityName);
                [self receiveNoContentStatusForEntityWithName:entityName];
                
            }
            
        } else {
            
            NSLog(@"    %@: have no new data", entityName);
            [self receiveNoContentStatusForEntityWithName:entityName];
            
        }
        
    } else {
        
        if ([resource isEqualToString:[STMSocketController newsResourceString]]) {
            [self parseNewsData:responseData];
        } else {
            NSLog(@"ERROR: unknown response: %@", data);
        }
        
    }
    
}

- (void)parseSocketFindAllResponseData:(NSArray *)data forEntityName:(NSString *)entityName {
    
    STMEntity *entity = (self.stcEntities)[entityName];
    
    if (entity) {
        
        [STMCoreObjectsController processingOfDataArray:data withEntityName:entityName andRoleName:entity.roleName withCompletionHandler:^(BOOL success) {
            
            if (success) {
                
                NSLog(@"    %@: get %d objects", entityName, data.count);
                
                NSUInteger pageRowCount = data.count;
                NSUInteger pageSize = self.fetchLimit;
                
                if (pageRowCount < pageSize) {
                    
                    NSLog(@"    %@: pageRowCount < pageSize / No more content", entityName);
                    
                    [self fillETagWithTemporaryValueForEntityName:entityName];
                    [self receiveNoContentStatusForEntityWithName:entityName];
                    
                } else {
                    
                    [self nextReceiveEntityWithName:entityName];
                    
                }
                
                [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFICATION_SYNCER_GET_BUNCH_OF_OBJECTS
                                                                    object:self
                                                                  userInfo:@{@"count"         :@(data.count),
                                                                             @"entityName"    :entityName}];
                
            } else {
                self.errorOccured = YES;
                [self entityCountDecrease];
            }
            
        }];
        
    }

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

- (void)parseFindAckResponseData:(NSDictionary *)responseData withEntityName:(NSString *)entityName xid:(NSData *)xid {

    //    NSLog(@"find responseData %@", responseData);

    if (!entityName) entityName = @"";
    if (!xid) xid = [NSData data];

    [STMCoreObjectsController insertObjectFromDictionary:responseData withEntityName:entityName withCompletionHandler:^(BOOL success) {
        [STMCoreObjectsController didFinishResolveFantom:@{@"entityName":entityName, @"xid":xid} successfully:success];
    }];
    
}


- (void)parseUpdateAckResponseData:(NSDictionary *)responseData {

//    NSLog(@"update responseData %@", responseData);
    [self syncObject:responseData];
    
}


#pragma mark - sync object

- (void)syncObject:(NSDictionary *)objectDictionary {
    
    NSString *xid = [objectDictionary valueForKey:@"id"];
    NSData *xidData = [STMFunctions xidDataFromXidString:xid];
    
    NSManagedObject *syncedObject = [STMCoreObjectsController objectForXid:xidData];
    
    if ([syncedObject isKindOfClass:[STMDatum class]]) {
        
        STMDatum *object = (STMDatum *)syncedObject;
        
        if (object) {
            
            [object.managedObjectContext performBlockAndWait:^{
                
                if ([object isKindOfClass:[STMRecordStatus class]] && [[(STMRecordStatus *)object valueForKey:@"isRemoved"] boolValue]) {
                    
                    [STMCoreObjectsController removeObject:object];
                    
                } else {
                    
                    NSDate *deviceTs = [STMSocketController deviceTsForSyncedObjectXid:xidData];
                    object.lts = deviceTs;
//                    [object willChangeValueForKey:@"lts"];
//                    [object setPrimitiveValue:deviceTs forKey:@"lts"];
//                    [object didChangeValueForKey:@"lts"];
                    
                }
                
                [STMSocketController syncObjectWithXid:xidData successfully:YES];
                
                NSString *entityName = object.entity.name;
                
                NSString *logMessage = [NSString stringWithFormat:@"successefully sync %@ with xid %@", entityName, xid];
                NSLog(logMessage);
                
            }];
            
        } else {
            
            NSString *logMessage = [NSString stringWithFormat:@"Sync: no object with xid: %@", xid];
            NSLog(logMessage);
            
        }
        
    }
    
}


#pragma mark - some sync methods

- (void)receiveNoContentStatusForEntityWithName:(NSString *)entityName {

    if ([entityName isEqualToString:@"STMEntity"]) {
        
        [STMEntityController flushSelf];
        [STMSocketController reloadResultsControllers];
        
        self.stcEntities = nil;
        NSMutableArray *entityNames = [self.stcEntities.allKeys mutableCopy];
        [entityNames removeObject:entityName];
        
        self.entitySyncNames = entityNames;
        
        self.entityCount = entityNames.count;
        
        NSUInteger settingsIndex = [self.entitySyncNames indexOfObject:@"STMSetting"];        
        if (settingsIndex != NSNotFound) [self.entitySyncNames exchangeObjectAtIndex:settingsIndex withObjectAtIndex:0];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"entitiesReceivingDidFinish" object:self];
        
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

- (void)sendFinishedWithError:(NSString *)errorString {
    
    if (errorString) {
        
        self.syncing = NO;
        self.syncerState = STMSyncerIdle;
        
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
    [[NSNotificationCenter defaultCenter] postNotificationName:@"bunchOfObjectsSended" object:self];
    
}

- (void)saveSendDate {
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSString *key = [@"sendDate" stringByAppendingString:self.session.uid];
    NSString *sendDateString = [[STMFunctions dateShortTimeShortFormatter] stringFromDate:[NSDate date]];
    
    [defaults setObject:sendDateString forKey:key];
    [defaults synchronize];
    
}

- (void)saveReceiveDate {
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSString *key = [@"receiveDate" stringByAppendingString:self.session.uid];

    NSString *receiveDateString = [[STMFunctions dateShortTimeShortFormatter] stringFromDate:[NSDate date]];
    
    [defaults setObject:receiveDateString forKey:key];
    [defaults synchronize];
    
}

- (void)socketLostConnection {
    
    self.syncing = NO;
    self.syncerState = STMSyncerIdle;

}


@end
