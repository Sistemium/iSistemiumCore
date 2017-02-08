//
//  STMSyncerHelper.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 11/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMPersistingFullStack.h"
#import "STMDataSyncingState.h"

#import "STMConstants.h"
#import "STMDocument.h"
#import "STMSessionManager.h"


@interface STMSyncerHelper : NSObject

@property (nonatomic, strong) STMDocument *document;
@property (nonatomic, strong) id <STMSession> session;
@property (nonatomic, weak) id <STMPersistingFullStack> persistenceDelegate;


@end
