//
//  STMPersistingRunning.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 24/05/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingTransaction.h"

@protocol STMAdapting

- (id<STMPersistingTransaction>)beginTransactionReadOnly:(BOOL)readOnly;
- (void)commit;
- (void)rollback;

@end
