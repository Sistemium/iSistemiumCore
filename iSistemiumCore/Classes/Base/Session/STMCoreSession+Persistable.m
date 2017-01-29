//
//  STMCoreSession+Persistable.m
//  iSisSales
//
//  Created by Alexander Levin on 29/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMCoreSession+Persistable.h"
#import "STMPersister+Async.h"
#import "STMPersister+Observable.h"

#import "STMCoreAuthController.h"

@implementation STMCoreSession (Persistable)

- (instancetype)initPersistable {
    
    NSString *dataModelName = self.startSettings[@"dataModelName"];
    
    if (!dataModelName) {
        dataModelName = [[STMCoreAuthController authController] dataModelName];
    }
    
    STMPersister *persister =
    [STMPersister persisterWithModelName:dataModelName
                                     uid:self.uid
                                  iSisDB:self.iSisDB];
    
    self.persistenceDelegate = persister;
    #warning need to remove direct links to document after full persisting concept realization
    self.document = persister.document;

    [self addPersistenceObservers];
    
    return self;
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
        [self removePersistenceObservers];
        self.persistenceDelegate = nil;
    }
    
}

- (void)persisterDocumentReady:(NSNotification *)notification {
    [self persisterCompleteInitializationWithSuccess:YES];
}

- (void)persisterDocumentNotReady:(NSNotification *)notification {
    [self persisterCompleteInitializationWithSuccess:NO];
}


@end
