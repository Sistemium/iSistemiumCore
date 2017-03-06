//
//  STMCoreSession+Persistable.m
//  iSisSales
//
//  Created by Alexander Levin on 29/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMCoreSession+Private.h"
#import "STMCoreSession+Persistable.h"
#import "STMPersister+Async.h"

#import "STMCoreAuthController.h"
#import "STMSyncer.h"

#import "STMEntityController.h"
#import "STMCorePicturesController.h"
#import "STMRecordStatusController.h"
#import "STMPersistingInterceptorUniqueProperty.h"

#import "STMUnsyncedDataHelper.h"

#import "STMSyncerHelper+Defantomizing.h"
#import "STMSyncerHelper+Downloading.h"

#import "STMPersisterFantoms.h"


@implementation STMCoreSession (Persistable)

- (instancetype)initPersistable {
    
    NSString *dataModelName = self.startSettings[@"dataModelName"];
    
    if (!dataModelName) {
        dataModelName = [[STMCoreAuthController authController] dataModelName];
    }
    
    STMPersister *persister = [STMPersister persisterWithModelName:dataModelName filing:self.filing completionHandler:^(BOOL success) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self persisterCompleteInitializationWithSuccess:success];
        });
        
    }];

    self.persistenceDelegate = persister;
    // TODO: remove direct links to document after full persisting concept realization
    self.document = persister.document;
    
    
    STMPersistingInterceptorUniqueProperty *entityNameInterceptor = [STMPersistingInterceptorUniqueProperty controllerWithPersistenceDelegate:persister];
    
    entityNameInterceptor.entityName = STM_ENTITY_NAME;
    entityNameInterceptor.propertyName = @"name";
    
    [persister beforeMergeEntityName:entityNameInterceptor.entityName
                         interceptor:entityNameInterceptor];
    
    [self addPersistenceObservers];

    return self;
    
}

- (void)removePersistable:(void (^)(BOOL success))completionHandler {
    
    [self removePersistenceObservers];
    
    // Uncomment if you want to rebuild db with logoff-logon
     [[(STMPersister *)self.persistenceDelegate fmdb] deleteFile];

    STMDocument *document = self.document;
    
    // TODO: do document closing in STMPersister
    
    self.document = nil;
    self.persistenceDelegate = nil;
    
    if (document && document.documentState == UIDocumentStateNormal) {
        
        [self.document saveDocument:^(BOOL success) {
            if (completionHandler) completionHandler(success);
        }];
        
    } else {
        if (completionHandler) completionHandler(YES);
    }
    
}

#pragma mark Private methods

- (void)persisterCompleteInitializationWithSuccess:(BOOL)success {
    
    if (!success) {
        NSLog(@"persister is not ready, have to do something with it");
        return;
    }
    
    [self initController:STMEntityController.class];
    [self initController:STMCorePicturesController.class];
    [self initController:STMRecordStatusController.class];
    
    self.settingsController = [[self settingsControllerClass] controllerWithSettings:self.startSettings defaultSettings:self.defaultSettings];
    self.settingsController.persistenceDelegate = self.persistenceDelegate;
    self.settingsController.session = self;
    
    [self.persistenceDelegate beforeMergeEntityName:STM_SETTING_NAME interceptor:self.settingsController];
    [self.persistenceDelegate beforeMergeEntityName:STM_RECORDSTATUS_NAME
                                        interceptor:(STMRecordStatusController *)[self controllerWithClass:STMRecordStatusController.class]];
    
    self.logger = [STMLogger sharedLogger];
    self.logger.session = self;
    
    self.trackers = [NSMutableDictionary dictionary];
    
    [self checkTrackersToStart];
    
    self.status = STMSessionRunning;
    
    if (!self.isRunningTests) {
        [self setupSyncer];
    }
    
}


#pragma mark - observers

- (void)addPersistenceObservers {
    
    [self observeNotification:NOTIFICATION_SESSION_STATUS_CHANGED
                     selector:@selector(myStatusChanged:)
                       object:self];
    
    [self observeNotification:NOTIFICATION_DOCUMENT_READY
                     selector:@selector(persisterDocumentReady:)
                       object:self.document];
    
    [self observeNotification:NOTIFICATION_DOCUMENT_NOT_READY
                     selector:@selector(persisterDocumentNotReady:)
                       object:self.document];
    
}

- (void)removePersistenceObservers {
    
    [NSNotificationCenter.defaultCenter removeObserver:self];
    
}

- (void)myStatusChanged:(NSNotification *)notification {
    
    if (self.status == STMSessionRemoving) {
        [self removePersistable:nil];
    }
    
}

- (void)persisterDocumentReady:(NSNotification *)notification {
    [self persisterCompleteInitializationWithSuccess:YES];
}

- (void)persisterDocumentNotReady:(NSNotification *)notification {
    [self persisterCompleteInitializationWithSuccess:NO];
}

- (void)setupSyncer {
    
    STMSyncer *syncer = [STMSyncer controllerWithPersistenceDelegate:self.persistenceDelegate];
    STMSyncerHelper *syncerHelper = [STMSyncerHelper controllerWithPersistenceDelegate:self.persistenceDelegate];
    
    syncerHelper.persistenceFantomsDelegate = [STMPersisterFantoms controllerWithPersistenceDelegate:self.persistenceDelegate];
    syncerHelper.dataDownloadingOwner = syncer;
    syncerHelper.defantomizingOwner = syncer;
    
    syncer.dataDownloadingDelegate = syncerHelper;
    syncer.defantomizingDelegate = syncerHelper;
    syncer.dataSyncingDelegate = [STMUnsyncedDataHelper unsyncedDataHelperWithPersistence:self.persistenceDelegate subscriber:self.syncer];
    syncer.session = self;
    
    self.syncer = syncer;
    
}

@end
