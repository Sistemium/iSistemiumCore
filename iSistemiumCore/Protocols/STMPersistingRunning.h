//
//  STMPersistingRunning.h
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 24/05/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersistingTransaction.h"
#import "STMAdapting.h"

@protocol STMPersistingRunning

@property (nonatomic, strong) NSDictionary<NSNumber *, id <STMAdapting>> *adapters;

- (void)execute:(BOOL (^)(id <STMPersistingTransaction> transaction))block;

- (NSArray *)readOnly:(NSArray *(^)(id <STMPersistingTransaction>))block;

@end
