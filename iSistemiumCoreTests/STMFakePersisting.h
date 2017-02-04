//
//  STMFakePersisting.h
//  iSisSales
//
//  Created by Alexander Levin on 03/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STMPersistingFullStack.h"
#import "STMPersister+Observable.h"

#define STMFakePersistingOptions NSDictionary *
#define STMFakePersistingOptionInMemoryDBKey @"inMemoryDB"
#define STMFakePersistingOptionInMemoryDB STMFakePersistingOptionInMemoryDBKey:@YES
#define STMFakePersistingOptionEmptyDBKey @"emptyDB"
#define STMFakePersistingOptionEmptyDB STMFakePersistingOptionEmptyDBKey:@YES

@interface STMFakePersisting : STMPersistingObservable <STMPersistingSync, STMPersistingPromised>

+ (instancetype)fakePersistingWithOptions:(STMFakePersistingOptions)options;

@property (nonatomic, strong) STMFakePersistingOptions options;

@end
