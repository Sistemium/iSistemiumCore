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
    #warning need to remove direct links to document after full persisting concept realization
    self.document = persister.document;

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
    [[STMLogger sharedLogger] saveLogMessageWithText:@"document ready"];
    
    self.settingsController = [[self settingsControllerClass] initWithSettings:self.startSettings];
    self.trackers = [NSMutableDictionary dictionary];
    if (!self.isRunningTests) self.syncer = [[STMSyncer alloc] init];
    
    [self checkTrackersToStart];
    
    self.logger = [STMLogger sharedLogger];
    self.logger.session = self;
    self.settingsController.session = self;
    
}


#pragma mark - observers

- (void)addPersistenceObservers {
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    
    [nc addObserver:self
           selector:@selector(myStatusChanged:)
               name:NOTIFICATION_SESSION_STATUS_CHANGED
             object:self];
    
    [nc addObserver:self
           selector:@selector(persisterDocumentReady:)
               name:NOTIFICATION_DOCUMENT_READY
             object:self.document];
    
    [nc addObserver:self
           selector:@selector(persisterDocumentNotReady:)
               name:NOTIFICATION_DOCUMENT_NOT_READY
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


@end
