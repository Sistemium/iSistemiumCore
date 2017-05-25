//
//  STMPersisterRunner.m
//  iSisSales
//
//  Created by Edgar Jan Vuicik on 24/05/2017.
//  Copyright © 2017 Sistemium UAB. All rights reserved.
//

#import "STMPersisterRunner.h"

@implementation STMPersisterRunner

- (void)execute:(BOOL (^)(id <STMPersistingTransaction> transaction))block error:(NSError **)error {

    
}

- (NSArray *)readOnly:(NSArray * (^)(id<STMPersistingTransaction>))block {
    
}

@end
