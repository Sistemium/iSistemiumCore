//
//  STMInMemoryTransaction.h
//  iSisSales
//
//  Created by Alexander Levin on 20/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMFakePersisting.h"
#import "STMPersistingInterCepting.h"

@interface STMInMemoryTransaction : NSObject <STMPersistingTransaction>

+ (instancetype)inMemoryTransactionWithInMemoryPersister:(STMFakePersisting *)persister;

@end
