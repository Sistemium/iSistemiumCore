//
//  STMPersistingRunning.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 24/05/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingTransaction.h"

@protocol STMPersistingRunning

- (void)execute:(BOOL (^)(id <STMPersistingTransaction> transaction))block;

- (NSArray *)readOnly:(NSArray * (^)(id<STMPersistingTransaction>))block;

@end
