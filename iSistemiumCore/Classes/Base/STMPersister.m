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


@interface STMPersister()

@property (nonatomic, strong) id <STMSession> session;
@property (nonatomic, strong) STMDocument *document;


@end


@implementation STMPersister

+ (instancetype)initWithDocument:(STMDocument *)stmdocument forSession:(id<STMSession>)session {
    
    STMPersister *persister = [[STMPersister alloc] init];
    
    persister.session = session;
    persister.document = stmdocument;
    
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
    
}

- (void)documentReady:(NSNotification *)notification {
    
}

- (void)documentNotReady:(NSNotification *)notification {
    
}


#pragma mark - STMPersistingSync


#pragma mark - STMPersistingAsync


#pragma mark - STMPersistingPromised


@end
