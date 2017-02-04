//
//  STMSyncerHelper.h
//  iSisSales
//
//  Created by Maxim Grigoriev on 11/01/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMPersistingSync.h"


@interface STMSyncerHelper : NSObject

@property (nonatomic, strong, readonly) NSMutableArray *failToResolveFantomsArray;
@property (nonatomic, weak) id <STMPersistingSync> persistenceDelegate;

@end
