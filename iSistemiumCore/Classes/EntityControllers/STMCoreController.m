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

@end

@implementation STMCoreController

+ (id <STMSession>)session {
    return [STMCoreSessionManager sharedManager].currentSession;
}

+ (instancetype)controllerWithPersistenceDelegate:(id)persistenceDelegate {
    return [[self.class alloc] initWithPersistenceDelegate:persistenceDelegate];
}

+ (instancetype)sharedInstance {
    
    // this is do not work for [STMCoreSettingsController stringValueForSettings…]
    // session store settingsController with key = STMSettingsController
    // but we ask here controller with key = STMCoreSettingsController

    return (STMCoreController*)[[self session] controllerWithClass:self.class];
    
}

- (instancetype)initWithPersistenceDelegate:(id)persistenceDelegate {
    
    self = [self init];
    self.persistenceDelegate = persistenceDelegate;
    
    NSLog(@"initWithPersistenceDelegate: %@", NSStringFromClass(self.class));
    
    return self;
    
}

// TODO: to remove document property after full implementation of persister
+ (STMDocument *)document {
    return [self session].document;
}

+ (id)persistenceDelegate {
    return [self session].persistenceDelegate;
}

- (id)authController {
    return [STMCoreAuthController sharedAuthController];
}

- (id)userDefaults {
    return [STMUserDefaults standardUserDefaults];
}

+ (id)userDefaults {
    return [STMUserDefaults standardUserDefaults];
}

- (id)logger {
    return self.session.logger;
}

@end
