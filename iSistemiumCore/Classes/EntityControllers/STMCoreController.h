//
//  STMCoreController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 15/01/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import "STMCoreControlling.h"
#import "STMCoreObject.h"
#import "STMCoreAuth.h"
#import "STMDocument.h"
#import "STMSessionManagement.h"
#import "STMPersistingFullStack.h"
#import "STMCoreUserDefaults.h"
#import "STMFunctions.h"

@interface STMCoreController : STMCoreObject <STMCoreControlling>

@property (nonatomic,weak) id <STMPersistingFullStack> persistenceDelegate;

// TODO: maybe a better idea to subclass with STMCoreSessionController and mode session there
@property (nonatomic,weak) id <STMSession> session;
@property (readonly) id <STMLogger> logger;

+ (id <STMSession>)session;

+ (STMDocument *)document;

+ (id <STMPersistingFullStack>) persistenceDelegate;

- (id <STMCoreAuth>)authController;
- (id <STMCoreUserDefaults>)userDefaults;
+ (id <STMCoreUserDefaults>)userDefaults;

@end
