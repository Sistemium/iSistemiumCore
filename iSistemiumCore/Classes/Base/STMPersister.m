//
//  STMPersister.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 05/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMPersister.h"

#import "STMConstants.h"
#import "STMCoreAuthController.h"


@interface STMPersister()

@property (nonatomic, weak) id <STMSession> session;


@end


@implementation STMPersister

+ (instancetype)initWithSession:(id <STMSession>)session {
    
    STMPersister *persister = [[STMPersister alloc] init];
    
    persister.session = session;
    
    NSString *dataModelName = [session.startSettings valueForKey:@"dataModelName"];
    
    if (!dataModelName) {
        dataModelName = [[STMCoreAuthController authController] dataModelName];
    }
    
    STMDocument *document = [STMDocument documentWithUID:session.uid
                                                  iSisDB:session.iSisDB
                                           dataModelName:dataModelName];

    persister.document = document;
    
    return persister;
    
}

- (instancetype)init {
    
    self = [super init];
    if (self) {
        [self addObservers];
    }
    return self;
    
}

#pragma mark - observers

- (void)addObservers {
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

    [nc addObserver:self
           selector:@selector(sessionStatusChanged:)
               name:NOTIFICATION_SESSION_STATUS_CHANGED
             object:self.session];

    [nc addObserver:self
           selector:@selector(documentReady:)
               name:NOTIFICATION_DOCUMENT_READY
             object:nil];
    
    [nc addObserver:self
           selector:@selector(documentNotReady:)
               name:NOTIFICATION_DOCUMENT_NOT_READY
             object:nil];

}

- (void)removeObservers {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
}

- (void)sessionStatusChanged:(NSNotification *)notification {
    
    if ([notification.object conformsToProtocol:@protocol(STMSession)]) {
        
        id <STMSession>session = (id <STMSession>)notification.object;
        
        if (session == self.session) {
            
            if (session.status == STMSessionRemoving) {
                
                [self removeObservers];
                self.session = nil;
                
            }
            
        }
        
    }

}

- (void)documentReady:(NSNotification *)notification {
    
    if ([[notification.userInfo valueForKey:@"uid"] isEqualToString:self.session.uid]) {
        
        [self.session persisterCompleteInitializationWithSuccess:YES];
        // here we can remove document observers
        
    }

}

- (void)documentNotReady:(NSNotification *)notification {

    if ([[notification.userInfo valueForKey:@"uid"] isEqualToString:self.session.uid]) {
        
        [self.session persisterCompleteInitializationWithSuccess:NO];
        // here we can remove document observers

    }

}


#pragma mark - STMPersistingSync


#pragma mark - STMPersistingAsync


#pragma mark - STMPersistingPromised


@end
