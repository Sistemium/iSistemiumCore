//
//  STMCoreController.m
//  iSistemium
//
//  Created by Maxim Grigoriev on 15/01/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMCoreController.h"
#import "STMCoreSessionManager.h"
#import "STMCoreAuthController.h"
#import "STMUserDefaults.h"

@implementation STMCoreController

+ (STMCoreSession *)session {
    return [STMCoreSessionManager sharedManager].currentSession;
}

#warning have to remove document property after full implementation of persister
+ (STMDocument *)document {
    return [self session].document;
}

+ (NSObject <STMPersistingPromised,STMPersistingAsync,STMPersistingSync> *)persistenceDelegate {
    return [self session].persistenceDelegate;
}

- (id)authController {
    return [STMCoreAuthController authController];
}

- (id)userDefaults {
    return [STMUserDefaults standardUserDefaults];
}

+ (id)userDefaults {
    return [STMUserDefaults standardUserDefaults];
}

@end
