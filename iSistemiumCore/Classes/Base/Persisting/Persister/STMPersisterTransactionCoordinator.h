//
//  STMPersisterTransactionCoordinator.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 25/05/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingTransaction.h"

@interface STMPersisterTransactionCoordinator : NSObject <STMPersistingTransaction>

- (instancetype)initWithModellingDelegate:(id <STMModelling>)modellingDelegate;
- (void)commit;
- (void)rollback;

@end
