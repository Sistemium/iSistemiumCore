//
//  STMFakePersisting.h
//  iSisSales
//
//  Created by Alexander Levin on 03/02/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "STMModeller+Interceptable.h"
#import "STMPersistingFullStack.h"

#define STMFakePersistingOptions NSDictionary *

#define STMFakePersistingOptionInMemoryDBKey @"inMemoryDB"
#define STMFakePersistingOptionInMemoryDB STMFakePersistingOptionInMemoryDBKey:@YES

#define STMFakePersistingOptionEmptyDBKey @"emptyDB"
#define STMFakePersistingOptionEmptyDB STMFakePersistingOptionEmptyDBKey:@YES

#define STMFakePersistingOptionCheckModelKey @"checkModel"
#define STMFakePersistingOptionCheckModel STMFakePersistingOptionCheckModelKey:@YES

@interface STMFakePersisting : STMModeller <STMPersistingSync>

+ (instancetype)fakePersistingWithOptions:(STMFakePersistingOptions)options;
+ (instancetype)fakePersistingWithModelName:(NSString *)modelName 
                                    options:(STMFakePersistingOptions)options;

- (instancetype)initWithPersistingOptions:(STMFakePersistingOptions)options;
- (void)setOption:(NSString *)option value:(id)value;

@property (nonatomic, strong) STMFakePersistingOptions options;

@end

#import "STMFakePersisting+Promised.h"
#import "STMFakePersisting+Async.h"
