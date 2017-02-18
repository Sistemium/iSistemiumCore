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
#import "STMPersistingInterceptorUniqueProperty.h"

#import "STMUnsyncedDataHelper.h"

#import "STMSyncerHelper+Defantomizing.h"
#import "STMSyncerHelper+Downloading.h"

#import "STMPersisterFantoms.h"
#import "STMSyncer.h"

@implementation STMCoreSession (Persistable)

- (instancetype)initPersistable {
    
    NSString *dataModelName = self.startSettings[@"dataModelName"];
    
    if (!dataModelName) {
        dataModelName = [[STMCoreAuthController authController] dataModelName];
    }
    
    STMPersister *persister =
    [STMPersister persisterWithModelName:dataModelName
                                     uid:self.uid
                                  iSisDB:self.iSisDB
                       completionHandler:nil];
    
    self.persistenceDelegate = persister;
    // TODO: remove direct links to document after full persisting concept realization
    self.document = persister.document;

    
    STMPersistingInterceptorUniqueProperty *entityNameInterceptor = [STMPersistingInterceptorUniqueProperty controllerWithPersistenceDelegate:persister];
    
    entityNameInterceptor.entityName = STM_ENTITY_NAME;
    entityNameInterceptor.propertyName = @"name";
    
    [persister beforeMergeEntityName:entityNameInterceptor.entityName interceptor:entityNameInterceptor];

    [self addPersistenceObservers];
    
    return self;
}

- (void)removePersistable:(void (^)(BOOL success))completionHandler {
    
    [self removePersistenceObservers];
    
    // TODO: do document closing in STMPersister
    
    if (self.document.documentState == UIDocumentStateNormal) {
        
        [self.document saveDocument:^(BOOL success) {
            
            if (completionHandler) completionHandler(success);
            
            self.document = nil;
            self.persistenceDelegate = nil;
            self.settingsController = nil;
            self.trackers = nil;
            self.logger = nil;
            self.syncer = nil;
            
        }];
        
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
    
    self.settingsController = [[self settingsControllerClass] controllerWithSettings:self.startSettings defaultSettings:self.defaultSettings];
    self.settingsController.persistenceDelegate = self.persistenceDelegate;
    self.settingsController.session = self;
    [(STMPersister *)self.persistenceDelegate beforeMergeEntityName:NSStringFromClass(STMSetting.class) interceptor:self.settingsController];
    
    self.logger = [STMLogger sharedLogger];
    self.logger.session = self;
    [self.logger saveLogMessageWithText:@"document ready"];
    
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
    
    self.syncer = [STMSyncer controllerWithPersistenceDelegate:self.persistenceDelegate];

    STMSyncerHelper *syncerHelper = [[STMSyncerHelper alloc] initWithPersistenceDelegate:self.persistenceDelegate];
    
    syncerHelper.dataDownloadingOwner = self.syncer;
    syncerHelper.persistenceFantomsDelegate = [STMPersisterFantoms persisterFantomsWithPersistenceDelegate:self.persistenceDelegate];
    syncerHelper.defantomizingOwner = self.syncer;
    
    self.syncer.dataDownloadingDelegate = syncerHelper;
    self.syncer.defantomizingDelegate = syncerHelper;
    
    self.syncer.dataSyncingDelegate = [STMUnsyncedDataHelper unsyncedDataHelperWithPersistence:self.persistenceDelegate subscriber:self.syncer];
    
    self.syncer.session = self;
    
}

@end
