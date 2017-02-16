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

@interface STMCoreController ()

@property (nonatomic,weak) id <STMPersistingObserving, STMPersistingSync> persistenceDelegate;

@end

@implementation STMCoreController

+ (STMCoreSession *)session {
    return [STMCoreSessionManager sharedManager].currentSession;
}

+ (instancetype)controllerWithPersistenceDelegate:(id)persistenceDelegate {
    return [[self.class alloc] initWithPersistenceDelegate:persistenceDelegate];
}

+ (instancetype)sharedInstance {
    return [[self session] controllerWithName:NSStringFromClass(self)];
}

- (instancetype)initWithPersistenceDelegate:(id)persistenceDelegate {
    
    self = [self init];
    self.persistenceDelegate = persistenceDelegate;
    
    NSLog(@"initWithPersistenceDelegate: %@", NSStringFromClass(self.class));
    
    return self;
    
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
