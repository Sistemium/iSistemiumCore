//
//  STMPersisterTransactionCoordinator.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 25/05/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingTransaction.h"
#import "STMPersistingObserving.h"

@interface STMPersisterTransactionCoordinator : NSObject <STMPersistingTransaction>

- (instancetype)initWithPersister:(id <STMModelling, STMPersistingObserving>)persister adapters:(NSDictionary *)adapters;

- (instancetype)initWithPersister:(id <STMModelling, STMPersistingObserving>)persister adapters:(NSDictionary *)adapters readOnly:(BOOL)readOnly;

- (void)endTransactionWithSuccess:(BOOL)success;

@property (nonatomic, weak) dispatch_queue_t dispatchQueue;

@end
