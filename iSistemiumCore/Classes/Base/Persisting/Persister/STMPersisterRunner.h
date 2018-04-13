//
//  STMPersisterRunner.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 24/05/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingRunning.h"
#import "STMPersistingObserving.h"

@interface STMPersisterRunner : NSObject <STMPersistingRunning>

- (instancetype)initWithPersister:(id <STMModelling, STMPersistingObserving>)persister adapters:(NSDictionary *)adapters;

@end
