//
//  STMSyncerHelper.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 11/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMCoreObject.h"

#import "STMPersistingFullStack.h"
#import "STMDataSyncingState.h"

#import "STMConstants.h"
#import "STMDocument.h"
#import "STMSessionManager.h"


@interface STMSyncerHelper : STMCoreObject

- (instancetype)initWithPersistenceDelegate:(id <STMPersistingFullStack>)persistenceDelegate;

@property (nonatomic, weak) id <STMSession> session;
@property (nonatomic, weak) id <STMPersistingFullStack> persistenceDelegate;

@end


#import "STMSyncerHelper+Downloading.h"
