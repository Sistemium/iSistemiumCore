//
//  STMCoreController.h
//  iSistemium
//
//  Created by Maxim Grigoriev on 15/01/15.
//  Copyright (c) 2015 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMDocument.h"
#import "STMSyncer.h"
#import "STMCoreSession.h"

#import "STMCoreNS.h"

#import "STMFunctions.h"
#import "STMConstants.h"

#import "STMCoreAuthController.h"

#import "STMCoreDataModel.h"
#import "STMPersistingPromised.h"
#import "STMPersistingAsync.h"
#import "STMPersistingSync.h"
#import "STMModelling.h"
#import "STMPersistingObserving.h"


@interface STMCoreController : NSObject

+ (STMCoreSession *)session;

+ (STMDocument *)document;

+ (id <STMPersistingPromised, STMPersistingAsync, STMPersistingSync, STMModelling, STMPersistingObserving>) persistenceDelegate;
+ (STMSyncer *)syncer;

@end
