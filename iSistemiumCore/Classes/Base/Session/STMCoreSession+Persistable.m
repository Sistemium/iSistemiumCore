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
#import "STMPersisterRunner.h"

#define FMDB_PATH @"fmdb"

@implementation STMCoreSession (Persistable)

- (instancetype)initPersistable {

    NSString *dataModelName = self.startSettings[@"dataModelName"];

    if (!dataModelName) {
        dataModelName = [[STMCoreAuthController authController] dataModelName];
    }

    NSString *fmdbFile = [dataModelName stringByAppendingString:@".db"];
    NSString *fmdbPath = [[self.filing persistencePath:FMDB_PATH] stringByAppendingPathComponent:fmdbFile];

    STMPersister *persister = [STMPersister persisterWithModelName:dataModelName
                                                 completionHandler:^(BOOL success) {

                                                 }];

    STMFmdb *fmdb = [[STMFmdb alloc] initWithModelling:persister dbPath:fmdbPath];

    persister.runner = [STMPersisterRunner withPersister:persister
                                                adapters:@{
                                                        @(STMStorageTypeFMDB): fmdb
                                                }];

    [self applyPatchesWithFmdb:fmdb persister:persister];

    self.persistenceDelegate = persister;

    STMPersistingInterceptorUniqueProperty *entityNameInterceptor =
            [STMPersistingInterceptorUniqueProperty controllerWithPersistenceDelegate:persister];

    NSString *entityName = entityNameInterceptor.entityName = STM_ENTITY_NAME;

    entityNameInterceptor.propertyName = STM_NAME;

    [persister beforeMergeEntityName:entityName interceptor:entityNameInterceptor];

    [self addPersistenceObservers];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self persisterCompleteInitializationWithSuccess:YES];
    });

    return self;

}

- (void)applyPatchesWithFmdb:(STMFmdb *)fmdb persister:(STMPersister *)persister {

    NSPredicate *notProcessed = [NSPredicate predicateWithFormat:@"isProcessed == NULL"];

    NSDictionary *options = @{
            STMPersistingOptionOrder: @"ord",
            STMPersistingOptionOrderDirection: @"ASC"
    };
    NSError *error;

    NSArray *result = [persister findAllSync:@"STMSQLPatch" predicate:notProcessed options:options error:&error];

    if (!result.count) {
        NSLog(@"No not-processed patches");
        return;
    }

    for (NSDictionary *patch in result) {

        NSString *result = [fmdb executePatchForCondition:patch[@"condition"] patch:patch[@"patch"]];

        if ([result hasPrefix:@"Success"]) {

            NSMutableDictionary *mPatch = patch.mutableCopy;

            mPatch[@"isProcessed"] = @YES;

            NSDictionary *fieldstoUpdate = @{STMPersistingOptionFieldstoUpdate: @[@"isProcessed"]};

            NSError *error;

            [persister updateSync:@"STMSQLPatch" attributes:mPatch.copy options:fieldstoUpdate error:&error];

        }

        [STMLogger.sharedLogger importantMessage:result];

    }

}

- (void)removePersistable:(void (^)(BOOL success))completionHandler {

    [self removePersistenceObservers];

    //     Uncomment if you want to rebuild db with logoff-logon
    //    [self.filing removeItemAtPath:[self.filing persistenceBasePath] error:nil];

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
    self.controllers[NSStringFromClass([self settingsControllerClass])] = self.settingsController;

    [self.persistenceDelegate beforeMergeEntityName:STM_SETTING_NAME interceptor:self.settingsController];
    [self.persistenceDelegate beforeMergeEntityName:STM_RECORDSTATUS_NAME
                                        interceptor:(STMRecordStatusController *) [self controllerWithClass:STMRecordStatusController.class]];

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

    STMUnsyncedDataHelper *unsyncedHelper = [STMUnsyncedDataHelper unsyncedDataHelperWithPersistence:self.persistenceDelegate subscriber:syncer];
    unsyncedHelper.session = self;

    syncer.dataSyncingDelegate = unsyncedHelper;
    syncer.session = self;

    self.syncer = syncer;

}

@end
