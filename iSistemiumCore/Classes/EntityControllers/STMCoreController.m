//
//  STMCoreController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 15/01/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMCoreController.h"
#import "STMCoreSessionManager.h"

@implementation STMCoreController

+ (STMCoreSession *)session {
    
    return [STMCoreSessionManager sharedManager].currentSession;
    
}

#warning have to remove document property after full implementation of persister
+ (STMDocument *)document {
    
    return [self session].document;
    
}

+ (NSObject <STMPersistingPromised,STMPersistingAsync,STMPersistingSync> *)persistenceDelegate {
    
    return [self session].persister;
    
}

+ (STMSyncer *)syncer {
    
    return [self session].syncer;
    
}

@end
